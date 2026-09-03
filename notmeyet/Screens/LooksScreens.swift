import SwiftUI
import UIKit

struct AnalysisProcessingScreen: View {
    let model: OnboardingFlowModel

    var body: some View {
        ProcessingScreen(
            step: .analysisProcessing,
            imageData: model.draft.preparedPhoto?.displayData,
            title: "Finding your natural harmony...",
            subtitle: "We're noticing how your features work together to surface hairstyles that feel balanced.",
            phase: model.analysisPhase,
            retry: model.analysisCanRetry ? { model.retryAnalysis() } : nil
        )
    }
}

struct HarmonySnapshotScreen: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let model: OnboardingFlowModel

    var body: some View {
        OnboardingPage(
            step: .harmonySnapshot,
            trailingNavigationTitle: "Skip look",
            trailingNavigationIdentifier: "harmony.skipLook",
            trailingNavigationDisabled: model.isCompletingOnboarding,
            trailingNavigationAction: model.skipLook,
            pinsActions: false
        ) {
            ScreenHeading(title: "Here's what works in harmony")
                .padding(.bottom, 16)

            if let result = model.draft.harmonyResult,
               let image = UIImage(data: result.annotatedImageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 260)
                    .frame(maxWidth: .infinity)
                    .clipShape(.rect(cornerRadius: 22))
                    .accessibilityLabel("Annotated facial harmony image")
                    .accessibilityIdentifier("harmony.annotatedImage")

                resultLayout {
                    ResultCard(
                        eyebrow: "Your face shape",
                        title: result.faceShape
                    )
                    .accessibilityIdentifier("harmony.faceShape")
                    ResultCard(
                        eyebrow: "Overall harmony",
                        title: harmonyScore(result.harmonyScore)
                    )
                    .accessibilityLabel("Overall harmony")
                    .accessibilityValue("\(harmonyScoreValue(result.harmonyScore)) out of 100")
                    .accessibilityIdentifier("harmony.score")
                }
                .padding(.top, 14)
            }

            Text("Estimates for inspiration, not a medical assessment.")
                .font(NMYDesign.Typography.micro)
                .foregroundStyle(NMYDesign.muted)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

            completionStatus(model)
        } actions: {
            Button("Show me a matching hairstyle") { model.showMatchingStyle() }
                .buttonStyle(.nmyPrimary)
                .disabled(model.isCompletingOnboarding)
                .accessibilityIdentifier("harmony.showStyle")
        }
    }

    private var resultLayout: AnyLayout {
        if dynamicTypeSize.isAccessibilitySize {
            AnyLayout(VStackLayout(alignment: .leading, spacing: NMYDesign.Spacing.medium))
        } else {
            AnyLayout(HStackLayout(alignment: .top, spacing: 10))
        }
    }

    private func harmonyScore(_ value: Double) -> String {
        "\(harmonyScoreValue(value)) / 100"
    }

    private func harmonyScoreValue(_ value: Double) -> String {
        String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}

struct GenerationProcessingScreen: View {
    let model: OnboardingFlowModel

    var body: some View {
        ProcessingScreen(
            step: .generationProcessing,
            imageData: model.draft.preparedPhoto?.displayData,
            title: "Creating your first NotMeYet look...",
            subtitle: "Same face. New possibility.",
            phase: model.generationPhase,
            retry: model.generationCanRetry ? { model.retryGeneration() } : nil
        )
    }
}

struct FirstResultScreen: View {
    let model: OnboardingFlowModel

    var body: some View {
        OnboardingPage(
            step: .firstResult,
            navigationTitle: "Your first look",
            pinsActions: false
        ) {
            ScreenHeading(title: "Not you yet - but should it be?")
                .padding(.bottom, 16)

            if let look = model.draft.generatedLook,
               let beforeData = model.draft.preparedPhoto?.displayData,
               let before = UIImage(data: beforeData),
               let after = UIImage(data: look.imageData) {
                BeforeAfterComparison(before: before, after: after, model: model)
            }

            if let look = model.draft.generatedLook {
                VStack(alignment: .leading, spacing: 6) {
                    Text(look.styleName)
                        .font(NMYDesign.Typography.cardTitle)
                        .accessibilityIdentifier("result.styleName")
                    Text("About this look")
                        .font(NMYDesign.Typography.detail.bold())
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("result.aboutHeading")
                    Text(look.styleDescription)
                        .font(NMYDesign.Typography.detail)
                        .foregroundStyle(NMYDesign.muted)
                        .accessibilityIdentifier("result.styleDescription")
                }
                .padding(.top, 14)
            }

            completionStatus(model)
        } actions: {
            Button("Try more") {
                model.tryMore()
            }
                .buttonStyle(.nmyPrimary)
                .disabled(model.draft.generatedLook == nil || model.isCompletingOnboarding)
                .accessibilityIdentifier("result.tryMore")
        }
    }
}

@ViewBuilder
private func completionStatus(_ model: OnboardingFlowModel) -> some View {
    if let error = model.completionError {
        NMYErrorPanel(message: error, retryTitle: "Try again") {
            model.retryOnboardingCompletion()
        }
        .padding(.top, 14)
    } else if model.isCompletingOnboarding {
        ProgressView("Finishing your account setup...")
            .font(NMYDesign.Typography.detail)
            .frame(maxWidth: .infinity)
            .padding(.top, 14)
            .accessibilityIdentifier("completion.progress")
    }
}

private struct ProcessingScreen<Value>: View {
    let step: OnboardingStep
    let imageData: Data?
    let title: String
    let subtitle: String
    let phase: OperationPhase<Value>
    let retry: (() -> Void)?

    var body: some View {
        OnboardingPage(step: step) {
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(NMYDesign.border, lineWidth: 2)
                        .frame(width: 238, height: 238)
                    Circle()
                        .trim(from: 0, to: 0.72)
                        .stroke(NMYDesign.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 238, height: 238)
                        .rotationEffect(.degrees(-90))
                    if let imageData, let image = UIImage(data: imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 176, height: 226)
                            .clipShape(.capsule)
                            .accessibilityLabel("Photo being processed")
                    }
                }
                .padding(.top, 26)

                VStack(spacing: 9) {
                    Text(title)
                        .font(NMYDesign.Typography.screenTitle)
                        .multilineTextAlignment(.center)
                        .nmyRouteHeading(id: title)
                    Text(subtitle)
                        .font(NMYDesign.Typography.supporting)
                        .foregroundStyle(NMYDesign.muted)
                        .multilineTextAlignment(.center)
                }

                if case .failed(let message) = phase {
                    NMYErrorPanel(message: message)
                } else {
                    ProgressView().accessibilityLabel("Processing")
                }
            }
            .frame(maxWidth: .infinity)
        } actions: {
            if case .failed = phase, let retry {
                Button("Try again", action: retry)
                    .buttonStyle(.nmyPrimary)
                    .accessibilityIdentifier("error.retry")
            }
        }
    }
}

func aspectFitRect(for contentSize: CGSize, in bounds: CGRect) -> CGRect {
    guard contentSize.width > 0, contentSize.height > 0, bounds.width > 0, bounds.height > 0 else {
        return .zero
    }
    let scale = min(bounds.width / contentSize.width, bounds.height / contentSize.height)
    let fittedSize = CGSize(width: contentSize.width * scale, height: contentSize.height * scale)
    return CGRect(
        x: bounds.midX - fittedSize.width / 2,
        y: bounds.midY - fittedSize.height / 2,
        width: fittedSize.width,
        height: fittedSize.height
    )
}

private struct ResultCard: View {
    @Environment(\.colorSchemeContrast) private var contrast
    let eyebrow: String
    let title: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow)
                .font(NMYDesign.Typography.micro)
                .foregroundStyle(NMYDesign.Accessibility.mutedColor(for: contrast))
            Text(title).font(NMYDesign.Typography.cardTitle)
            if let detail {
                Text(detail)
                    .font(NMYDesign.Typography.micro)
                    .foregroundStyle(NMYDesign.Accessibility.mutedColor(for: contrast))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .nmyCard(padding: 13)
        .accessibilityElement(children: .combine)
    }
}

private struct BeforeAfterComparison: View {
    let before: UIImage
    let after: UIImage
    let model: OnboardingFlowModel

    var splitBinding: Binding<Double> {
        Binding(get: { model.comparisonSplit }, set: model.setComparisonSplit)
    }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    comparisonImage(after)
                        .saturation(1.12)
                        .contrast(1.06)

                    comparisonImage(before)
                        .frame(width: geometry.size.width * model.comparisonSplit, alignment: .leading)
                        .clipped()
                        .overlay(alignment: .trailing) {
                            Rectangle().fill(.white).frame(width: 2)
                        }

                    HStack {
                        comparisonLabel("Before")
                        Spacer()
                        comparisonLabel("After")
                    }
                    .padding(14)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)

                    Image(systemName: "arrow.left.and.right")
                        .font(NMYDesign.Typography.supporting.bold())
                        .frame(width: 40, height: 40)
                        .background(.white)
                        .clipShape(.circle)
                        .shadow(radius: 6, y: 2)
                        .contentShape(.circle)
                        .gesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.comparisonSpace))
                                .onChanged { value in
                                    setSplit(atX: value.location.x, in: geometry.size.width)
                                }
                        )
                        .position(x: geometry.size.width * model.comparisonSplit, y: geometry.size.height * 0.52)
                }
                .coordinateSpace(.named(Self.comparisonSpace))
                .contentShape(.rect)
                // Dragging the handle adjusts the split; a tap anywhere on the
                // comparison jumps to that point. Neither starves the enclosing
                // ScrollView, so the page still scrolls over the image.
                .simultaneousGesture(
                    SpatialTapGesture(coordinateSpace: .named(Self.comparisonSpace))
                        .onEnded { value in
                            setSplit(atX: value.location.x, in: geometry.size.width)
                        }
                )
            }
            .aspectRatio(353 / 380, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 27))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Before and after hairstyle comparison")
            .accessibilityValue("\(Int(model.comparisonSplit * 100)) percent before")
            .accessibilityAddTraits(.isImage)
            .accessibilityIdentifier("result.comparison")

            Slider(value: splitBinding, in: 0.12...0.88, step: 0.01)
                .tint(NMYDesign.accent)
                .frame(minHeight: NMYDesign.minimumTarget)
                .accessibilityLabel("Compare before and after")
                .accessibilityValue("\(Int(model.comparisonSplit * 100)) percent before")
                .accessibilityIdentifier("result.slider")
        }
    }

    private static let comparisonSpace = "comparison"

    private func setSplit(atX x: CGFloat, in width: CGFloat) {
        guard width > 0 else { return }
        model.setComparisonSplit(x / width)
    }

    private func comparisonImage(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func comparisonLabel(_ title: String) -> some View {
        Text(title)
            .font(NMYDesign.Typography.detail.bold())
            .foregroundStyle(NMYDesign.accentForeground)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .nmyAdaptiveSurface(.black, opacity: 0.58)
            .clipShape(.capsule)
            .accessibilityHidden(true)
    }
}
