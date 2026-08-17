#if DEBUG
import Foundation
import UIKit

enum DebugUITestPresentation: String, CaseIterable, Sendable {
    case screen01 = "01"
    case screen02 = "02"
    case screen03 = "03"
    case screen04 = "04"
    case screen05 = "05"
    case screen05BackendResolving = "05-backend-resolving"
    case screen06 = "06"
    case screen06CompletionProgress = "06-completion-progress"
    case screen07 = "07"
    case screen08Loading = "08-loading"
    case screen08Error = "08-error"
    case screen09 = "09"
    case screen09CompletionProgress = "09-completion-progress"
    case screen10Loading = "10-loading"
    case screen10Error = "10-error"
    case screen11Success = "11-success"
    case screen11CompletionProgress = "11-completion-progress"
    case screen12Mock = "12-mock"
    case screen13 = "13"
    case screen13CreatedIncomplete = "13-created-incomplete"
    case accessPendingProgress = "access-pending-progress"
    case accessFailure = "access-failure"
    case main
    case screen12ProductionShell = "12-production-shell"

    private static let argumentPrefix = "--ui-test-presentation="

    static func selected(
        in arguments: [String],
        configuration: AppConfiguration
    ) -> Self? {
        guard configuration.isMock else { return nil }
        return selected(in: arguments)
    }

    static func selected(in arguments: [String]) -> Self? {
        guard arguments.contains("--mock-services") else { return nil }
        let values = arguments.compactMap { argument -> String? in
            guard argument.hasPrefix(argumentPrefix) else { return nil }
            return String(argument.dropFirst(argumentPrefix.count))
        }
        guard values.count == 1 else { return nil }
        return Self(rawValue: values[0])
    }

    @MainActor
    func apply(to model: OnboardingFlowModel) {
        model.phase = .bootstrapping
        model.draft = OnboardingDraft()
        model.analysisPhase = .idle
        model.generationPhase = .idle
        model.analysisCanRetry = true
        model.generationCanRetry = true
        model.authenticationError = nil
        model.completionError = nil
        model.accessError = nil
        model.returningAccountNotice = nil
        model.purchaseError = nil
        model.photoError = nil
        model.isAuthenticating = false
        model.isResolvingAccount = false
        model.isCompletingOnboarding = false
        model.isVerifyingAccess = false
        model.isPurchasing = false
        model.comparisonSplit = 0.46
        model.debugUsesProductionPaywallShell = self == .screen12ProductionShell
        model.debugUsesStaticWelcomeMedia = self == .screen01

        switch self {
        case .screen01:
            model.phase = .onboarding(.welcome)
        case .screen02:
            model.phase = .onboarding(.primaryGoal)
        case .screen03:
            model.phase = .onboarding(.painPoints)
        case .screen04:
            model.phase = .onboarding(.direction)
        case .screen05:
            model.phase = .onboarding(.account)
        case .screen05BackendResolving:
            model.phase = .onboarding(.account)
            model.isResolvingAccount = true
        case .screen06:
            model.phase = .onboarding(.photoPreparation)
        case .screen06CompletionProgress:
            model.phase = .onboarding(.photoPreparation)
            model.isCompletingOnboarding = true
        case .screen07:
            guard seedPreparedPhoto(in: model) else { return }
            model.phase = .onboarding(.photoReview)
        case .screen08Loading:
            guard seedPreparedPhoto(in: model) else { return }
            model.analysisPhase = .loading
            model.phase = .onboarding(.analysisProcessing)
        case .screen08Error:
            guard seedPreparedPhoto(in: model) else { return }
            model.analysisPhase = .failed("We couldn't finish your harmony check. Try again.")
            model.phase = .onboarding(.analysisProcessing)
        case .screen09:
            guard seedPreparedPhoto(in: model) else { return }
            model.draft.harmonyResult = .mock
            model.analysisPhase = .loaded(.mock)
            model.phase = .onboarding(.harmonySnapshot)
        case .screen09CompletionProgress:
            guard seedHarmony(in: model) else { return }
            model.phase = .onboarding(.harmonySnapshot)
            model.isCompletingOnboarding = true
        case .screen10Loading:
            guard seedHarmony(in: model) else { return }
            model.generationPhase = .loading
            model.phase = .onboarding(.generationProcessing)
        case .screen10Error:
            guard seedHarmony(in: model) else { return }
            model.generationPhase = .failed("We couldn't create your look. Try again.")
            model.phase = .onboarding(.generationProcessing)
        case .screen11Success:
            guard seedGeneratedLook(in: model) else { return }
            model.phase = .onboarding(.firstResult)
        case .screen11CompletionProgress:
            guard seedGeneratedLook(in: model) else { return }
            model.phase = .onboarding(.firstResult)
            model.isCompletingOnboarding = true
        case .screen12Mock, .screen12ProductionShell:
            model.phase = .onboarding(.paywall)
        case .screen13:
            model.phase = .onboarding(.returningSignIn)
        case .screen13CreatedIncomplete:
            model.phase = .onboarding(.returningSignIn)
            model.returningAccountNotice = "This account hasn't completed onboarding yet. Start onboarding to create your first look."
        case .accessPendingProgress:
            model.phase = .postOnboardingAccess
            model.isVerifyingAccess = true
        case .accessFailure:
            model.phase = .postOnboardingAccess
            model.accessError = "We couldn't verify access. Try again."
        case .main:
            model.phase = .main
        }
    }

    @MainActor
    private func seedPreparedPhoto(in model: OnboardingFlowModel) -> Bool {
        guard let image = UIImage(named: "SamplePortrait"),
              let data = image.jpegData(compressionQuality: 0.9) else {
            showMissingFixture(in: model)
            return false
        }
        let width = image.cgImage?.width ?? Int(image.size.width * image.scale)
        let height = image.cgImage?.height ?? Int(image.size.height * image.scale)
        model.draft.preparedPhoto = PreparedPhoto(
            displayData: data,
            uploadData: data,
            pixelWidth: width,
            pixelHeight: height
        )
        return true
    }

    @MainActor
    private func seedHarmony(in model: OnboardingFlowModel) -> Bool {
        guard seedPreparedPhoto(in: model) else { return false }
        model.draft.harmonyResult = .mock
        model.analysisPhase = .loaded(.mock)
        return true
    }

    @MainActor
    private func seedGeneratedLook(in model: OnboardingFlowModel) -> Bool {
        guard seedHarmony(in: model) else { return false }
        model.draft.generatedLook = .mock
        model.generationPhase = .loaded(.mock)
        return true
    }

    @MainActor
    private func showMissingFixture(in model: OnboardingFlowModel) {
        model.phase = .configurationUnavailable("The Debug visual fixture is unavailable.")
    }
}
#endif
