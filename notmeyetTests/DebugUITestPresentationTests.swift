#if DEBUG
import Foundation
import Testing
@testable import notmeyet

@Suite("Debug UI-test presentations")
struct DebugUITestPresentationTests {
    @Test("Presentation selectors require one explicit mock-mode value")
    @MainActor
    func selectorValidation() {
        for presentation in DebugUITestPresentation.allCases {
            let arguments = ["--mock-services", "--ui-test-presentation=\(presentation.rawValue)"]
            #expect(DebugUITestPresentation.selected(in: arguments, configuration: .testMock) == presentation)
        }

        #expect(DebugUITestPresentation.selected(
            in: ["--ui-test-presentation=main"],
            configuration: .testMock
        ) == nil)
        #expect(DebugUITestPresentation.selected(
            in: ["--mock-services", "--ui-test-presentation=unknown"],
            configuration: .testMock
        ) == nil)
        #expect(DebugUITestPresentation.selected(
            in: ["--mock-services", "--ui-test-presentation=01", "--ui-test-presentation=main"],
            configuration: .testMock
        ) == nil)
        #expect(DebugUITestPresentation.selected(
            in: ["--mock-services", "--ui-test-presentation=main"],
            configuration: liveConfiguration
        ) == nil)
    }

    @Test("Every presentation seeds a stable route without invoking services")
    @MainActor
    func presentationsSeedStableRoutes() {
        for presentation in DebugUITestPresentation.allCases {
            let harness = TestDependencyHarness()
            let model = OnboardingFlowModel(dependencies: harness.makeDependencies())

            presentation.apply(to: model)

            #expect(model.phase == expectedPhase(for: presentation))
            #expect(harness.events.isEmpty)
            #expect(model.accountOperationStage == .idle)
            if requiresPhoto(presentation) {
                #expect(model.draft.preparedPhoto != nil)
            }
        }
    }

    @Test("Processing presentations seed their exact operation states")
    @MainActor
    func processingStates() {
        let harness = TestDependencyHarness()

        let analysisLoading = OnboardingFlowModel(dependencies: harness.makeDependencies())
        DebugUITestPresentation.screen08Loading.apply(to: analysisLoading)
        #expect(analysisLoading.analysisPhase.isLoading)

        let analysisError = OnboardingFlowModel(dependencies: harness.makeDependencies())
        DebugUITestPresentation.screen08Error.apply(to: analysisError)
        guard case .failed = analysisError.analysisPhase else {
            Issue.record("Screen 08 error did not seed a failed analysis phase")
            return
        }

        let generationLoading = OnboardingFlowModel(dependencies: harness.makeDependencies())
        DebugUITestPresentation.screen10Loading.apply(to: generationLoading)
        #expect(generationLoading.generationPhase.isLoading)

        let generationError = OnboardingFlowModel(dependencies: harness.makeDependencies())
        DebugUITestPresentation.screen10Error.apply(to: generationError)
        guard case .failed = generationError.generationPhase else {
            Issue.record("Screen 10 error did not seed a failed generation phase")
            return
        }

        let imageSuccess = OnboardingFlowModel(dependencies: harness.makeDependencies())
        DebugUITestPresentation.screen11Success.apply(to: imageSuccess)
        #expect(imageSuccess.draft.generatedLook?.imageData.isEmpty == false)
        #expect(imageSuccess.comparisonSplit == 0.46)
    }

    @Test("Backend completion presentations seed their exact public state")
    @MainActor
    func backendCompletionStates() {
        let harness = TestDependencyHarness()

        let resolving = OnboardingFlowModel(dependencies: harness.makeDependencies())
        DebugUITestPresentation.screen05BackendResolving.apply(to: resolving)
        #expect(resolving.isResolvingAccount)
        #expect(resolving.isAuthenticating == false)
        #expect(resolving.authenticationError == nil)

        let createdIncomplete = OnboardingFlowModel(dependencies: harness.makeDependencies())
        DebugUITestPresentation.screen13CreatedIncomplete.apply(to: createdIncomplete)
        #expect(
            createdIncomplete.returningAccountNotice
                == "This account hasn't completed onboarding yet. Start onboarding to create your first look."
        )

        for presentation in [
            DebugUITestPresentation.screen06CompletionProgress,
            .screen09CompletionProgress,
            .screen11CompletionProgress
        ] {
            let model = OnboardingFlowModel(dependencies: harness.makeDependencies())
            presentation.apply(to: model)
            #expect(model.isCompletingOnboarding)
            #expect(model.completionError == nil)
            #expect(model.isVerifyingAccess == false)
        }

        let accessPending = OnboardingFlowModel(dependencies: harness.makeDependencies())
        DebugUITestPresentation.accessPendingProgress.apply(to: accessPending)
        #expect(accessPending.isVerifyingAccess)
        #expect(accessPending.accessError == nil)

        let accessFailure = OnboardingFlowModel(dependencies: harness.makeDependencies())
        DebugUITestPresentation.accessFailure.apply(to: accessFailure)
        #expect(accessFailure.isVerifyingAccess == false)
        #expect(accessFailure.accessError == "We couldn't verify access. Try again.")
        #expect(harness.events.isEmpty)
    }

    @MainActor
    private func expectedPhase(for presentation: DebugUITestPresentation) -> AppAccessPhase {
        switch presentation {
        case .screen01: .onboarding(.welcome)
        case .screen02: .onboarding(.primaryGoal)
        case .screen03: .onboarding(.painPoints)
        case .screen04: .onboarding(.direction)
        case .screen05, .screen05BackendResolving: .onboarding(.account)
        case .screen06, .screen06CompletionProgress: .onboarding(.photoPreparation)
        case .screen07: .onboarding(.photoReview)
        case .screen08Loading, .screen08Error: .onboarding(.analysisProcessing)
        case .screen09, .screen09CompletionProgress: .onboarding(.harmonySnapshot)
        case .screen10Loading, .screen10Error: .onboarding(.generationProcessing)
        case .screen11Success, .screen11CompletionProgress: .onboarding(.firstResult)
        case .screen12Mock, .screen12ProductionShell: .onboarding(.paywall)
        case .screen13, .screen13CreatedIncomplete: .onboarding(.returningSignIn)
        case .accessPendingProgress, .accessFailure: .postOnboardingAccess
        case .main: .main
        }
    }

    private func requiresPhoto(_ presentation: DebugUITestPresentation) -> Bool {
        switch presentation {
        case .screen07, .screen08Loading, .screen08Error, .screen09,
             .screen09CompletionProgress, .screen10Loading, .screen10Error,
             .screen11Success, .screen11CompletionProgress:
            true
        default:
            false
        }
    }

    private var liveConfiguration: AppConfiguration {
        AppConfiguration(
            mode: .live,
            googleClientID: "google-client",
            revenueCatAPIKey: "revenuecat-key",
            revenueCatEntitlementID: "pro",
            looksAPIBaseURL: URL(string: "https://api.example.com"),
            termsURL: URL(string: "https://example.com/terms"),
            privacyURL: URL(string: "https://example.com/privacy"),
            facialDataDisclosuresApproved: true,
            backendUserLifecycleContractConfirmed: true
        )
    }
}
#endif
