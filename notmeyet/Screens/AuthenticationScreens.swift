import SwiftUI

struct AccountScreen: View {
    let model: OnboardingFlowModel

    var body: some View {
        OnboardingPage(step: .account, showsBack: true, back: model.goBack) {
            AuthenticationHero(
                title: "Continue to your free harmony check",
                subtitle: "Sign in or create an account to get one free harmony check and one personalized hairstyle look."
            )
            .padding(.top, 10)

            AuthenticationActions(model: model, returning: false)
                .padding(.top, 28)

            if let error = model.authenticationError {
                NMYErrorPanel(message: error, retryTitle: "Try account connection") {
                    Task { await model.retryAuthentication() }
                }
                .padding(.top, 14)
            }
        } actions: {
            VStack(spacing: 8) {
                Text("By continuing, you agree to the")
                    .font(NMYDesign.Typography.detail)
                    .foregroundStyle(NMYDesign.muted)
                LegalLinksView(
                    termsURL: model.dependencies.configuration.termsURL,
                    privacyURL: model.dependencies.configuration.privacyURL
                )
            }
        }
    }
}

struct ReturningSignInScreen: View {
    let model: OnboardingFlowModel

    var body: some View {
        OnboardingPage(step: .returningSignIn, showsBack: true, back: model.goBack) {
            AuthenticationHero(
                title: "Welcome back",
                subtitle: "Sign in to return to your harmony profile, saved looks, and previous sessions."
            )
            .padding(.top, 10)

            AuthenticationActions(model: model, returning: true)
                .padding(.top, 28)

            if let error = model.authenticationError {
                NMYErrorPanel(message: error, retryTitle: "Try account connection") {
                    Task { await model.retryAuthentication() }
                }
                .padding(.top, 14)
            }
        } actions: {
            Button("New to NotMeYet? Start onboarding") { model.goBack() }
                .font(NMYDesign.Typography.detail.weight(.semibold))
                .foregroundStyle(NMYDesign.muted)
                .frame(maxWidth: .infinity, minHeight: NMYDesign.minimumTarget)
                .accessibilityIdentifier("returning.startOnboarding")
        }
    }
}

private struct AuthenticationHero: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 24) {
            Text("N")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(NMYDesign.accent)
                .frame(width: 72, height: 72)
                .background(NMYDesign.accent.opacity(0.1))
                .clipShape(.rect(cornerRadius: 24))
                .accessibilityHidden(true)
            ScreenHeading(title: title, subtitle: subtitle)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AuthenticationActions: View {
    let model: OnboardingFlowModel
    let returning: Bool

    var body: some View {
        VStack(spacing: 10) {
            Button {
                Task { await model.authenticate(with: .apple, returning: returning) }
            } label: {
                HStack {
                    Image(systemName: "apple.logo")
                    Text("Continue with Apple")
                }
                .font(NMYDesign.Typography.control)
                .foregroundStyle(NMYDesign.accentForeground)
                .frame(maxWidth: .infinity, minHeight: NMYDesign.controlHeight)
                .background(NMYDesign.foreground)
                .clipShape(.rect(cornerRadius: NMYDesign.largeRadius))
            }
            .buttonStyle(.plain)
            .disabled(model.isAuthenticating)
            .accessibilityIdentifier("auth.apple")

            Button("Continue with Google") {
                Task { await model.authenticate(with: .google, returning: returning) }
            }
            .buttonStyle(.nmySecondary)
            .disabled(model.isAuthenticating)
            .accessibilityIdentifier("auth.google")

            if model.isAuthenticating {
                ProgressView("Connecting your account...")
                    .font(NMYDesign.Typography.detail)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
                    .accessibilityIdentifier("auth.progress")
            }
        }
    }
}
