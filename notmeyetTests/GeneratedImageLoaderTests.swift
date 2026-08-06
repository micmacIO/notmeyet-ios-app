import Foundation
import Testing
import UIKit
@testable import notmeyet

@Suite("Generated image loading", .serialized)
@MainActor
struct GeneratedImageLoaderTests {
    private let secureURL = URL(string: "https://example.com/generated.png")!

    @Test("Valid raster responses load without cookies or cache reuse")
    func loadsValidRasterEphemerally() async throws {
        let firstImage = try makeImageData(color: .systemPink)
        let secondImage = try makeImageData(color: .systemBlue)
        let responses = ImageResponseSequence([
            ImageStubResponse(
                statusCode: 200,
                headers: [
                    "Content-Type": "image/png",
                    "Cache-Control": "public, max-age=3600",
                    "Set-Cookie": "sensitive=value"
                ],
                data: firstImage
            ),
            ImageStubResponse(
                statusCode: 200,
                headers: ["Content-Type": "image/png"],
                data: secondImage
            )
        ])
        GeneratedImageURLProtocol.handler = { request in try responses.next(for: request) }
        defer { GeneratedImageURLProtocol.reset() }
        let loader = makeLoader()

        #expect(try await loader.load(url: secureURL) == firstImage)
        #expect(try await loader.load(url: secureURL) == secondImage)
        #expect(responses.requests.count == 2)
        #expect(responses.requests.allSatisfy {
            $0.cachePolicy == .reloadIgnoringLocalCacheData
        })
        #expect(responses.requests.allSatisfy {
            $0.value(forHTTPHeaderField: "Cookie") == nil
        })
    }

    @Test("Initial and final response URLs must use HTTPS")
    func rejectsInsecureInitialAndFinalURLs() async throws {
        let responses = ImageResponseSequence([])
        GeneratedImageURLProtocol.handler = { request in try responses.next(for: request) }
        defer { GeneratedImageURLProtocol.reset() }
        let loader = makeLoader()

        await #expect(throws: ServiceFailure.transport(
            "The generated image URL is not secure."
        )) {
            try await loader.load(url: URL(string: "http://example.com/generated.png")!)
        }
        #expect(responses.requests.isEmpty)

        let image = try makeImageData(color: .systemPink)
        let redirected = ImageResponseSequence([
            ImageStubResponse(
                statusCode: 200,
                headers: ["Content-Type": "image/png"],
                data: image,
                finalURL: URL(string: "http://cdn.example.com/generated.png")
            )
        ])
        GeneratedImageURLProtocol.handler = { request in try redirected.next(for: request) }

        await #expect(throws: ServiceFailure.transport(
            "The generated image URL is not secure."
        )) {
            try await loader.load(url: secureURL)
        }
        #expect(redirected.requests.count == 1)
    }

    @Test("Status and unsupported MIME types fail closed")
    func validatesHTTPEnvelope() async throws {
        let image = try makeImageData(color: .systemPink)

        await expectFailure(
            ImageStubResponse(
                statusCode: 503,
                headers: ["Content-Type": "image/png"],
                data: image
            ),
            expected: .transport("The generated image is unavailable. Try again.")
        )
        await expectFailure(
            ImageStubResponse(
                statusCode: 200,
                headers: ["Content-Type": "text/plain"],
                data: image
            ),
            expected: .transport("The generated result is not a supported image.")
        )
    }

    @Test("Missing and empty image MIME values fail while parameters are accepted")
    func validatesImageMIMEValues() async throws {
        let image = try makeImageData(color: .systemPink)

        for headers: [String: String] in [
            [:],
            ["Content-Type": ""],
            ["Content-Type": "image/"]
        ] {
            await expectFailure(
                ImageStubResponse(statusCode: 200, headers: headers, data: image),
                expected: .transport("The generated result is not a supported image.")
            )
        }

        let response = ImageStubResponse(
            statusCode: 200,
            headers: ["Content-Type": "image/png; charset=binary"],
            data: image
        )
        #expect(try await load(response) == image)
    }

    @Test("Encoded byte limit accepts equality and rejects one over")
    func validatesEncodedByteBoundary() async throws {
        let image = try makeImageData(color: .systemPink)
        let response = ImageStubResponse(
            statusCode: 200,
            headers: ["Content-Type": "image/png"],
            data: image
        )

        #expect(try await load(response, maximumBytes: image.count) == image)
        await expectFailure(
            response,
            maximumBytes: image.count - 1,
            expected: .transport("The generated result is too large or invalid.")
        )
    }

    @Test("Default encoded byte limit is exactly 12 MiB")
    func locksDefaultEncodedByteLimit() async throws {
        let image = try makeImageData(color: .systemPink)
        let twelveMiB = 12 * 1_024 * 1_024
        let responses = ImageResponseSequence([
            ImageStubResponse(
                statusCode: 200,
                headers: [
                    "Content-Type": "image/png",
                    "Content-Length": "\(twelveMiB)"
                ],
                data: image
            ),
            ImageStubResponse(
                statusCode: 200,
                headers: [
                    "Content-Type": "image/png",
                    "Content-Length": "\(twelveMiB + 1)"
                ],
                data: image
            )
        ])
        GeneratedImageURLProtocol.handler = { request in try responses.next(for: request) }
        defer { GeneratedImageURLProtocol.reset() }
        let loader = GeneratedImageLoader(protocolClasses: [GeneratedImageURLProtocol.self])

        #expect(try await loader.load(url: secureURL) == image)
        await #expect(throws: ServiceFailure.transport(
            "The generated result is too large or invalid."
        )) {
            try await loader.load(url: secureURL)
        }
        #expect(responses.requests.count == 2)
    }

    @Test("Dimension limit accepts equality and rejects one over")
    func validatesDimensionBoundary() async throws {
        let image = try makeImageData(width: 3, height: 2, color: .systemPink)
        let response = ImageStubResponse(
            statusCode: 200,
            headers: ["Content-Type": "image/png"],
            data: image
        )

        #expect(try await load(response, maximumDimension: 3) == image)

        await expectFailure(
            response,
            maximumDimension: 2,
            expected: .transport("The generated result is too large or invalid.")
        )
    }

    @Test("Decoded-pixel limit accepts equality and rejects one over")
    func validatesDecodedPixelBoundary() async throws {
        let image = try makeImageData(width: 3, height: 2, color: .systemPink)
        let response = ImageStubResponse(
            statusCode: 200,
            headers: ["Content-Type": "image/png"],
            data: image
        )

        #expect(try await load(response, maximumDecodedPixels: 6) == image)
        await expectFailure(
            response,
            maximumDecodedPixels: 5,
            expected: .transport("The generated result is too large or invalid.")
        )
    }

    @Test("Malformed image bytes are rejected even with an image MIME type")
    func rejectsInvalidRaster() async {
        await expectFailure(
            ImageStubResponse(
                statusCode: 200,
                headers: ["Content-Type": "image/png"],
                data: Data("not-an-image".utf8)
            ),
            expected: .transport("The generated result is too large or invalid.")
        )
    }

    @Test("Cancellation stops transport and propagates CancellationError")
    func propagatesCancellation() async {
        let started = ImageTestSignal()
        let stopped = ImageTestSignal()
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

    private func makeLoader(
        maximumBytes: Int = 12 * 1_024 * 1_024,
        maximumDimension: Int = 8_192,
        maximumDecodedPixels: Int64 = 40_000_000
    ) -> GeneratedImageLoader {
        GeneratedImageLoader(
            maximumBytes: maximumBytes,
            maximumDimension: maximumDimension,
            maximumDecodedPixels: maximumDecodedPixels,
            protocolClasses: [GeneratedImageURLProtocol.self]
        )
    }

    private func expectFailure(
        _ response: ImageStubResponse,
        maximumBytes: Int = 12 * 1_024 * 1_024,
        maximumDimension: Int = 8_192,
        maximumDecodedPixels: Int64 = 40_000_000,
        expected: ServiceFailure
    ) async {
        await #expect(throws: expected) {
            try await load(
                response,
                maximumBytes: maximumBytes,
                maximumDimension: maximumDimension,
                maximumDecodedPixels: maximumDecodedPixels
            )
        }
    }

    private func load(
        _ response: ImageStubResponse,
        maximumBytes: Int = 12 * 1_024 * 1_024,
        maximumDimension: Int = 8_192,
        maximumDecodedPixels: Int64 = 40_000_000
    ) async throws -> Data {
        let responses = ImageResponseSequence([response])
        GeneratedImageURLProtocol.handler = { request in try responses.next(for: request) }
        defer { GeneratedImageURLProtocol.reset() }
        let loader = makeLoader(
            maximumBytes: maximumBytes,
            maximumDimension: maximumDimension,
            maximumDecodedPixels: maximumDecodedPixels
        )

        return try await loader.load(url: secureURL)
    }

    private func makeImageData(
        width: Int = 2,
        height: Int = 2,
        color: UIColor
    ) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: width, height: height),
            format: format
        )
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return try #require(image.pngData())
    }
}

nonisolated private struct ImageStubResponse: Sendable {
    let statusCode: Int
    let headers: [String: String]
    let data: Data
    let finalURL: URL?

    init(
        statusCode: Int,
        headers: [String: String],
        data: Data,
        finalURL: URL? = nil
    ) {
        self.statusCode = statusCode
        self.headers = headers
        self.data = data
        self.finalURL = finalURL
    }
}

nonisolated private final class ImageResponseSequence: @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [ImageStubResponse]
    private var recordedRequests: [URLRequest] = []

    init(_ responses: [ImageStubResponse]) {
        self.responses = responses
    }

    var requests: [URLRequest] {
        lock.withLock { recordedRequests }
    }

    func next(for request: URLRequest) throws -> ImageStubResponse {
        try lock.withLock {
            recordedRequests.append(request)
            guard responses.isEmpty == false else { throw URLError(.badServerResponse) }
            return responses.removeFirst()
        }
    }
}

private actor ImageTestSignal {
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

nonisolated private final class GeneratedImageURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> ImageStubResponse?

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
                let responseURL = stub.finalURL ?? request.url,
                let response = HTTPURLResponse(
                    url: responseURL,
                    statusCode: stub.statusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: stub.headers
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
