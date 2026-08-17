import Foundation
import Testing
@testable import notmeyet

@Suite("Live backend-user HTTP transport", .serialized)
@MainActor
struct LiveBackendUserServiceTests {
    private let authenticationFailure = ServiceFailure.authentication(
        "Your session could not be verified. Please sign in again."
    )
    private let unavailableFailure = ServiceFailure.transport(
        "The account service is unavailable. Try again."
    )
    private let requestFailure = ServiceFailure.transport(
        "The account service could not complete the request. Try again."
    )

    @Test("Client sends exact PUT and PATCH contracts with a fresh bearer token")
    func requestContractsAndFreshTokens() async throws {
        let script = BackendUserTransportScript([
            .json(statusCode: 200, body: BackendUserFixture.user(completed: false)),
            .json(statusCode: 200, body: BackendUserFixture.user(completed: true))
        ])
        ScriptedBackendUserURLProtocol.script = script
        defer { ScriptedBackendUserURLProtocol.reset() }
        let tokens = BackendUserLockedCounter()
        let client = makeService(tokens: tokens).client()

        let resolution = try await client.resolveCurrentUser()
        try await client.completeOnboarding()

        #expect(resolution == BackendUserResolution(
            origin: .existing,
            onboardingCompleted: false
        ))
        #expect(tokens.value == 2)

        let requests = script.requests
        #expect(requests.count == 2)
        #expect(requests.map(\.httpMethod) == ["PUT", "PATCH"])
        #expect(requests.map(\.url?.path) == ["/api/v1/users/me", "/api/v1/users/me"])
        #expect(requests.allSatisfy { $0.url?.query == nil })
        #expect(requests.map { $0.value(forHTTPHeaderField: "Authorization") } == [
            "Bearer fixture-token-1",
            "Bearer fixture-token-2"
        ])
        #expect(requests.allSatisfy {
            $0.value(forHTTPHeaderField: "Accept") == "application/json"
        })

        #expect(requests[0].httpBody == nil)
        #expect(requests[0].httpBodyStream == nil)
        #expect(requests[0].value(forHTTPHeaderField: "Content-Type") == nil)

        #expect(requests[1].httpBody == Data(#"{"onboardingCompleted":true}"#.utf8))
        #expect(requests[1].value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(String(decoding: requests[1].httpBody ?? Data(), as: UTF8.self).contains("false") == false)
    }

    @Test(
        "PUT accepts only the finite status and Boolean mapping",
        arguments: BackendUserPUTCase.allCases
    )
    func putResponseMatrix(testCase: BackendUserPUTCase) async {
        let script = BackendUserTransportScript([testCase.stub])
        ScriptedBackendUserURLProtocol.script = script
        defer { ScriptedBackendUserURLProtocol.reset() }
        let service = makeService()

        if let expectedResolution = testCase.expectedResolution {
            do {
                #expect(try await service.resolveCurrentUser() == expectedResolution)
            } catch {
                Issue.record("Expected resolution, received \(error)")
            }
        } else if let expectedFailure = testCase.expectedFailure {
            await #expect(throws: expectedFailure) {
                try await service.resolveCurrentUser()
            }
        } else {
            Issue.record("PUT fixture has no expected outcome")
        }

        #expect(script.requests.count == 1)
        #expect(script.requests.first?.httpMethod == "PUT")
    }

    @Test(
        "PATCH accepts only 200 with an acknowledged true Boolean",
        arguments: BackendUserPATCHCase.allCases
    )
    func patchResponseMatrix(testCase: BackendUserPATCHCase) async {
        let script = BackendUserTransportScript([testCase.stub])
        ScriptedBackendUserURLProtocol.script = script
        defer { ScriptedBackendUserURLProtocol.reset() }
        let service = makeService()

        if testCase.isAccepted {
            do {
                try await service.completeOnboarding()
            } catch {
                Issue.record("Expected completion acknowledgement, received \(error)")
            }
        } else if let expectedFailure = testCase.expectedFailure {
            await #expect(throws: expectedFailure) {
                try await service.completeOnboarding()
            }
        } else {
            Issue.record("PATCH fixture has no expected outcome")
        }

        #expect(script.requests.count == 1)
        #expect(script.requests.first?.httpMethod == "PATCH")
    }

    @Test("Token provider failures are sanitized before either transport begins")
    func tokenFailurePreventsTransport() async {
        for operation in BackendUserOperation.allCases {
            let script = BackendUserTransportScript([])
            ScriptedBackendUserURLProtocol.script = script
            let providerCalls = BackendUserLockedCounter()
            let service = LiveBackendUserService(
                configuration: makeConfiguration(),
                idTokenProvider: {
                    _ = providerCalls.increment()
                    throw BackendUserSecretError(secret: "provider-secret-detail")
                },
                protocolClasses: [ScriptedBackendUserURLProtocol.self]
            )

            await #expect(throws: authenticationFailure) {
                try await invoke(operation, on: service)
            }
            #expect(providerCalls.value == 1)
            #expect(script.requests.isEmpty)
            #expect(authenticationFailure.errorDescription?.contains("provider-secret-detail") == false)
            ScriptedBackendUserURLProtocol.reset()
        }
    }

    @Test(
        "Empty, whitespace, and CRLF-bearing tokens are rejected before transport",
        arguments: InvalidBackendUserToken.allCases
    )
    func invalidTokensAreRejected(testCase: InvalidBackendUserToken) async {
        for operation in BackendUserOperation.allCases {
            let script = BackendUserTransportScript([])
            ScriptedBackendUserURLProtocol.script = script
            let providerCalls = BackendUserLockedCounter()
            let service = LiveBackendUserService(
                configuration: makeConfiguration(),
                idTokenProvider: {
                    _ = providerCalls.increment()
                    return testCase.rawValue
                },
                protocolClasses: [ScriptedBackendUserURLProtocol.self]
            )

            await #expect(throws: authenticationFailure) {
                try await invoke(operation, on: service)
            }
            #expect(providerCalls.value == 1)
            #expect(script.requests.isEmpty)
            ScriptedBackendUserURLProtocol.reset()
        }
    }

    @Test("An ambiguous PUT is retried only by a second explicit call")
    func explicitPUTRetryIsSafe() async throws {
        let script = BackendUserTransportScript([
            .failure(.networkConnectionLost),
            .json(statusCode: 200, body: BackendUserFixture.user(completed: false))
        ])
        ScriptedBackendUserURLProtocol.script = script
        defer { ScriptedBackendUserURLProtocol.reset() }
        let tokens = BackendUserLockedCounter()
        let service = makeService(tokens: tokens)

        await #expect(throws: unavailableFailure) {
            try await service.resolveCurrentUser()
        }
        #expect(try await service.resolveCurrentUser() == BackendUserResolution(
            origin: .existing,
            onboardingCompleted: false
        ))

        #expect(tokens.value == 2)
        #expect(script.requests.count == 2)
        #expect(script.requests.allSatisfy { $0.httpMethod == "PUT" && $0.httpBody == nil })
        #expect(script.requests.map { $0.value(forHTTPHeaderField: "Authorization") } == [
            "Bearer fixture-token-1",
            "Bearer fixture-token-2"
        ])
    }

    @Test("An ambiguous PATCH is retried only by a second explicit monotonic call")
    func explicitPATCHRetryIsSafe() async throws {
        let script = BackendUserTransportScript([
            .failure(.networkConnectionLost),
            .json(statusCode: 200, body: BackendUserFixture.user(completed: true))
        ])
        ScriptedBackendUserURLProtocol.script = script
        defer { ScriptedBackendUserURLProtocol.reset() }
        let tokens = BackendUserLockedCounter()
        let service = makeService(tokens: tokens)

        await #expect(throws: unavailableFailure) {
            try await service.completeOnboarding()
        }
        try await service.completeOnboarding()

        #expect(tokens.value == 2)
        #expect(script.requests.count == 2)
        #expect(script.requests.allSatisfy {
            $0.httpMethod == "PATCH"
                && $0.httpBody == Data(#"{"onboardingCompleted":true}"#.utf8)
        })
        #expect(script.requests.map { $0.value(forHTTPHeaderField: "Authorization") } == [
            "Bearer fixture-token-1",
            "Bearer fixture-token-2"
        ])
    }

    @Test("Cancellation stops hanging PUT and PATCH transports", .timeLimit(.minutes(1)))
    func cancellationStopsTransport() async {
        for operation in BackendUserOperation.allCases {
            let script = BackendUserTransportScript([.hanging])
            let started = BackendUserTestSignal()
            let stopped = BackendUserTestSignal()
            ScriptedBackendUserURLProtocol.script = script
            ScriptedBackendUserURLProtocol.onStart = {
                Task { await started.fire() }
            }
            ScriptedBackendUserURLProtocol.onStop = {
                Task { await stopped.fire() }
            }
            let service = makeService()

            let task = Task {
                try await invoke(operation, on: service)
            }
            await started.wait()
            task.cancel()

            await #expect(throws: CancellationError.self) {
                try await task.value
            }
            await stopped.wait()
            #expect(script.requests.count == 1)
            ScriptedBackendUserURLProtocol.reset()
        }
    }

    @Test("Raw backend problem details are never exposed")
    func rawBackendDetailsAreSuppressed() async {
        let secret = "raw-backend-secret-detail"

        for operation in BackendUserOperation.allCases {
            let script = BackendUserTransportScript([
                .json(statusCode: 500, body: BackendUserFixture.problem(status: 500, detail: secret))
            ])
            ScriptedBackendUserURLProtocol.script = script
            let service = makeService()

            do {
                try await invoke(operation, on: service)
                Issue.record("Expected backend request failure")
            } catch let failure as ServiceFailure {
                #expect(failure == requestFailure)
                #expect(failure.errorDescription?.contains(secret) == false)
            } catch {
                Issue.record("Expected ServiceFailure, received \(error)")
            }
            ScriptedBackendUserURLProtocol.reset()
        }
    }

    @Test(
        "Missing, insecure, and hostless base URLs fail before authentication or transport",
        arguments: InvalidBackendUserConfiguration.allCases
    )
    func rejectsInvalidConfiguration(testCase: InvalidBackendUserConfiguration) async {
        for operation in BackendUserOperation.allCases {
            let script = BackendUserTransportScript([])
            ScriptedBackendUserURLProtocol.script = script
            let tokens = BackendUserLockedCounter()
            let service = makeService(
                configuration: makeConfiguration(baseURL: testCase.baseURL),
                tokens: tokens
            )

            await #expect(throws: ServiceFailure.configuration(
                "Backend user service configuration is incomplete."
            )) {
                try await invoke(operation, on: service)
            }
            #expect(tokens.value == 0)
            #expect(script.requests.isEmpty)
            ScriptedBackendUserURLProtocol.reset()
        }
    }

    @Test("Unconfirmed lifecycle contract fails before token acquisition or transport")
    func unconfirmedLifecycleContractPreventsTransport() async {
        for operation in BackendUserOperation.allCases {
            let script = BackendUserTransportScript([])
            ScriptedBackendUserURLProtocol.script = script
            let tokens = BackendUserLockedCounter()
            let service = makeService(
                configuration: makeConfiguration(lifecycleContractConfirmed: false),
                tokens: tokens
            )

            await #expect(throws: ServiceFailure.configuration(
                "Backend user service configuration is incomplete."
            )) {
                try await invoke(operation, on: service)
            }
            #expect(tokens.value == 0)
            #expect(script.requests.isEmpty)
            ScriptedBackendUserURLProtocol.reset()
        }
    }

    @Test("Lifecycle transport is independent of facial-data disclosure approval")
    func disclosureApprovalIsNotInspected() async throws {
        let script = BackendUserTransportScript([
            .json(statusCode: 201, body: BackendUserFixture.user(completed: false)),
            .json(statusCode: 200, body: BackendUserFixture.user(completed: true))
        ])
        ScriptedBackendUserURLProtocol.script = script
        defer { ScriptedBackendUserURLProtocol.reset() }
        let service = makeService(
            configuration: makeConfiguration(disclosuresApproved: false)
        )

        #expect(try await service.resolveCurrentUser() == BackendUserResolution(
            origin: .created,
            onboardingCompleted: false
        ))
        try await service.completeOnboarding()
        #expect(script.requests.count == 2)
    }

    @Test("Session configuration is ephemeral and disables persistent network state")
    func sessionConfigurationIsEphemeral() {
        let configuration = LiveBackendUserService.makeSessionConfiguration(
            protocolClasses: [ScriptedBackendUserURLProtocol.self]
        )

        #expect(configuration.identifier == nil)
        #expect(configuration.urlCache == nil)
        #expect(configuration.requestCachePolicy == .reloadIgnoringLocalCacheData)
        #expect(configuration.httpCookieStorage == nil)
        #expect(configuration.httpCookieAcceptPolicy == .never)
        #expect(configuration.httpShouldSetCookies == false)
        #expect(configuration.urlCredentialStorage == nil)
        #expect(configuration.sessionSendsLaunchEvents == false)
    }

    @Test("Responses and cookies are not reused between explicit calls")
    func responsesAndCookiesAreNotPersisted() async throws {
        let script = BackendUserTransportScript([
            .json(
                statusCode: 200,
                body: BackendUserFixture.user(completed: false),
                headers: [
                    "Cache-Control": "public, max-age=3600",
                    "Set-Cookie": "sensitive=value"
                ]
            ),
            .json(statusCode: 200, body: BackendUserFixture.user(completed: true))
        ])
        ScriptedBackendUserURLProtocol.script = script
        defer { ScriptedBackendUserURLProtocol.reset() }
        let service = makeService()

        #expect(try await service.resolveCurrentUser().onboardingCompleted == false)
        #expect(try await service.resolveCurrentUser().onboardingCompleted == true)

        #expect(script.requests.count == 2)
        #expect(script.requests.allSatisfy {
            $0.cachePolicy == .reloadIgnoringLocalCacheData
        })
        #expect(script.requests.allSatisfy {
            $0.value(forHTTPHeaderField: "Cookie") == nil
        })
    }

    private func makeService(
        configuration: AppConfiguration? = nil,
        tokens: BackendUserLockedCounter = BackendUserLockedCounter()
    ) -> LiveBackendUserService {
        LiveBackendUserService(
            configuration: configuration ?? makeConfiguration(),
            idTokenProvider: {
                "fixture-token-\(tokens.increment())"
            },
            protocolClasses: [ScriptedBackendUserURLProtocol.self]
        )
    }

    private func makeConfiguration(
        baseURL: URL? = URL(string: "https://api.notmeyet.app"),
        disclosuresApproved: Bool = true,
        lifecycleContractConfirmed: Bool = true
    ) -> AppConfiguration {
        AppConfiguration(
            mode: .live,
            googleClientID: "google-client",
            revenueCatAPIKey: "revenuecat-key",
            revenueCatEntitlementID: "pro",
            looksAPIBaseURL: baseURL,
            termsURL: URL(string: "https://example.com/terms"),
            privacyURL: URL(string: "https://example.com/privacy"),
            facialDataDisclosuresApproved: disclosuresApproved,
            backendUserLifecycleContractConfirmed: lifecycleContractConfirmed
        )
    }

    private func invoke(
        _ operation: BackendUserOperation,
        on service: LiveBackendUserService
    ) async throws {
        switch operation {
        case .resolve:
            _ = try await service.resolveCurrentUser()
        case .complete:
            try await service.completeOnboarding()
        }
    }
}

nonisolated enum BackendUserPUTCase: CaseIterable, Sendable, CustomTestStringConvertible {
    case createdIncomplete
    case existingIncomplete
    case existingComplete
    case invalidCreatedComplete
    case missing
    case null
    case string
    case malformed
    case noContent
    case redirect
    case badRequest
    case unauthorized
    case serverError

    var testDescription: String {
        switch self {
        case .createdIncomplete: "201 + false"
        case .existingIncomplete: "200 + false"
        case .existingComplete: "200 + true"
        case .invalidCreatedComplete: "invalid 201 + true"
        case .missing: "missing"
        case .null: "null"
        case .string: "string"
        case .malformed: "malformed"
        case .noContent: "204"
        case .redirect: "302"
        case .badRequest: "400"
        case .unauthorized: "401"
        case .serverError: "500"
        }
    }

    var stub: BackendUserStub {
        switch self {
        case .createdIncomplete:
            .json(statusCode: 201, body: BackendUserFixture.user(completed: false))
        case .existingIncomplete:
            .json(statusCode: 200, body: BackendUserFixture.user(completed: false))
        case .existingComplete:
            .json(statusCode: 200, body: BackendUserFixture.user(completed: true))
        case .invalidCreatedComplete:
            .json(statusCode: 201, body: BackendUserFixture.user(completed: true))
        case .missing:
            .json(statusCode: 200, body: BackendUserFixture.missingCompletion)
        case .null:
            .json(statusCode: 200, body: BackendUserFixture.user(completionJSON: "null"))
        case .string:
            .json(statusCode: 200, body: BackendUserFixture.user(completionJSON: #""true""#))
        case .malformed:
            .json(statusCode: 200, body: BackendUserFixture.malformed)
        case .noContent:
            .json(statusCode: 204, body: BackendUserFixture.user(completed: false))
        case .redirect:
            .json(
                statusCode: 302,
                body: BackendUserFixture.user(completed: false),
                headers: ["Location": "https://api.example.com/redirected"]
            )
        case .badRequest:
            .json(statusCode: 400, body: BackendUserFixture.problem(status: 400))
        case .unauthorized:
            .json(statusCode: 401, body: BackendUserFixture.problem(status: 401))
        case .serverError:
            .json(statusCode: 500, body: BackendUserFixture.problem(status: 500))
        }
    }

    var expectedResolution: BackendUserResolution? {
        switch self {
        case .createdIncomplete:
            BackendUserResolution(origin: .created, onboardingCompleted: false)
        case .existingIncomplete:
            BackendUserResolution(origin: .existing, onboardingCompleted: false)
        case .existingComplete:
            BackendUserResolution(origin: .existing, onboardingCompleted: true)
        default:
            nil
        }
    }

    var expectedFailure: ServiceFailure? {
        switch self {
        case .createdIncomplete, .existingIncomplete, .existingComplete:
            nil
        case .invalidCreatedComplete, .missing, .null, .string, .malformed:
            .transport("The account service returned an unusable response. Try again.")
        case .unauthorized:
            .authentication("Your session could not be verified. Please sign in again.")
        case .noContent, .redirect, .badRequest, .serverError:
            .transport("The account service could not complete the request. Try again.")
        }
    }
}

nonisolated enum BackendUserPATCHCase: CaseIterable, Sendable, CustomTestStringConvertible {
    case accepted
    case invalidFalse
    case missing
    case null
    case string
    case malformed
    case noContent
    case redirect
    case badRequest
    case unauthorized
    case serverError

    var testDescription: String {
        switch self {
        case .accepted: "accepted 200 + true"
        case .invalidFalse: "invalid 200 + false"
        case .missing: "missing"
        case .null: "null"
        case .string: "string"
        case .malformed: "malformed"
        case .noContent: "204"
        case .redirect: "302"
        case .badRequest: "400"
        case .unauthorized: "401"
        case .serverError: "500"
        }
    }

    var stub: BackendUserStub {
        switch self {
        case .accepted:
            .json(statusCode: 200, body: BackendUserFixture.user(completed: true))
        case .invalidFalse:
            .json(statusCode: 200, body: BackendUserFixture.user(completed: false))
        case .missing:
            .json(statusCode: 200, body: BackendUserFixture.missingCompletion)
        case .null:
            .json(statusCode: 200, body: BackendUserFixture.user(completionJSON: "null"))
        case .string:
            .json(statusCode: 200, body: BackendUserFixture.user(completionJSON: #""true""#))
        case .malformed:
            .json(statusCode: 200, body: BackendUserFixture.malformed)
        case .noContent:
            .json(statusCode: 204, body: BackendUserFixture.user(completed: true))
        case .redirect:
            .json(
                statusCode: 302,
                body: BackendUserFixture.user(completed: true),
                headers: ["Location": "https://api.example.com/redirected"]
            )
        case .badRequest:
            .json(statusCode: 400, body: BackendUserFixture.problem(status: 400))
        case .unauthorized:
            .json(statusCode: 401, body: BackendUserFixture.problem(status: 401))
        case .serverError:
            .json(statusCode: 500, body: BackendUserFixture.problem(status: 500))
        }
    }

    var isAccepted: Bool {
        self == .accepted
    }

    var expectedFailure: ServiceFailure? {
        switch self {
        case .accepted:
            nil
        case .invalidFalse, .missing, .null, .string, .malformed:
            .transport("The account service returned an unusable response. Try again.")
        case .unauthorized:
            .authentication("Your session could not be verified. Please sign in again.")
        case .noContent, .redirect, .badRequest, .serverError:
            .transport("The account service could not complete the request. Try again.")
        }
    }
}

nonisolated enum BackendUserOperation: CaseIterable, Sendable {
    case resolve
    case complete
}

nonisolated enum InvalidBackendUserToken: String, CaseIterable, Sendable, CustomTestStringConvertible {
    case empty = ""
    case leadingWhitespace = " fixture-token"
    case trailingWhitespace = "fixture-token "
    case embeddedWhitespace = "fixture token"
    case tab = "fixture-token\t"
    case crlf = "fixture-token\r\nX-Injected: value"

    var testDescription: String {
        switch self {
        case .empty: "empty"
        case .leadingWhitespace: "leading whitespace"
        case .trailingWhitespace: "trailing whitespace"
        case .embeddedWhitespace: "embedded whitespace"
        case .tab: "tab"
        case .crlf: "CRLF"
        }
    }
}

nonisolated enum InvalidBackendUserConfiguration: CaseIterable, Sendable, CustomTestStringConvertible {
    case missing
    case insecure
    case hostless

    var testDescription: String {
        switch self {
        case .missing: "missing"
        case .insecure: "HTTP"
        case .hostless: "hostless HTTPS"
        }
    }

    var baseURL: URL? {
        switch self {
        case .missing: nil
        case .insecure: URL(string: "http://api.notmeyet.app")
        case .hostless: URL(string: "https:///api-root")
        }
    }
}

nonisolated private enum BackendUserFixture {
    static func user(completed: Bool) -> String {
        user(completionJSON: completed ? "true" : "false")
    }

    static func user(completionJSON: String) -> String {
        """
        {
          "id":"fixture-user-id",
          "firebaseUid":"fixture-firebase-uid",
          "onboardingCompleted":\(completionJSON),
          "wallet":{"creditBalance":50,"subscription":null}
        }
        """
    }

    static let missingCompletion = """
    {
      "id":"fixture-user-id",
      "firebaseUid":"fixture-firebase-uid",
      "wallet":{"creditBalance":50,"subscription":null}
    }
    """

    static let malformed = """
    {"id":"fixture-user-id","onboardingCompleted":
    """

    static func problem(status: Int, detail: String = "fixture backend detail") -> String {
        """
        {
          "type":"https://api.example.com/problems/request",
          "title":"Request failed",
          "status":\(status),
          "detail":"\(detail)",
          "instance":"/api/v1/users/me",
          "properties":null
        }
        """
    }
}

nonisolated private struct BackendUserSecretError: Error, CustomStringConvertible, Sendable {
    let secret: String
    var description: String { secret }
}

nonisolated private final class BackendUserLockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    var value: Int {
        lock.withLock { storage }
    }

    @discardableResult
    func increment() -> Int {
        lock.withLock {
            storage += 1
            return storage
        }
    }
}

nonisolated enum BackendUserStub: Sendable {
    case response(statusCode: Int, headers: [String: String], data: Data)
    case failure(URLError.Code)
    case hanging

    static func json(
        statusCode: Int,
        body: String,
        headers: [String: String] = [:]
    ) -> BackendUserStub {
        var responseHeaders = headers
        responseHeaders["Content-Type"] = "application/json"
        return .response(
            statusCode: statusCode,
            headers: responseHeaders,
            data: Data(body.utf8)
        )
    }
}

nonisolated private final class BackendUserTransportScript: @unchecked Sendable {
    private let lock = NSLock()
    private var stubs: [BackendUserStub]
    private var recordedRequests: [URLRequest] = []

    init(_ stubs: [BackendUserStub]) {
        self.stubs = stubs
    }

    var requests: [URLRequest] {
        lock.withLock { recordedRequests }
    }

    func next(for request: URLRequest) throws -> BackendUserStub {
        try lock.withLock {
            recordedRequests.append(request)
            guard stubs.isEmpty == false else { throw URLError(.badServerResponse) }
            return stubs.removeFirst()
        }
    }
}

private actor BackendUserTestSignal {
    private var hasFired = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard hasFired == false else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func fire() {
        hasFired = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}

nonisolated private final class ScriptedBackendUserURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var script: BackendUserTransportScript?
    nonisolated(unsafe) static var onStart: (@Sendable () -> Void)?
    nonisolated(unsafe) static var onStop: (@Sendable () -> Void)?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.onStart?()
        guard let script = Self.script else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            switch try script.next(for: requestWithCapturedBody(request)) {
            case .failure(let code):
                client?.urlProtocol(self, didFailWithError: URLError(code))
            case .hanging:
                return
            case .response(let statusCode, let headers, let data):
                guard
                    let url = request.url,
                    let response = HTTPURLResponse(
                        url: url,
                        statusCode: statusCode,
                        httpVersion: "HTTP/1.1",
                        headerFields: headers
                    )
                else {
                    client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                    return
                }
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            }
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
        Self.onStop?()
    }

    static func reset() {
        script = nil
        onStart = nil
        onStop = nil
    }

    private func requestWithCapturedBody(_ request: URLRequest) -> URLRequest {
        guard request.httpBody == nil, let stream = request.httpBodyStream else { return request }
        stream.open()
        defer { stream.close() }

        var body = Data()
        var buffer = [UInt8](repeating: 0, count: 16_384)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            body.append(buffer, count: count)
        }

        var capturedRequest = request
        capturedRequest.httpBodyStream = nil
        capturedRequest.httpBody = body
        return capturedRequest
    }
}
