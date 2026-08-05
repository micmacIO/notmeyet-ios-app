import CryptoKit
import Foundation
import ImageIO
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import notmeyet

@Suite("Photo processing")
struct PhotoProcessorTests {
    @Test("Preparation normalizes orientation, bounds dimensions, and strips source metadata")
    @MainActor
    func preparesMetadataFreePhoto() async throws {
        let sourceData = try makeJPEG(width: 480, height: 240, orientation: 6)
        let processor = PhotoProcessor()

        let photo = try await processor.prepare(
            data: sourceData,
            policy: ImagePreparationPolicy(maximumLongEdge: 128, jpegQuality: 0.85)
        )

        #expect(max(photo.pixelWidth, photo.pixelHeight) <= 128)
        #expect(photo.pixelHeight > photo.pixelWidth)
        #expect(photo.displayData == photo.uploadData)
        let source = try #require(CGImageSourceCreateWithData(photo.uploadData as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect(properties[kCGImagePropertyGPSDictionary] == nil)
        #expect(properties[kCGImagePropertyTIFFDictionary] == nil)
        let orientation = properties[kCGImagePropertyOrientation] as? Int
        #expect(orientation == nil || orientation == 1)
    }

    @Test("Malformed input is rejected safely")
    @MainActor
    func rejectsMalformedImage() async {
        let processor = PhotoProcessor()

        await #expect(throws: ServiceFailure.self) {
            try await processor.prepare(data: Data("not-an-image".utf8), policy: .mock)
        }
    }

    @Test("Cancellation is propagated")
    @MainActor
    func propagatesCancellation() async {
        let processor = PhotoProcessor()
        let task = Task {
            try await processor.prepare(data: Data("unused".utf8), policy: .mock)
        }
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected photo preparation to be cancelled")
        } catch is CancellationError {
            // Expected.
        } catch {
            Issue.record("Expected CancellationError, received \(error)")
        }
    }

    @Test("Mock policy emits bounded JPEG output without upscaling")
    @MainActor
    func mockPolicyBoundsJPEGOutput() async throws {
        #expect(ImagePreparationPolicy.mock.maximumLongEdge == 2_048)
        #expect(ImagePreparationPolicy.mock.jpegQuality == 0.85)
        let processor = PhotoProcessor()
        let large = try makeJPEG(width: 4_096, height: 2_048, orientation: 1)

        let bounded = try await processor.prepare(data: large, policy: .mock)

        #expect(bounded.pixelWidth == 2_048)
        #expect(bounded.pixelHeight == 1_024)
        let boundedSource = try #require(
            CGImageSourceCreateWithData(bounded.uploadData as CFData, nil)
        )
        #expect(CGImageSourceGetType(boundedSource) as String? == UTType.jpeg.identifier)

        let small = try makeJPEG(width: 320, height: 180, orientation: 1)
        let unchanged = try await processor.prepare(data: small, policy: .mock)
        #expect(unchanged.pixelWidth == 320)
        #expect(unchanged.pixelHeight == 180)
    }

    @Test("JPEG quality policy changes encoded output")
    @MainActor
    func jpegQualityIsApplied() async throws {
        let source = try makeDetailedJPEG(width: 512, height: 512)
        let processor = PhotoProcessor()

        let lowQuality = try await processor.prepare(
            data: source,
            policy: ImagePreparationPolicy(maximumLongEdge: 512, jpegQuality: 0.2)
        )
        let mockQuality = try await processor.prepare(data: source, policy: .mock)

        #expect(mockQuality.uploadData.count > lowQuality.uploadData.count)
    }

    @Test("Large photo preparation leaves the MainActor responsive")
    @MainActor
    func preparationDoesNotBlockMainActor() async throws {
        let source = try makeJPEG(width: 4_096, height: 2_048, orientation: 1)
        let processor = PhotoProcessor()
        var preparationFinished = false

        try await confirmation("MainActor heartbeat") { heartbeat in
            let heartbeatTask = Task { @MainActor in
                #expect(preparationFinished == false)
                heartbeat()
            }
            _ = try await processor.prepare(data: source, policy: .mock)
            preparationFinished = true
            await heartbeatTask.value
        }
    }

    @MainActor
    private func makeJPEG(width: Int, height: Int, orientation: Int) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: width, height: height),
            format: format
        )
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        let cgImage = try #require(image.cgImage)
        let output = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil)
        )
        let properties: [CFString: Any] = [
            kCGImagePropertyOrientation: orientation,
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 51.5,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 0.1,
                kCGImagePropertyGPSLongitudeRef: "W"
            ],
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "Test Camera"]
        ]
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }

    @MainActor
    private func makeDetailedJPEG(width: Int, height: Int) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: width, height: height),
            format: format
        )
        let image = renderer.image { context in
            for y in stride(from: 0, to: height, by: 4) {
                for x in stride(from: 0, to: width, by: 4) {
                    let value = (x &* 31 &+ y &* 17) % 255
                    UIColor(
                        red: CGFloat(value) / 255,
                        green: CGFloat((value &* 7) % 255) / 255,
                        blue: CGFloat((value &* 13) % 255) / 255,
                        alpha: 1
                    ).setFill()
                    context.fill(CGRect(x: x, y: y, width: 4, height: 4))
                }
            }
        }
        return try #require(image.jpegData(compressionQuality: 1))
    }
}

@Suite("Authentication nonce")
struct AuthenticationNonceTests {
    @Test("Nonce has the requested length and allowed characters")
    @MainActor
    func nonceShape() throws {
        let nonce = try AuthenticationNonce.make(length: 64)
        let allowed = Set("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

        #expect(nonce.count == 64)
        #expect(nonce.allSatisfy(allowed.contains))
    }

    @Test("SHA-256 uses lowercase hexadecimal encoding")
    @MainActor
    func sha256Encoding() {
        #expect(
            AuthenticationNonce.sha256("hello")
                == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        )
    }
}
