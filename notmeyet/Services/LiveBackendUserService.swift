import Foundation

actor LiveBackendUserService {
    private let configuration: AppConfiguration
    private let idTokenProvider: @Sendable () async throws -> String
    private let sessionDelegate: BackendUserSessionDelegate
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(
        configuration: AppConfiguration,
        idTokenProvider: @escaping @Sendable () async throws -> String,
        protocolClasses: [AnyClass]? = nil
    ) {
        self.configuration = configuration
        self.idTokenProvider = idTokenProvider

        let sessionDelegate = BackendUserSessionDelegate()
        self.sessionDelegate = sessionDelegate
        self.session = URLSession(
            configuration: Self.makeSessionConfiguration(protocolClasses: protocolClasses),
            delegate: sessionDelegate,
            delegateQueue: nil
        )
    }

    func resolveCurrentUser() async throws -> BackendUserResolution {
        try Task.checkCancellation()
        let baseURL = try validatedBaseURL()
        var request = URLRequest(url: currentUserURL(relativeTo: baseURL))
        request.httpMethod = "PUT"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request = try await authorized(request)

        let response = try await execute(request)
        guard response.http.statusCode == 200 || response.http.statusCode == 201 else {
            throw safeHTTPFailure(for: response.http.statusCode)
        }
        guard let user = try? decoder.decode(CurrentUserResponse.self, from: response.data) else {
            throw invalidResponseFailure
        }

        switch (response.http.statusCode, user.onboardingCompleted) {
        case (201, false):
            return BackendUserResolution(origin: .created, onboardingCompleted: false)
        case (200, false):
            return BackendUserResolution(origin: .existing, onboardingCompleted: false)
        case (200, true):
            return BackendUserResolution(origin: .existing, onboardingCompleted: true)
        default:
            throw invalidResponseFailure
        }
    }

    func completeOnboarding() async throws {
        try Task.checkCancellation()
        let baseURL = try validatedBaseURL()
        var request = URLRequest(url: currentUserURL(relativeTo: baseURL))
        request.httpMethod = "PATCH"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(#"{"onboardingCompleted":true}"#.utf8)
        request = try await authorized(request)

        let response = try await execute(request)
        guard response.http.statusCode == 200 else {
            throw safeHTTPFailure(for: response.http.statusCode)
        }
        guard
            let user = try? decoder.decode(CurrentUserResponse.self, from: response.data),
            user.onboardingCompleted
        else {
            throw invalidResponseFailure
        }
    }

    nonisolated func client() -> BackendUserClient {
        BackendUserClient(
            resolveCurrentUser: { [self] in
                try await resolveCurrentUser()
            },
            completeOnboarding: { [self] in
                try await completeOnboarding()
            }
        )
    }

    nonisolated static func makeSessionConfiguration(
        protocolClasses: [AnyClass]? = nil
    ) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        if let protocolClasses {
            configuration.protocolClasses = protocolClasses
        }
        return configuration
    }

    private func validatedBaseURL() throws -> URL {
        guard
            configuration.hasConfirmedBackendUserLifecycleConfiguration,
            let baseURL = configuration.looksAPIBaseURL,
            baseURL.host?.isEmpty == false
        else {
            throw ServiceFailure.configuration(
                "Backend user service configuration is incomplete."
            )
        }
        return baseURL
    }

    private func currentUserURL(relativeTo baseURL: URL) -> URL {
        ["api", "v1", "users", "me"].reduce(baseURL) { url, component in
            url.appendingPathComponent(component, isDirectory: false)
        }
    }

    private func authorized(_ request: URLRequest) async throws -> URLRequest {
        try Task.checkCancellation()
        let token: String
        do {
            token = try await idTokenProvider()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            throw authenticationFailure
        }
        try Task.checkCancellation()

        guard
            token.isEmpty == false,
            token.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
        else {
            throw authenticationFailure
        }

        var authorizedRequest = request
        authorizedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        authorizedRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        return authorizedRequest
    }

    private func execute(_ request: URLRequest) async throws -> APIResponse {
        try Task.checkCancellation()
        do {
            let (data, response) = try await session.data(for: request)
            try Task.checkCancellation()
            guard let http = response as? HTTPURLResponse else {
                throw APIRequestError.noHTTPResponse
            }
            return APIResponse(data: data, http: http)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            throw unavailableFailure
        }
    }

    private func safeHTTPFailure(for statusCode: Int) -> ServiceFailure {
        if statusCode == 401 || statusCode == 403 {
            return authenticationFailure
        }
        return .transport("The account service could not complete the request. Try again.")
    }

    private var authenticationFailure: ServiceFailure {
        .authentication("Your session could not be verified. Please sign in again.")
    }

    private var unavailableFailure: ServiceFailure {
        .transport("The account service is unavailable. Try again.")
    }

    private var invalidResponseFailure: ServiceFailure {
        .transport("The account service returned an unusable response. Try again.")
    }
}

private extension LiveBackendUserService {
    struct APIResponse: Sendable {
        let data: Data
        let http: HTTPURLResponse
    }

    struct CurrentUserResponse: Decodable, Sendable {
        let onboardingCompleted: Bool
    }

    enum APIRequestError: Error {
        case noHTTPResponse
    }
}

nonisolated private final class BackendUserSessionDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
