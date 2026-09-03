import AVFoundation

/// Front-camera capture used by the onboarding photo step.
///
/// A custom session replaces `UIImagePickerController` so the capture screen can
/// surround the preview with white (extra light on the face), draw a framing
/// guide, and hand back a photo that is not mirrored.
final class CameraSession: NSObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var captureContinuation: CheckedContinuation<Data?, Never>?
    private var isConfigured = false

    // ponytail: the session is configured and started on the main actor; move it
    // to a background task if opening the camera ever feels janky.
    func start() {
        if !isConfigured { configure() }
        guard !session.isRunning else { return }
        session.startRunning()
    }

    func stop() {
        guard session.isRunning else { return }
        session.stopRunning()
    }

    /// Captures a single JPEG frame, or `nil` if the session never started.
    func capturePhoto() async -> Data? {
        guard session.isRunning, captureContinuation == nil else { return nil }
        return await withCheckedContinuation { continuation in
            captureContinuation = continuation
            photoOutput.capturePhoto(
                with: AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg]),
                delegate: self
            )
        }
    }

    private func configure() {
        isConfigured = true
        session.beginConfiguration()
        session.sessionPreset = .photo
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        session.commitConfiguration()

        guard let connection = photoOutput.connection(with: .video) else { return }
        if connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        // The preview stays mirrored so framing feels like a mirror, but the
        // saved photo shows the face the way other people see it.
        connection.automaticallyAdjustsVideoMirroring = false
        if connection.isVideoMirroringSupported {
            connection.isVideoMirrored = false
        }
    }

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let data = photo.fileDataRepresentation()
        Task { @MainActor in
            captureContinuation?.resume(returning: data)
            captureContinuation = nil
        }
    }
}
