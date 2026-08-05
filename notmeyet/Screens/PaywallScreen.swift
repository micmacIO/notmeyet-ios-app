import RevenueCatUI
import SwiftUI

struct PaywallScreen: View {
    let model: OnboardingFlowModel

    @ViewBuilder
    var body: some View {
        #if DEBUG
        if model.debugUsesProductionPaywallShell {
            DebugProductionPaywallShell(model: model)
        } else if model.dependencies.configuration.isMock {
            MockPaywallScreen(model: model)
        } else {
            RevenueCatPaywallScreen(model: model)
        }
        #else
        RevenueCatPaywallScreen(model: model)
        #endif
    }
}

private struct RevenueCatPaywallScreen: View {
    let model: OnboardingFlowModel

    var body: some View {
        ProductionPaywallShell(model: model) {
            PaywallView(displayCloseButton: false)
                .onPurchaseCompleted { _ in
                    Task { await model.refreshAccessAfterPurchase() }
                }
                .onPurchaseCancelled {
                    model.handlePurchaseCancellation()
                }
                .onPurchaseFailure { _ in
                    model.handlePurchaseFailure()
                }
                .onRestoreCompleted { _ in
                    Task { await model.refreshAccessAfterRestore() }
                }
                .onRestoreFailure { _ in
                    model.handleRestoreFailure()
                }
        }
    }
}

private struct ProductionPaywallShell<Content: View>: View {
    let model: OnboardingFlowModel
    let content: Content

    init(model: OnboardingFlowModel, @ViewBuilder content: () -> Content) {
        self.model = model
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Meet more versions of you")
                .font(NMYDesign.Typography.cardTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, NMYDesign.horizontalInset)
                .padding(.vertical, NMYDesign.Spacing.medium)
                .background(NMYDesign.background)
                .nmyRouteHeading(id: "paywall-live")

            content
                .safeAreaInset(edge: .top) {
                    if let message = model.purchaseError {
                        PaywallStatusBanner(message: message)
                            .padding(.horizontal, NMYDesign.horizontalInset)
                            .padding(.vertical, NMYDesign.Spacing.small)
                            .background(NMYDesign.background)
                    }
                }
        }
    }
}

#if DEBUG
private struct DebugProductionPaywallShell: View {
    let model: OnboardingFlowModel

    var body: some View {
        ProductionPaywallShell(model: model) {
            VStack(spacing: NMYDesign.Spacing.medium) {
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(NMYDesign.accent)
                    .accessibilityHidden(true)
                Text("RevenueCat paywall content")
                    .font(NMYDesign.Typography.cardTitle)
                Text("Offline fixture for verifying the app-owned production shell.")
                    .font(NMYDesign.Typography.supporting)
                    .foregroundStyle(NMYDesign.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(NMYDesign.Spacing.xLarge)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(NMYDesign.surface)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("paywall.production.fixture")
        }
    }
}

private struct MockPaywallScreen: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let model: OnboardingFlowModel

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView {
                    VStack(spacing: 0) {
                        paywallContent
                        paywallFooter
                    }
                }
                .scrollIndicators(.hidden)
            } else {
                ScrollView {
                    paywallContent
                }
                .scrollIndicators(.hidden)
                .safeAreaInset(edge: .bottom) {
                    paywallFooter
                }
            }
        }
        .background(NMYDesign.background)
        .foregroundStyle(NMYDesign.foreground)
    }

    private var paywallContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            ScreenHeading(
                eyebrow: "Your first look is ready",
                title: "Meet more versions of you",
                subtitle: "Explore hairstyles ranked for your features and compare favorites before committing."
            )
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, NMYDesign.Spacing.large)

            HStack(spacing: 8) {
                previewImage("SamplePortrait", label: "Before")
                previewImage("GeneratedLook", label: "After")
            }
            .frame(height: 176)

            VStack(alignment: .leading, spacing: 13) {
                benefit("Explore all launch hairstyles")
                benefit("See styles ranked for your features")
                benefit("Generate, save, and compare previews")
            }
            .nmyCard()

            if let message = model.purchaseError {
                PaywallStatusBanner(message: message)
            }
        }
        .padding(.horizontal, NMYDesign.horizontalInset)
        .padding(.top, NMYDesign.Spacing.xxLarge)
        .padding(.bottom, 28)
        .frame(maxWidth: 500)
        .frame(maxWidth: .infinity)
    }

    private var paywallFooter: some View {
        VStack(spacing: 10) {
            Button {
                Task { await model.purchase() }
            } label: {
                if model.isPurchasing {
                    ProgressView()
                        .tint(NMYDesign.accentForeground)
                        .accessibilityLabel("Verifying purchase")
                } else {
                    Text("Unlock more looks")
                }
            }
            .buttonStyle(.nmyPrimary)
            .disabled(model.isPurchasing)
            .accessibilityIdentifier("paywall.purchase")

            Button("Restore purchases") {
                Task { await model.restore() }
            }
            .buttonStyle(.nmySecondary)
            .disabled(model.isPurchasing)
            .accessibilityIdentifier("paywall.restore")

            LegalLinksView(
                termsURL: model.dependencies.configuration.termsURL,
                privacyURL: model.dependencies.configuration.privacyURL
            )
        }
        .padding(.horizontal, NMYDesign.horizontalInset)
        .padding(.top, NMYDesign.Spacing.medium)
        .padding(.bottom, NMYDesign.Spacing.small)
        .frame(maxWidth: 500)
        .frame(maxWidth: .infinity)
        .background(NMYDesign.background)
    }

    private func previewImage(_ name: String, label: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 176)
            .clipped()
            .overlay(alignment: .topLeading) {
                Text(label)
                    .font(NMYDesign.Typography.eyebrow)
                    .foregroundStyle(NMYDesign.accentForeground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .nmyAdaptiveSurface(.black, opacity: 0.58)
                    .clipShape(.capsule)
                    .padding(8)
            }
            .clipShape(.rect(cornerRadius: NMYDesign.largeRadius))
            .accessibilityLabel("\(label) hairstyle preview")
    }

    private func benefit(_ title: String) -> some View {
        Label(title, systemImage: "checkmark.circle.fill")
            .font(NMYDesign.Typography.choice)
            .foregroundStyle(NMYDesign.foreground)
            .symbolRenderingMode(.hierarchical)
    }
}
#endif

private struct PaywallStatusBanner: View {
    @Environment(\.colorSchemeContrast) private var contrast
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(NMYDesign.Typography.detail.weight(.semibold))
            .foregroundStyle(NMYDesign.danger)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NMYDesign.surface)
            .overlay {
                RoundedRectangle(cornerRadius: NMYDesign.mediumRadius)
                    .stroke(
                        NMYDesign.danger.opacity(contrast == .increased ? 1 : 0.5),
                        lineWidth: NMYDesign.Accessibility.strokeWidth(for: contrast)
                    )
            }
            .clipShape(.rect(cornerRadius: NMYDesign.mediumRadius))
            .accessibilityIdentifier("paywall.status")
    }
}
