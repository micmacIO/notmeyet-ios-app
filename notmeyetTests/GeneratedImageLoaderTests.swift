import Foundation
import Testing
import UIKit
@testable import notmeyet

@Suite("Generated image loading", .serialized)
@MainActor
struct GeneratedImageLoaderTests {
    private let secureURL = URL(string: "https://example.com/generated.png")!

    @Test("Secure image responses load without cache reuse")
    func loadsSecureImage() async throws {
        let image = try makeImageData(color: .systemPink)
        let responses = StubResponseSequence([
            StubImageResponse(statusCode: 200, mimeType: "image/png", data: image)
        ])
        GeneratedImageURLProtocol.handler = { request in
            try responses.next(for: request)
        }
        defer { GeneratedImageURLProtocol.reset() }
        let loader = makeLoader()

        #expect(try await loader.load(url: secureURL) == image)
        let requests = responses.recordedRequests
        #expect(requests.count == 1)
        #expect(requests.first?.cachePolicy == .reloadIgnoringLocalCacheData)
    }

    @Test("Insecure URLs are rejected before transport")
    func rejectsInsecureURL() async {
        let responses = StubResponseSequence([])
        GeneratedImageURLProtocol.handler = { request in
            try responses.next(for: request)
        }
        defer { GeneratedImageURLProtocol.reset() }
        let loader = makeLoader()
        let insecureURL = URL(string: "http://example.com/generated.png")!

        await #expect(
            throws: ServiceFailure.transport("The generated image URL is not secure.")
        ) {
            try await loader.load(url: insecureURL)
        }
        #expect(responses.recordedRequests.isEmpty)
    }

    @Test("Non-success status fails closed")
    func rejectsNonSuccessStatus() async throws {
        defer { GeneratedImageURLProtocol.reset() }
        let image = try makeImageData(color: .systemPink)

        await expectFailure(
            StubImageResponse(statusCode: 503, mimeType: "image/png", data: image),
            expected: .transport("The generated image is unavailable. Try again.")
        )
    }

    @Test("Unsupported MIME type fails closed")
    func rejectsUnsupportedMIMEType() async throws {
        defer { GeneratedImageURLProtocol.reset() }
        let image = try makeImageData(color: .systemPink)

        await expectFailure(
            StubImageResponse(statusCode: 200, mimeType: "text/plain", data: image),
            expected: .transport("The generated result is not a supported image.")
        )
    }

    @Test("Invalid image data fails closed")
    func rejectsInvalidImageData() async {
        defer { GeneratedImageURLProtocol.reset() }

        await expectFailure(
            StubImageResponse(statusCode: 200, mimeType: "image/png", data: Data("invalid".utf8)),
            expected: .transport("The generated result is too large or invalid.")
        )
    }

    @Test("Oversized image data fails closed")
    func rejectsOversizedImageData() async throws {
        defer { GeneratedImageURLProtocol.reset() }
        let image = try makeImageData(color: .systemPink)

        await expectFailure(
            StubImageResponse(statusCode: 200, mimeType: "image/png", data: image),
            maximumBytes: 1,
            expected: .transport("The generated result is too large or invalid.")
        )
    }

    @Test("A failed load can retry and successful responses are not cached")
    func retriesWithoutCacheReuse() async throws {
        let firstImage = try makeImageData(color: .systemPink)
        let secondImage = try makeImageData(color: .systemBlue)
        let responses = StubResponseSequence([
            StubImageResponse(statusCode: 503, mimeType: "image/png", data: Data()),
            StubImageResponse(statusCode: 200, mimeType: "image/png", data: firstImage),
            StubImageResponse(statusCode: 200, mimeType: "image/png", data: secondImage)
        ])
        GeneratedImageURLProtocol.handler = { request in
            try responses.next(for: request)
        }
        defer { GeneratedImageURLProtocol.reset() }
        let loader = makeLoader()

        await #expect(
            throws: ServiceFailure.transport("The generated image is unavailable. Try again.")
        ) {
            try await loader.load(url: secureURL)
        }
        #expect(try await loader.load(url: secureURL) == firstImage)
        #expect(try await loader.load(url: secureURL) == secondImage)
        #expect(responses.recordedRequests.count == 3)
        #expect(
            responses.recordedRequests.allSatisfy {
                $0.cachePolicy == .reloadIgnoringLocalCacheData
            }
        )
    }

    @Test("Cancellation stops transport and propagates CancellationError")
    func propagatesCancellation() async {
        let started = TestSignal()
        let stopped = TestSignal()
        GeneratedImageURLProtocol.handler = { _ in nil }
        GeneratedImageURLProtocol.onStart = {
            Task { await started.fire() }
        }
        GeneratedImageURLProtocol.onStop = {
            Task { await stopped.fire() }
        }
        defer { GeneratedImageURLProtocol.reset() }
        let loader = makeLoader()

        let task = Task {
            try await loader.load(url: secureURL)
        }
        await started.wait()
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        await stopped.wait()
    }

    private func makeLoader(maximumBytes: Int = 12 * 1_024 * 1_024) -> GeneratedImageLoader {
        GeneratedImageLoader(
            maximumBytes: maximumBytes,
            protocolClasses: [GeneratedImageURLProtocol.self]
        )
    }

    private func expectFailure(
        _ response: StubImageResponse,
        maximumBytes: Int = 12 * 1_024 * 1_024,
        expected: ServiceFailure
    ) async {
        let responses = StubResponseSequence([response])
        GeneratedImageURLProtocol.handler = { request in
            try responses.next(for: request)
        }
        let loader = makeLoader(maximumBytes: maximumBytes)

        await #expect(throws: expected) {
            try await loader.load(url: secureURL)
        }
    }

    private func makeImageData(color: UIColor) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2), format: format)
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        return try #require(image.pngData())
    }
}

private struct StubImageResponse: Sendable {
    let statusCode: Int
    let mimeType: String
    let data: Data
}

private final class StubResponseSequence: @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [StubImageResponse]
    private var requests: [URLRequest] = []

    init(_ responses: [StubImageResponse]) {
        self.responses = responses
    }

    var recordedRequests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }

    func next(for request: URLRequest) throws -> StubImageResponse {
        lock.lock()
        defer { lock.unlock() }
        requests.append(request)
        guard responses.isEmpty == false else {
            throw URLError(.badServerResponse)
        }
        return responses.removeFirst()
    }
}

private actor TestSignal {
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

private final class GeneratedImageURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> StubImageResponse?

    nonisolated(unsafe) static var handler: Handler?
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
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            guard let stub = try handler(request) else { return }
            guard
                let url = request.url,
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: stub.statusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: [
                        "Content-Type": stub.mimeType,
                        "Cache-Control": "public, max-age=3600"
                    ]
                )
            else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
            client?.urlProtocol(self, didLoad: stub.data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
        Self.onStop?()
    }

    static func reset() {
        handler = nil
        onStart = nil
        onStop = nil
    }
}
