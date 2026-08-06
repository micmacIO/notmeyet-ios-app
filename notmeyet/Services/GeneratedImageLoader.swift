import Foundation
import ImageIO

actor GeneratedImageLoader {
    private let session: URLSession
    private let maximumBytes: Int
    private let maximumDimension: Int
    private let maximumDecodedPixels: Int64

    init(
        maximumBytes: Int = 12 * 1_024 * 1_024,
        maximumDimension: Int = 8_192,
        maximumDecodedPixels: Int64 = 40_000_000,
        protocolClasses: [AnyClass]? = nil
    ) {
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
        self.session = URLSession(configuration: configuration)
        self.maximumBytes = maximumBytes
        self.maximumDimension = maximumDimension
        self.maximumDecodedPixels = maximumDecodedPixels
    }

    func load(url: URL) async throws -> Data {
        try Task.checkCancellation()
        guard
            url.scheme?.lowercased() == "https",
            url.host?.isEmpty == false
        else {
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
            throw ServiceFailure.transport("The generated image is unavailable. Try again.")
        }
        try Task.checkCancellation()

        guard
            let response = response as? HTTPURLResponse,
            (200..<300).contains(response.statusCode)
        else {
            throw ServiceFailure.transport("The generated image is unavailable. Try again.")
        }
        guard
            response.url?.scheme?.lowercased() == "https",
            response.url?.host?.isEmpty == false
        else {
            throw ServiceFailure.transport("The generated image URL is not secure.")
        }
        let contentType = response
            .value(forHTTPHeaderField: "Content-Type")?
            .split(separator: ";", maxSplits: 1)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard
            let contentType,
            contentType.hasPrefix("image/"),
            contentType.dropFirst("image/".count).isEmpty == false
        else {
            throw ServiceFailure.transport("The generated result is not a supported image.")
        }
        guard
            response.expectedContentLength <= 0 || response.expectedContentLength <= Int64(maximumBytes),
            data.count <= maximumBytes,
            isValidRaster(data)
        else {
            throw ServiceFailure.transport("The generated result is too large or invalid.")
        }
        try Task.checkCancellation()
        return data
    }

    private func isValidRaster(_ data: Data) -> Bool {
        guard
            maximumBytes >= 0,
            maximumDimension > 0,
            maximumDecodedPixels > 0,
            let source = CGImageSourceCreateWithData(
                data as CFData,
                [kCGImageSourceShouldCache: false] as CFDictionary
            ),
            CGImageSourceGetStatus(source) == .statusComplete
        else {
            return false
        }

        let imageCount = CGImageSourceGetCount(source)
        guard imageCount > 0 else { return false }
        var totalPixels: Int64 = 0

        for index in 0..<imageCount {
            guard
                CGImageSourceGetStatusAtIndex(source, index) == .statusComplete,
                let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil)
                    as? [CFString: Any],
                let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.int64Value,
                let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.int64Value,
                width > 0,
                height > 0,
                width <= Int64(maximumDimension),
                height <= Int64(maximumDimension),
                width <= maximumDecodedPixels / height
            else {
                return false
            }

            let pixels = width * height
            guard totalPixels <= maximumDecodedPixels - pixels else { return false }
            totalPixels += pixels

            guard CGImageSourceCreateImageAtIndex(
                source,
                index,
                [
                    kCGImageSourceShouldCache: true,
                    kCGImageSourceShouldCacheImmediately: true
                ] as CFDictionary
            ) != nil else {
                return false
            }
        }

        return true
    }

}
