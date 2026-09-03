import SwiftUI

/// Full-screen front-camera capture for onboarding.
///
/// The surround is white and the screen brightness is raised while the camera is
/// open, so the display doubles as a fill light. A dashed oval shows where the
/// face belongs, matching the guide on the preparation screen.
struct CameraCaptureView: View {
    let onCapture: (Data) -> Void
    let onCancel: () -> Void

    @State private var camera = CameraSession()
    @State private var isCapturing = false
    @State private var brightnessBeforeCamera: CGFloat?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel", action: onCancel)
                    .font(NMYDesign.Typography.control)
                    .foregroundStyle(.black)
                    .frame(minHeight: NMYDesign.minimumTarget)
                    .accessibilityIdentifier("camera.cancel")
                Spacer()
            }
            .padding(.horizontal)

            ZStack {
                CameraPreview(session: camera.session)
                Ellipse()
                    .strokeBorder(.white, style: StrokeStyle(lineWidth: 2, dash: [7, 6]))
                    .aspectRatio(184 / 243, contentMode: .fit)
                    .padding()
            }
            .aspectRatio(3 / 4, contentMode: .fit)
            .clipShape(.rect(cornerRadius: NMYDesign.largeRadius))
            .padding(.horizontal)

            Spacer(minLength: 0)

            Button("Take photo", action: capture)
                .buttonStyle(.nmyPrimary)
                .disabled(isCapturing)
                .padding()
                .accessibilityIdentifier("camera.shutter")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
        .environment(\.colorScheme, .light)
        .onAppear {
            brightnessBeforeCamera = ScreenBrightness.raiseToMaximum()
            camera.start()
        }
        .onDisappear {
            camera.stop()
            ScreenBrightness.restore(to: brightnessBeforeCamera)
        }
    }

    private func capture() {
        isCapturing = true
        Task {
            defer { isCapturing = false }
            guard let data = await camera.capturePhoto() else { return }
            onCapture(data)
        }
    }
}
