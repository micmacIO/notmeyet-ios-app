import SwiftUI

struct PostOnboardingAccessView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    let model: OnboardingFlowModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NMYDesign.Spacing.xLarge) {
                ScreenHeading(
                    eyebrow: "Account ready",
                    title: "Checking your access",
                    subtitle: "Your onboarding is complete. We're securely connecting your account to your access status."
                )

                VStack(spacing: NMYDesign.Spacing.large) {
                    Image(systemName: model.accessError == nil ? "checkmark.shield.fill" : "arrow.clockwise.circle.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(NMYDesign.accent)
                        .accessibilityHidden(true)

                    if model.isVerifyingAccess {
                        ProgressView("Verifying access...")
                            .font(NMYDesign.Typography.supporting)
                            .accessibilityIdentifier("access.progress")
                    }

                    if let error = model.accessError {
                        NMYErrorPanel(message: error, retryTitle: "Try again") {
                            model.retryAccessHandoff()
                        }
                    }
                }
                .padding(NMYDesign.Spacing.xLarge)
                .frame(maxWidth: .infinity)
                .background(
                    reduceTransparency
                        ? NMYDesign.surface
                        : NMYDesign.surface.opacity(contrast == .increased ? 1 : 0.88)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: NMYDesign.largeRadius)
                        .stroke(
                            NMYDesign.Accessibility.borderColor(for: contrast),
                            lineWidth: NMYDesign.Accessibility.strokeWidth(for: contrast)
                        )
                }
                .clipShape(.rect(cornerRadius: NMYDesign.largeRadius))
            }
            .padding(.horizontal, NMYDesign.horizontalInset)
            .padding(.vertical, NMYDesign.Spacing.xxLarge)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .background(NMYDesign.background)
        .foregroundStyle(NMYDesign.foreground)
        .accessibilityIdentifier("access.pending")
    }
}
