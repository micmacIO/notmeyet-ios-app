import Foundation
import ImageIO
import UniformTypeIdentifiers

actor PhotoProcessor {
    func prepare(data: Data, policy: ImagePreparationPolicy) throws -> PreparedPhoto {
        try Task.checkCancellation()
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ServiceFailure.invalidImage("This image could not be opened. Choose another photo.")
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: policy.maximumLongEdge,
            kCGImageSourceShouldCacheImmediately: false
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ServiceFailure.invalidImage("This image could not be prepared. Choose another photo.")
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ServiceFailure.invalidImage("This image could not be prepared. Choose another photo.")
        }
        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: policy.jpegQuality
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ServiceFailure.invalidImage("This image could not be prepared. Choose another photo.")
        }
        try Task.checkCancellation()

        let encoded = output as Data
        return PreparedPhoto(
            displayData: encoded,
            uploadData: encoded,
            pixelWidth: image.width,
            pixelHeight: image.height
        )
    }

    nonisolated func client() -> PhotoProcessingClient {
        PhotoProcessingClient { [self] data, policy in
            try await prepare(data: data, policy: policy)
        }
    }
}
