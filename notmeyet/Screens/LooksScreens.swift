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
            retry: model.retryAnalysis
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
            trailingNavigationAction: model.skipLook,
            pinsActions: false
        ) {
            ScreenHeading(title: "Here's what works in harmony")
                .padding(.bottom, 16)

            if let imageData = model.draft.preparedPhoto?.displayData,
                let image = UIImage(data: imageData),
                let result = model.draft.harmonyResult {
                HarmonyImageView(image: image, guides: result.guides)
                    .frame(height: 260)

                resultLayout {
                    ResultCard(
                        eyebrow: "Your face shape",
                        title: result.faceShapeTitle,
                        detail: result.faceShapeDescription
                    )
                    ResultCard(
                        eyebrow: "Overall harmony",
                        title: result.harmonyTitle,
                        detail: result.harmonyDescription
                    )
                }
                .padding(.top, 14)
            }

            Text("Estimates for inspiration, not a medical assessment.")
                .font(NMYDesign.Typography.micro)
                .foregroundStyle(NMYDesign.muted)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
        } actions: {
            Button("Show me a matching hairstyle") { model.showMatchingStyle() }
                .buttonStyle(.nmyPrimary)
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
            retry: model.retryGeneration
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

            resultContent

            if let look = model.draft.generatedLook {
                VStack(alignment: .leading, spacing: 6) {
                    Text(look.styleName).font(NMYDesign.Typography.cardTitle)
                    Text("Why this was chosen")
                        .font(NMYDesign.Typography.detail.bold())
                    Text(look.explanation)
                        .font(NMYDesign.Typography.detail)
                        .foregroundStyle(NMYDesign.muted)
                }
                .padding(.top, 14)
            }
        } actions: {
            Button("Try more") { model.tryMore() }
                .buttonStyle(.nmyPrimary)
                .disabled(model.draft.generatedImageData == nil)
                .accessibilityIdentifier("result.tryMore")
        }
    }

    @ViewBuilder
    private var resultContent: some View {
        switch model.generatedImagePhase {
        case .idle, .loading:
            VStack(spacing: 14) {
                ProgressView()
                Text("Loading your first look...")
                    .font(NMYDesign.Typography.supporting)
                    .foregroundStyle(NMYDesign.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .nmyCard()
            .aspectRatio(353 / 380, contentMode: .fit)
            .accessibilityIdentifier("result.loading")
        case .failed(let message):
            NMYErrorPanel(message: message, retryTitle: "Try loading again", retry: model.retryGeneratedImage)
                .frame(minHeight: 220)
        case .loaded(let afterData):
            if let beforeData = model.draft.preparedPhoto?.displayData,
               let before = UIImage(data: beforeData),
               let after = UIImage(data: afterData) {
                BeforeAfterComparison(before: before, after: after, model: model)
            }
        }
    }
}

private struct ProcessingScreen<Value>: View {
    let step: OnboardingStep
    let imageData: Data?
    let title: String
    let subtitle: String
    let phase: OperationPhase<Value>
    let retry: () -> Void

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
            if case .failed = phase {
                Button("Try again", action: retry)
                    .buttonStyle(.nmyPrimary)
                    .accessibilityIdentifier("error.retry")
            }
        }
    }
}

private struct HarmonyImageView: View {
    @Environment(\.colorSchemeContrast) private var contrast
    let image: UIImage
    let guides: [HarmonyGuide]

    var body: some View {
        GeometryReader { geometry in
            let imageRect = aspectFitRect(for: image.size, in: CGRect(origin: .zero, size: geometry.size))
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageRect.width, height: imageRect.height)
                    .position(x: imageRect.midX, y: imageRect.midY)

                Canvas { context, _ in
                    for guide in guides where guide.points.count > 1 {
                        var path = Path()
                        if let first = guide.points.first {
                            path.move(to: guidePoint(first, in: imageRect))
                        }
                        for point in guide.points.dropFirst() {
                            path.addLine(to: guidePoint(point, in: imageRect))
                        }
                        context.stroke(
                            path,
                            with: .color(NMYDesign.accent),
                            lineWidth: NMYDesign.Accessibility.strokeWidth(
                                for: contrast,
                                standard: 1.2,
                                increased: 2.4
                            )
                        )
                    }
                }
                .accessibilityHidden(true)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .clipShape(.rect(cornerRadius: 22))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your photo with facial harmony guides")
    }

    private func guidePoint(_ point: NormalizedPoint, in imageRect: CGRect) -> CGPoint {
        CGPoint(
            x: imageRect.minX + CGFloat(point.x) * imageRect.width,
            y: imageRect.minY + CGFloat(point.y) * imageRect.height
        )
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
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow)
                .font(NMYDesign.Typography.micro)
                .foregroundStyle(NMYDesign.Accessibility.mutedColor(for: contrast))
            Text(title).font(NMYDesign.Typography.cardTitle)
            Text(detail)
                .font(NMYDesign.Typography.micro)
                .foregroundStyle(NMYDesign.Accessibility.mutedColor(for: contrast))
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
                        Text("Before")
                        Spacer()
                        Text("After")
                    }
                    .font(NMYDesign.Typography.detail.bold())
                    .padding(14)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)

                    Image(systemName: "arrow.left.and.right")
                        .font(NMYDesign.Typography.supporting.bold())
                        .frame(width: 40, height: 40)
                        .background(.white)
                        .clipShape(.circle)
                        .shadow(radius: 6, y: 2)
                        .position(x: geometry.size.width * model.comparisonSplit, y: geometry.size.height * 0.52)
                        .allowsHitTesting(false)
                }
                .contentShape(.rect)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            model.setComparisonSplit(value.location.x / max(geometry.size.width, 1))
                        }
                )
            }
            .aspectRatio(353 / 380, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 27))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Before and after hairstyle comparison")
            .accessibilityValue("\(Int(model.comparisonSplit * 100)) percent before")
            .accessibilityAdjustableAction { direction in
                model.setComparisonSplit(model.comparisonSplit + (direction == .increment ? 0.05 : -0.05))
            }
            .accessibilityIdentifier("result.comparison")

            Slider(value: splitBinding, in: 0.12...0.88)
                .tint(NMYDesign.accent)
                .accessibilityLabel("Compare before and after")
                .accessibilityValue("\(Int(model.comparisonSplit * 100)) percent before")
                .accessibilityIdentifier("result.slider")
        }
    }

    private func comparisonImage(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
