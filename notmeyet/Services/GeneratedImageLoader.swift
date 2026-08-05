import Foundation
import UIKit

actor GeneratedImageLoader {
    private let session: URLSession
    private let maximumBytes: Int

    init(
        maximumBytes: Int = 12 * 1_024 * 1_024,
        protocolClasses: [AnyClass]? = nil
    ) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        if let protocolClasses {
            configuration.protocolClasses = protocolClasses
        }
        self.session = URLSession(configuration: configuration)
        self.maximumBytes = maximumBytes
    }

    func load(url: URL) async throws -> Data {
        guard url.scheme == "https" else {
            throw ServiceFailure.transport("The generated image URL is not secure.")
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            try Task.checkCancellation()
            throw error
        }
        try Task.checkCancellation()

        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw ServiceFailure.transport("The generated image is unavailable. Try again.")
        }
        let contentType = response
            .value(forHTTPHeaderField: "Content-Type")?
            .split(separator: ";", maxSplits: 1)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard contentType?.hasPrefix("image/") == true else {
            throw ServiceFailure.transport("The generated result is not a supported image.")
        }
        guard data.count <= maximumBytes, UIImage(data: data) != nil else {
            throw ServiceFailure.transport("The generated result is too large or invalid.")
        }
        return data
    }

    nonisolated func client() -> GeneratedImageClient {
        GeneratedImageClient { [self] url in
            try await load(url: url)
        }
    }
}
