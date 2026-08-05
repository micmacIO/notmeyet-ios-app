import Foundation
import Testing
@testable import notmeyet

@Suite("Live Looks fail-closed transport", .serialized)
@MainActor
struct LiveLooksServiceTests {
    @Test("Missing OpenAPI contracts send no analysis or generation request")
    func unavailableContractSendsNoRequest() async {
        await expectNoRequest(
            disclosuresApproved: true,
            expected: .configuration(
                "Looksmaxxing OpenAPI request and response contracts have not been supplied."
            )
        )
    }

    @Test("Unapproved facial-data disclosures send no request")
    func unapprovedDisclosuresSendNoRequest() async {
        await expectNoRequest(
            disclosuresApproved: false,
            expected: .configuration(
                "Looksmaxxing configuration and facial-data disclosures are incomplete."
            )
        )
    }

    private func expectNoRequest(
        disclosuresApproved: Bool,
        expected: ServiceFailure
    ) async {
        let recorder = LooksRequestRecorder()
        RecordingLooksURLProtocol.onRequest = { request in
            recorder.record(request)
        }
        defer { RecordingLooksURLProtocol.onRequest = nil }
        let configuration = AppConfiguration(
            mode: .live,
            googleClientID: "google-client",
            revenueCatAPIKey: "revenuecat-key",
            revenueCatEntitlementID: "pro",
            looksAPIBaseURL: URL(string: "https://api.example.com")!,
            looksAuthToken: "looks-token",
            termsURL: URL(string: "https://example.com/terms")!,
            privacyURL: URL(string: "https://example.com/privacy")!,
            facialDataDisclosuresApproved: disclosuresApproved
        )
        let client = LiveLooksService(
            configuration: configuration,
            protocolClasses: [RecordingLooksURLProtocol.self]
        ).client()
        let photo = PreparedPhoto(
            displayData: Data([0x01]),
            uploadData: Data([0x02]),
            pixelWidth: 1,
            pixelHeight: 1
        )

        await #expect(throws: expected) {
            try await client.analyze(photo)
        }
        await #expect(throws: expected) {
            try await client.generateLook(photo, nil)
        }
        #expect(recorder.requests.isEmpty)
    }
}

private final class LooksRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URLRequest] = []

    var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func record(_ request: URLRequest) {
        lock.lock()
        storage.append(request)
        lock.unlock()
    }
}

private final class RecordingLooksURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var onRequest: (@Sendable (URLRequest) -> Void)?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.onRequest?(request)
        client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
    }

    override func stopLoading() {}
}
