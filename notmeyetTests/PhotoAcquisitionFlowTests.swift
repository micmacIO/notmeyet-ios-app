import Testing
import UIKit
@testable import notmeyet

@Suite("Photo acquisition flow")
struct PhotoAcquisitionFlowTests {
    @Test("Authorized camera capture prepares the image and advances to review")
    @MainActor
    func cameraCaptureSuccess() async throws {
        let expectedPhoto = Self.preparedPhoto(byte: 0x11)
        let cameraAccess = CameraAccessClient(
            isAvailable: { true },
            authorizationState: { .authorized },
            requestAccess: { false }
        )
        let model = OnboardingFlowModel(
            dependencies: TestDependencyHarness().makeDependencies(
                photoProcessing: PhotoProcessingClient { _, _ in expectedPhoto },
                cameraAccess: cameraAccess
            )
        )
        model.phase = .onboarding(.photoPreparation)

        #expect(await model.requestCamera())

        var capturedData: Data?
        var didCancel = false
        let coordinator = CameraPicker.Coordinator(
            onCapture: { capturedData = $0 },
            onCancel: { didCancel = true }
        )
        coordinator.imagePickerController(
            UIImagePickerController(),
            didFinishPickingMediaWithInfo: [.originalImage: Self.fixtureImage()]
        )
        let data = try #require(capturedData)
        #expect(!data.isEmpty)
        #expect(!didCancel)

        await model.preparePhoto(data: data)

        #expect(model.phase == .onboarding(.photoReview))
        #expect(model.draft.preparedPhoto == expectedPhoto)
        #expect(model.photoError == nil)
    }

    @Test("Library success passes selected bytes to processing and advances to review")
    @MainActor
    func librarySuccess() async {
        let sourceData = Data([0x21, 0x22, 0x23])
        let expectedPhoto = Self.preparedPhoto(byte: 0x24)
        let recorder = PhotoProcessingRecorder(result: expectedPhoto)
        let model = OnboardingFlowModel(
            dependencies: TestDependencyHarness().makeDependencies(
                photoProcessing: PhotoProcessingClient { data, policy in
                    await recorder.prepare(data, policy: policy)
                }
            )
        )
        model.phase = .onboarding(.photoPreparation)

        await model.loadLibraryPhoto { sourceData }

        #expect(await recorder.receivedData() == sourceData)
        #expect(await recorder.receivedPolicy() == .current)
        #expect(model.phase == .onboarding(.photoReview))
        #expect(model.draft.preparedPhoto == expectedPhoto)
        #expect(model.photoError == nil)
    }

    @Test("Picker cancellation leaves photo preparation unchanged")
    @MainActor
    func pickerCancellationIsSilent() async {
        let model = OnboardingFlowModel(dependencies: TestDependencyHarness().makeDependencies())
        model.phase = .onboarding(.photoPreparation)
        var didCapture = false
        var didCancel = false
        let coordinator = CameraPicker.Coordinator(
            onCapture: { _ in didCapture = true },
            onCancel: { didCancel = true }
        )

        coordinator.imagePickerControllerDidCancel(UIImagePickerController())
        await model.loadLibraryPhoto { throw CancellationError() }

        #expect(didCancel)
        #expect(!didCapture)
        #expect(model.phase == .onboarding(.photoPreparation))
        #expect(model.draft.preparedPhoto == nil)
        #expect(model.photoError == nil)
    }

    @Test("Denied permission keeps screen 06 and offers Settings")
    @MainActor
    func permissionDenial() async {
        var state = CameraAuthorizationState.notDetermined
        var requestCount = 0
        let cameraAccess = CameraAccessClient(
            isAvailable: { true },
            authorizationState: { state },
            requestAccess: {
                requestCount += 1
                state = .denied
                return false
            }
        )
        let model = OnboardingFlowModel(
            dependencies: TestDependencyHarness().makeDependencies(cameraAccess: cameraAccess)
        )
        model.phase = .onboarding(.photoPreparation)

        #expect(await model.requestCamera() == false)

        #expect(requestCount == 1)
        #expect(model.phase == .onboarding(.photoPreparation))
        #expect(model.photoError == "Camera access is off. Allow it in Settings or choose a library photo.")
        #expect(model.shouldOfferCameraSettings)
    }

    @Test("Restricted permission stays on screen 06 with library guidance")
    @MainActor
    func restrictedPermission() async {
        let cameraAccess = CameraAccessClient(
            isAvailable: { true },
            authorizationState: { .restricted },
            requestAccess: { false }
        )
        let model = OnboardingFlowModel(
            dependencies: TestDependencyHarness().makeDependencies(cameraAccess: cameraAccess)
        )
        model.phase = .onboarding(.photoPreparation)

        #expect(await model.requestCamera() == false)
        #expect(model.phase == .onboarding(.photoPreparation))
        #expect(model.photoError == "Camera access is restricted. Choose a photo from your library instead.")
        #expect(!model.shouldOfferCameraSettings)
    }

    @Test("Unavailable camera fails before checking authorization")
    @MainActor
    func unavailableCamera() async {
        var authorizationChecks = 0
        var accessRequests = 0
        let cameraAccess = CameraAccessClient(
            isAvailable: { false },
            authorizationState: {
                authorizationChecks += 1
                return .authorized
            },
            requestAccess: {
                accessRequests += 1
                return true
            }
        )
        let model = OnboardingFlowModel(
            dependencies: TestDependencyHarness().makeDependencies(cameraAccess: cameraAccess)
        )
        model.phase = .onboarding(.photoPreparation)

        #expect(await model.requestCamera() == false)

        #expect(authorizationChecks == 0)
        #expect(accessRequests == 0)
        #expect(model.phase == .onboarding(.photoPreparation))
        #expect(model.photoError == "A camera isn't available here. Choose a photo from your library instead.")
        #expect(model.draft.preparedPhoto == nil)
    }

    @Test("Invalid library data stays on screen 06 with recoverable feedback")
    @MainActor
    func invalidLibraryImage() async {
        let model = OnboardingFlowModel(
            dependencies: TestDependencyHarness().makeDependencies(
                photoProcessing: PhotoProcessingClient { _, _ in
                    throw ServiceFailure.invalidImage("This image data is invalid.")
                }
            )
        )
        model.phase = .onboarding(.photoPreparation)

        await model.loadLibraryPhoto { nil }
        #expect(model.photoError == "This photo couldn't be opened. Choose another one.")

        await model.loadLibraryPhoto { Data([0x00]) }

        #expect(model.phase == .onboarding(.photoPreparation))
        #expect(model.photoError == "This image data is invalid.")
        #expect(model.draft.preparedPhoto == nil)
    }

    private static func preparedPhoto(byte: UInt8) -> PreparedPhoto {
        PreparedPhoto(
            displayData: Data([byte]),
            uploadData: Data([byte]),
            pixelWidth: 10,
            pixelHeight: 12
        )
    }

    @MainActor
    private static func fixtureImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4), format: format).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }
}

private actor PhotoProcessingRecorder {
    private let result: PreparedPhoto
    private var data: Data?
    private var policy: ImagePreparationPolicy?

    init(result: PreparedPhoto) {
        self.result = result
    }

    func prepare(_ data: Data, policy: ImagePreparationPolicy) -> PreparedPhoto {
        self.data = data
        self.policy = policy
        return result
    }

    func receivedData() -> Data? {
        data
    }

    func receivedPolicy() -> ImagePreparationPolicy? {
        policy
    }
}
