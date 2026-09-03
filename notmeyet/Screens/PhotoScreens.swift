import PhotosUI
import SwiftUI
import UIKit

struct PhotoPreparationScreen: View {
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let model: OnboardingFlowModel
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showsCamera = false

    var body: some View {
        let libraryBorderColor = NMYDesign.Accessibility.borderColor(for: contrast)
        let libraryBorderWidth = NMYDesign.Accessibility.strokeWidth(for: contrast)

        OnboardingPage(
            step: .photoPreparation,
            trailingNavigationTitle: "Skip harmony check",
            trailingNavigationIdentifier: "photo.skipHarmony",
            trailingNavigationDisabled: model.isCompletingOnboarding,
            trailingNavigationAction: model.skipHarmonyCheck,
            pinsActions: false
        ) {
            ScreenHeading(
                title: "Let's find what works with your features.",
                subtitle: "Start with a clear, front-facing photo. Better input creates a more realistic preview."
            )
            .padding(.bottom, 18)

            if let error = model.completionError {
                NMYErrorPanel(message: error, retryTitle: "Try again") {
                    model.retryOnboardingCompletion()
                }
                .padding(.bottom, 14)
            }

            if model.isCompletingOnboarding {
                ProgressView("Finishing your account setup...")
                    .font(NMYDesign.Typography.detail)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 14)
                    .accessibilityIdentifier("completion.progress")
            }

            PhotoGuideView()

            LazyVGrid(columns: photoTipColumns, alignment: .leading, spacing: 10) {
                ForEach([
                    "Face camera directly", "Use even lighting", "Hair away from face",
                    "No glasses or hats", "Neutral expression", "One face only"
                ], id: \.self) { tip in
                    Label(tip, systemImage: "checkmark")
                        .font(NMYDesign.Typography.detail)
                        .foregroundStyle(NMYDesign.muted)
                        .labelStyle(TipLabelStyle())
                }
            }
            .padding(.top, 14)

            if let error = model.photoError {
                NMYErrorPanel(message: error)
                    .padding(.top, 14)
                if model.shouldOfferCameraSettings {
                    Button(action: openSettings) {
                        Text("Open Settings")
                            .font(NMYDesign.Typography.supporting.bold())
                            .frame(minHeight: NMYDesign.minimumTarget)
                            .contentShape(.rect)
                    }
                    .accessibilityIdentifier("camera.openSettings")
                }
            }


        } actions: {
            VStack(spacing: 10) {
                Button("Take my front photo") { requestCamera() }
                    .buttonStyle(.nmyPrimary)
                    .disabled(model.isCompletingOnboarding)
                    .accessibilityIdentifier("photo.camera")

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Text("Choose from library")
                        .font(NMYDesign.Typography.control)
                        .foregroundStyle(NMYDesign.foreground)
                        .frame(maxWidth: .infinity, minHeight: NMYDesign.controlHeight)
                        .background(NMYDesign.surface)
                        .overlay {
                            RoundedRectangle(cornerRadius: NMYDesign.largeRadius)
                                .stroke(
                                    libraryBorderColor,
                                    lineWidth: libraryBorderWidth
                                )
                        }
                        .clipShape(.rect(cornerRadius: NMYDesign.largeRadius))
                }
                .disabled(model.isCompletingOnboarding)
                .accessibilityIdentifier("photo.library")

                #if DEBUG
                if model.dependencies.configuration.isMock,
                   ProcessInfo.processInfo.arguments.contains("--mock-photo-fixture") {
                    Button("Use sample photo") { loadFixturePhoto() }
                        .buttonStyle(.nmySecondary)
                        .disabled(model.isCompletingOnboarding)
                        .accessibilityIdentifier("photo.fixture")
                }
                #endif

                Text("By continuing, you agree to the")
                    .font(NMYDesign.Typography.detail)
                    .foregroundStyle(NMYDesign.muted)
                    .multilineTextAlignment(.center)
                LegalLinksView(
                    termsURL: model.dependencies.configuration.termsURL,
                    privacyURL: model.dependencies.configuration.privacyURL
                )
            }
        }
        .onChange(of: selectedPhoto) { _, item in load(item) }
        .fullScreenCover(isPresented: $showsCamera) {
            CameraCaptureView { data in
                showsCamera = false
                Task { await model.preparePhoto(data: data) }
            } onCancel: {
                showsCamera = false
            }
            .ignoresSafeArea()
        }
    }

    private var photoTipColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible()),
            count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
        )
    }

    private func requestCamera() {
        Task {
            if await model.requestCamera() {
                showsCamera = true
            }
        }
    }

    private func load(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            defer { selectedPhoto = nil }
            await model.loadLibraryPhoto {
                try await item.loadTransferable(type: Data.self)
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    #if DEBUG
    private func loadFixturePhoto() {
        guard let data = UIImage(named: "SamplePortrait")?.jpegData(compressionQuality: 0.9) else {
            model.photoError = "The sample photo is unavailable."
            return
        }
        Task { await model.preparePhoto(data: data) }
    }
    #endif
}

struct PhotoReviewScreen: View {
    @Environment(\.colorSchemeContrast) private var contrast
    let model: OnboardingFlowModel

    var body: some View {
        OnboardingPage(
            step: .photoReview,
            showsBack: true,
            back: model.goBack,
            navigationTitle: "Front photo"
        ) {
            if let image = model.draft.preparedPhoto.flatMap({ UIImage(data: $0.displayData) }) {
                ZStack(alignment: .bottom) {
                    // The rectangle takes the photo's own proportions, so the
                    // whole photo is visible without bars beside it.
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(image.size, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipShape(.rect(cornerRadius: 28))

                    Text("Ready to review")
                        .font(NMYDesign.Typography.detail.bold())
                        .foregroundStyle(NMYDesign.Accessibility.successColor(for: contrast))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .nmyAdaptiveSurface(.white, opacity: 0.9)
                        .clipShape(.capsule)
                        .padding(.bottom, 16)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Your selected front photo. Ready to review.")
                .accessibilityAddTraits(.isImage)
                .accessibilitySortPriority(2)
                .accessibilityIdentifier("photo.review.image")
            }

            Text("Use this photo?")
                .font(NMYDesign.Typography.cardTitle)
                .padding(.top, 18)
                .accessibilitySortPriority(3)
                .nmyRouteHeading(id: "photo-review")
            Text("Check that your face is visible, centered, and evenly lit. Photo quality has not been automatically validated.")
                .font(NMYDesign.Typography.supporting)
                .foregroundStyle(NMYDesign.muted)
                .padding(.top, 6)
                .accessibilitySortPriority(1)
        } actions: {
            VStack(spacing: 10) {
                Button("Use this photo") { model.usePhoto() }
                    .buttonStyle(.nmyPrimary)
                    .accessibilityIdentifier("photo.use")
                Button("Retake") { model.retakePhoto() }
                    .buttonStyle(.nmySecondary)
                    .accessibilityIdentifier("photo.retake")
            }
        }
    }
}

private struct PhotoGuideView: View {
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image("SamplePortrait")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                Color.black.opacity(0.18)
                Ellipse()
                    .strokeBorder(
                        .white,
                        style: StrokeStyle(
                            lineWidth: NMYDesign.Accessibility.strokeWidth(
                                for: contrast,
                                standard: 2,
                                increased: 3
                            ),
                            dash: [7, 6]
                        )
                    )
                    .frame(width: geometry.size.width * (184 / 353), height: geometry.size.height)
            }
        }
        .aspectRatio(353 / 243, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 28))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Example of a clear, front-facing photo centered within the oval guide")
        .accessibilityAddTraits(.isImage)
    }
}

private struct TipLabelStyle: LabelStyle {
    @Environment(\.colorSchemeContrast) private var contrast

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            configuration.icon.foregroundStyle(NMYDesign.Accessibility.successColor(for: contrast))
            configuration.title
        }
    }
}
