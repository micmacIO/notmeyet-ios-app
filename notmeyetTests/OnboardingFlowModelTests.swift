import Foundation
import Testing
@testable import notmeyet

@Suite("Onboarding flow")
struct OnboardingFlowModelTests {
    @Test("Questionnaire choices expose exact ordered copy and cardinality")
    @MainActor
    func questionnaireMetadata() {
        #expect(PrimaryGoal.cardinality == .zeroOrOne)
        #expect(PrimaryGoal.allCases.map(\.title) == [
            "Find a haircut that actually suits me",
            "Look sharper and more put-together",
            "Break out of my current style",
            "Feel more confident about my appearance",
            "Avoid regretting my next haircut",
            "Just see what else could work"
        ])
        #expect(PrimaryGoal.allCases.allSatisfy { $0.detail == nil })

        #expect(PainPoint.cardinality == .zeroOrMore)
        #expect(PainPoint.allCases.map(\.title) == [
            "I don't know what suits my face",
            "Haircuts look different on me than on the model",
            "I can't picture a new style before committing",
            "I don't know what to ask my barber for",
            "I've regretted a haircut before",
            "I keep choosing the same safe style"
        ])
        #expect(PainPoint.allCases.allSatisfy { $0.detail == nil })

        #expect(StyleDirection.cardinality == .zeroOrOne)
        #expect(StyleDirection.allCases.map(\.title) == ["Subtle", "Noticeable", "Bold"])
        #expect(StyleDirection.allCases.map(\.detail) == [
            "A cleaner version of my current look",
            "Clearly different, but still easy to wear",
            "Show me something I wouldn't normally try"
        ])
    }

    @Test("Accessibility announcements distinguish repeated errors and operation statuses")
    @MainActor
    func accessibilityAnnouncementOccurrences() throws {
        let model = OnboardingFlowModel(dependencies: TestDependencyHarness().makeDependencies())

        model.authenticationError = "Sign-in failed"
        let firstError = try #require(model.accessibilityAnnouncement)
        model.authenticationError = "Sign-in failed"
        let repeatedError = try #require(model.accessibilityAnnouncement)

        #expect(firstError.message == "Sign-in failed")
        #expect(repeatedError.message == firstError.message)
        #expect(repeatedError.id != firstError.id)

        model.isAuthenticating = true
        #expect(model.accessibilityAnnouncement?.message == "Connecting your account.")

        model.isResolvingAccount = true
        let resolvingAnnouncement = try #require(model.accessibilityAnnouncement)
        model.isResolvingAccount = true
        #expect(model.accessibilityAnnouncement?.id == resolvingAnnouncement.id)

        model.generationPhase = .loaded(Self.look(name: "Ready", path: "ready"))
        #expect(model.accessibilityAnnouncement?.message == "Your look is ready.")

        model.phase = .configurationUnavailable("Configuration failed")
        #expect(model.accessibilityAnnouncement?.message == "Configuration failed")
    }

    @Test("Completed lifecycle transitions announce success with access progress once")
    @MainActor
    func completedLifecycleProgressAnnouncements() async {
        let launchPurchase = ControlledPurchaseHarness()
        defer { launchPurchase.cancelOutstandingRequests() }
        let launchHarness = TestDependencyHarness()
        launchHarness.userID = "launch-user"
        launchHarness.backendOnboardingCompleted = true
        let launchModel = OnboardingFlowModel(
            dependencies: launchHarness.makeDependencies(purchase: launchPurchase.client())
        )

        let bootstrap = Task { await launchModel.bootstrap() }
        await launchPurchase.waitForBindingRequests(1)
        #expect(
            launchModel.accessibilityAnnouncement?.message
                == "Your account is ready. Verifying your access."
        )
        launchPurchase.succeedBindingRequest(0)
        await launchPurchase.waitForAccessRequests(1)
        launchPurchase.succeedAccessRequest(0, with: .inactive)
        await bootstrap.value

        let completionPurchase = ControlledPurchaseHarness()
        defer { completionPurchase.cancelOutstandingRequests() }
        let completionHarness = TestDependencyHarness()
        completionHarness.userID = "completion-user"
        let completionModel = OnboardingFlowModel(
            dependencies: completionHarness.makeDependencies(purchase: completionPurchase.client())
        )
        await completionModel.bootstrap()

        completionModel.skipHarmonyCheck()
        await completionPurchase.waitForBindingRequests(1)
        #expect(
            completionModel.accessibilityAnnouncement?.message
                == "Onboarding complete. Verifying your access."
        )
        completionPurchase.succeedBindingRequest(0)
        await completionPurchase.waitForAccessRequests(1)
        completionPurchase.succeedAccessRequest(0, with: .inactive)
        #expect(await eventually { completionModel.phase == .onboarding(.paywall) })
    }

    @Test("Questionnaires allow zero choices, clear singles, and retain answers through Back")
    @MainActor
    func questionnaireNavigation() {
        let model = OnboardingFlowModel(dependencies: TestDependencyHarness().makeDependencies())
        model.phase = .onboarding(.welcome)

        model.showPrimaryGoal()
        #expect(model.phase == .onboarding(.primaryGoal))
        model.togglePrimaryGoal(.confidence)
        model.togglePrimaryGoal(.confidence)
        #expect(model.draft.primaryGoal == nil)

        model.continueFromPrimaryGoal()
        model.togglePainPoint(.unknownFit)
        model.togglePainPoint(.barberLanguage)
        #expect(model.draft.painPoints == [.unknownFit, .barberLanguage])

        model.continueFromPainPoints()
        model.toggleDirection(.bold)
        model.goBack()
        #expect(model.phase == .onboarding(.painPoints))
        #expect(model.draft.direction == .bold)
        #expect(model.draft.painPoints == [.unknownFit, .barberLanguage])
    }

    @Test("Signed-out launch performs no backend or purchase work")
    @MainActor
    func signedOutLaunchSkipsBackendAndPurchase() async {
        let harness = TestDependencyHarness()
        let model = OnboardingFlowModel(dependencies: harness.makeDependencies())

        await model.bootstrap()

        #expect(model.phase == .onboarding(.welcome))
        #expect(harness.backendResolutionRequestCount == 0)
        #expect(harness.completionRequestCount == 0)
        #expect(harness.bindingRequestCount == 0)
        #expect(harness.accessRequestCount == 0)
        #expect(harness.purchaseRequestCount == 0)
        #expect(harness.restoreRequestCount == 0)
        #expect(harness.accessMonitoringRequestCount == 0)
        #expect(harness.events.isEmpty)
    }

    @Test(
        "Authenticated launch sends created and existing incomplete accounts to screen 06",
        arguments: [BackendUserOrigin.created, .existing]
    )
    @MainActor
    func incompleteAuthenticatedLaunch(_ origin: BackendUserOrigin) async {
        let harness = TestDependencyHarness()
        harness.userID = "launch-user"
        harness.backendUserOrigin = origin
        harness.backendOnboardingCompleted = false
        let model = OnboardingFlowModel(dependencies: harness.makeDependencies())

        await model.bootstrap()

        #expect(model.phase == .onboarding(.photoPreparation))
        #expect(model.accountOperationStage == .idle)
        #expect(harness.events == ["resolveCurrentUser"])
        #expect(harness.bindingRequestCount == 0)
        #expect(harness.accessRequestCount == 0)
        #expect(harness.accessMonitoringRequestCount == 0)
    }

    @Test(
        "Completed authenticated launch routes from refreshed access",
        arguments: [AccessStatus.active, .inactive]
    )
    @MainActor
    func completedAuthenticatedLaunch(_ status: AccessStatus) async {
        let harness = TestDependencyHarness()
        harness.userID = "launch-user"
        harness.backendOnboardingCompleted = true
        harness.accessStatus = status
        let model = OnboardingFlowModel(dependencies: harness.makeDependencies())

        await model.bootstrap()

        #expect(model.phase == Self.expectedPhase(for: status))
        #expect(harness.events == [
            "resolveCurrentUser", "bind:launch-user", "currentAccess", "accessUpdates"
        ])
        #expect(harness.completionRequestCount == 0)
        #expect(harness.accessMonitoringRequestCount == 1)
    }

    @Test("Backend launch failure fails closed and retry repeats only resolution")
    @MainActor
    func backendLaunchFailureRetriesResolution() async {
        let harness = TestDependencyHarness()
        harness.userID = "launch-user"
        harness.backendResolutionFailure = .transport("Account lookup failed")
        let model = OnboardingFlowModel(dependencies: harness.makeDependencies())

        await model.bootstrap()
        #expect(model.phase == .configurationUnavailable("Account lookup failed"))
        #expect(model.accountOperationStage == .resolving(
            userID: "launch-user",
            context: .launch
        ))
        #expect(harness.backendResolutionRequestCount == 1)
        #expect(harness.bindingRequestCount == 0)

        harness.backendResolutionFailure = nil
        await model.retryBootstrap()

        #expect(model.phase == .onboarding(.photoPreparation))
        #expect(harness.backendResolutionRequestCount == 2)
        #expect(harness.authenticationRequestCount == 0)
        #expect(harness.completionRequestCount == 0)
        #expect(harness.bindingRequestCount == 0)
    }

    @Test("Impossible created-completed resolution fails closed in every entry context")
    @MainActor
    func createdCompletedResolutionFailsClosed() async {
        for entry in BackendResolutionEntry.allCases {
            let harness = TestDependencyHarness()
            harness.backendUserOrigin = .created
            harness.backendOnboardingCompleted = true
            entry.prepare(harness: harness)
            let model = OnboardingFlowModel(dependencies: harness.makeDependencies())

            await entry.resolve(in: model)

            #expect(entry.didRemainFailClosed(model))
            #expect(harness.backendResolutionRequestCount == 1)
            #expect(harness.bindingRequestCount == 0)
            #expect(harness.accessRequestCount == 0)
            #expect(harness.accessMonitoringRequestCount == 0)
        }
    }

    @Test(
        "Screen 05 sends created and existing incomplete accounts to screen 06 without purchase work",
        arguments: [BackendUserOrigin.created, .existing]
    )
    @MainActor
    func accountSignInIncomplete(_ origin: BackendUserOrigin) async {
        let harness = TestDependencyHarness()
        harness.backendUserOrigin = origin
        harness.backendOnboardingCompleted = false
        let model = OnboardingFlowModel(dependencies: harness.makeDependencies())
        model.phase = .onboarding(.account)

        await model.authenticate(with: .apple, returning: false)

        #expect(model.phase == .onboarding(.photoPreparation))
        #expect(harness.events == ["signIn:apple", "resolveCurrentUser"])
        #expect(harness.bindingRequestCount == 0)
        #expect(harness.accessRequestCount == 0)
        #expect(harness.purchaseRequestCount == 0)
        #expect(harness.restoreRequestCount == 0)
        #expect(harness.accessMonitoringRequestCount == 0)
    }

    @Test(
        "Screen 05 existing completed account routes from refreshed access",
        arguments: [AccessStatus.active, .inactive]
    )
    @MainActor
    func accountSignInCompleted(_ status: AccessStatus) async {
        let harness = TestDependencyHarness()
        harness.backendUserOrigin = .existing
        harness.backendOnboardingCompleted = true
        harness.accessStatus = status
        let model = OnboardingFlowModel(dependencies: harness.makeDependencies())
        model.phase = .onboarding(.account)

        await model.authenticate(with: .google, returning: false)

        #expect(model.phase == Self.expectedPhase(for: status))
        #expect(harness.events == [
            "signIn:google", "resolveCurrentUser", "bind:test-user", "currentAccess", "accessUpdates"
        ])
    }

    @Test("Screen 05 resolution failure retry repeats PUT without provider sign-in")
    @MainActor
    func accountResolutionFailureRetriesOnlyResolution() async {
        let harness = TestDependencyHarness()
        harness.backendResolutionFailure = .transport("Account lookup failed")
        let model = OnboardingFlowModel(dependencies: harness.makeDependencies())
        model.phase = .onboarding(.account)

        await model.authenticate(with: .apple, returning: false)
        #expect(model.phase == .onboarding(.account))
        #expect(model.authenticationError == "Account lookup failed")
        #expect(model.accountOperationStage == .resolving(userID: "test-user", context: .account))

        harness.backendResolutionFailure = nil
        await model.retryAuthentication()

        #expect(model.phase == .onboarding(.photoPreparation))
        #expect(harness.authenticationRequestCount == 1)
        #expect(harness.backendResolutionRequestCount == 2)
        #expect(harness.events == [
            "signIn:apple", "resolveCurrentUser", "resolveCurrentUser"
        ])
    }

    @Test("Authentication failure retries the provider instead of becoming a no-op")
    @MainActor
    func authenticationFailureRetriesProvider() async {
        let harness = TestDependencyHarness()
        harness.authenticationFailure = .authentication("Sign-in failed")
        let model = OnboardingFlowModel(dependencies: harness.makeDependencies())
        model.phase = .onboarding(.account)

        await model.authenticate(with: .google, returning: false)
        #expect(model.phase == .onboarding(.account))
        #expect(model.authenticationError == "Sign-in failed")

        harness.authenticationFailure = nil
        await model.retryAuthentication()

        #expect(model.phase == .onboarding(.photoPreparation))
        #expect(harness.authenticationRequestCount == 2)
        #expect(harness.backendResolutionRequestCount == 1)
        #expect(harness.events == [
            "signIn:google", "signIn:google", "resolveCurrentUser"
        ])
    }

    @Test("Provider cancellation leaves screen 05 unchanged without backend or purchase work")
    @MainActor
    func authenticationCancellationIsSilent() async {
        let harness = TestDependencyHarness()
        harness.authenticationFailure = .cancelled
        let model = OnboardingFlowModel(dependencies: harness.makeDependencies())
        model.phase = .onboarding(.account)

        await model.authenticate(with: .apple, returning: false)

        #expect(model.phase == .onboarding(.account))
        #expect(model.authenticationError == nil)
        #expect(model.isAuthenticating == false)
        #expect(harness.events == ["signIn:apple"])
        #expect(harness.backendResolutionRequestCount == 0)
        #expect(harness.bindingRequestCount == 0)
    }

    @Test("Back from screen 05 prevents a late backend response from routing")
    @MainActor
    func backInvalidatesPendingAccountResolution() async {
        let backend = ControlledBackendUserHarness()
        defer { backend.cancelOutstandingRequests() }
        let purchase = ControlledPurchaseHarness()
        defer { purchase.cancelOutstandingRequests() }
        let harness = TestDependencyHarness()
        let model = OnboardingFlowModel(
            dependencies: harness.makeDependencies(
                backendUser: backend.client(),
                purchase: purchase.client()
            )
        )
        model.phase = .onboarding(.account)

        let authentication = Task { await model.authenticate(with: .google, returning: false) }
        await backend.waitForResolutionRequests(1)
        #expect(model.isConnectingAccount)

        model.goBack()
        backend.succeedResolutionRequest(0, with: Self.resolution(completed: true))
        await authentication.value

        #expect(model.phase == .onboarding(.direction))
        #expect(model.isConnectingAccount == false)
        #expect(purchase.bindingRequests.isEmpty)
        #expect(purchase.accessRequestCount == 0)
    }

    @Test("Cancelling screen 05 resolution leaves its route unchanged")
    @MainActor
    func cancellationDuringAccountResolutionIsSafe() async {
        let backend = ControlledBackendUserHarness()
        defer { backend.cancelOutstandingRequests() }
        let purchase = ControlledPurchaseHarness()
        defer { purchase.cancelOutstandingRequests() }
        let model = OnboardingFlowModel(
            dependencies: TestDependencyHarness().makeDependencies(
                backendUser: backend.client(),
                purchase: purchase.client()
            )
        )
        model.phase = .onboarding(.account)

        let authentication = Task { await model.authenticate(with: .apple, returning: false) }
        await backend.waitForResolutionRequests(1)
        authentication.cancel()
        #expect(await eventually { backend.cancelledResolutionRequests == [0] })
        backend.failResolutionRequest(0, with: CancellationError())
        await authentication.value

        #expect(model.phase == .onboarding(.account))
        #expect(model.authenticationError == nil)
        #expect(model.accountOperationStage == .idle)
        #expect(purchase.bindingRequests.isEmpty)
    }

    @Test("Overlapping screen 05 resolutions accept only the newest user")
    @MainActor
    func overlappingAccountResolutionsDiscardStaleResponse() async {
        let backend = ControlledBackendUserHarness()
        defer { backend.cancelOutstandingRequests() }
        let purchase = ControlledPurchaseHarness()
        defer { purchase.cancelOutstandingRequests() }
        let harness = TestDependencyHarness()
        harness.authenticatedUserID = "first-user"
        let model = OnboardingFlowModel(
            dependencies: harness.makeDependencies(
                backendUser: backend.client(),
                purchase: purchase.client()
            )
        )
        model.phase = .onboarding(.account)

        let first = Task { await model.authenticate(with: .apple, returning: false) }
        await backend.waitForResolutionRequests(1)
        harness.authenticatedUserID = "second-user"
        let second = Task { await model.authenticate(with: .google, returning: false) }
        await backend.waitForResolutionRequests(2)

        backend.succeedResolutionRequest(1, with: Self.resolution(origin: .existing, completed: false))
        await second.value
        backend.succeedResolutionRequest(0, with: Self.resolution(origin: .existing, completed: true))
        await first.value

        #expect(model.phase == .onboarding(.photoPreparation))
        #expect(harness.authenticationRequestCount == 2)
        #expect(purchase.bindingRequests.isEmpty)
        #expect(purchase.accessRequestCount == 0)
    }

    @Test("Google callback URLs are forwarded exactly once")
    @MainActor
    func googleCallbackForwarding() {
        let harness = TestDependencyHarness()
        let model = OnboardingFlowModel(dependencies: harness.makeDependencies())
        let callback = URL(string: "com.googleusercontent.apps.test:/oauth/callback?code=123")!

        model.handleOpenURL(callback)

        #expect(harness.handledURLs == [callback])
    }

    @Test("Screen 13 created incomplete account stays with notice and can start onboarding")
    @MainActor
    func returningCreatedIncompleteAccount() async {
        let harness = TestDependencyHarness()
        harness.backendUserOrigin = .created
        let model = OnboardingFlowModel(dependencies: harness.makeDependencies())
        model.phase = .onboarding(.returningSignIn)

        await model.authenticate(with: .google, returning: true)

        #expect(model.phase == .onboarding(.returningSignIn))
        #expect(model.returningAccountNotice != nil)
        #expect(harness.events == ["signIn:google", "resolveCurrentUser"])
        #expect(harness.bindingRequestCount == 0)
        #expect(harness.accessRequestCount == 0)
        #expect(harness.purchaseRequestCount == 0)
        #expect(harness.restoreRequestCount == 0)
        #expect(harness.accessMonitoringRequestCount == 0)
        #expect(harness.completionRequestCount == 0)
        #expect(harness.backendOnboardingCompleted == false)

        model.startOnboardingFromReturningAccount()
        #expect(model.phase == .onboarding(.welcome))
        #expect(model.returningAccountNotice == nil)
        #expect(harness.events == ["signIn:google", "resolveCurrentUser"])
        #expect(harness.completionRequestCount == 0)
        #expect(harness.backendOnboardingCompleted == false)
    }

    @Test("Provider failure on screen 13 remains recoverable without backend or purchase work")
    @MainActor
    func returningProviderFailure() async {
        let harness = TestDependencyHarness()
        harness.authenticationFailure = .authentication("Provider failed")
        let model = OnboardingFlowModel(dependencies: harness.makeDependencies())
        model.phase = .onboarding(.returningSignIn)

        await model.authenticate(with: .apple, returning: true)

        #expect(model.phase == .onboarding(.returningSignIn))
        #expect(model.authenticationError == "Provider failed")
        #expect(harness.events == ["signIn:apple"])
        #expect(harness.backendResolutionRequestCount == 0)
        #expect(harness.completionRequestCount == 0)
        #expect(harness.bindingRequestCount == 0)
        #expect(harness.accessRequestCount == 0)
    }

    @Test("Screen 13 existing incomplete account resumes at screen 06 without purchase work")
    @MainActor
    func returningExistingIncompleteAccount() async {
        let harness = TestDependencyHarness()
        harness.backendUserOrigin = .existing
        let model = OnboardingFlowModel(dependencies: harness.makeDependencies())
        model.phase = .onboarding(.returningSignIn)

        await model.authenticate(with: .apple, returning: true)

        #expect(model.phase == .onboarding(.photoPreparation))
        #expect(harness.events == ["signIn:apple", "resolveCurrentUser"])
        #expect(harness.bindingRequestCount == 0)
        #expect(harness.accessRequestCount == 0)
        #expect(harness.purchaseRequestCount == 0)
        #expect(harness.restoreRequestCount == 0)
        #expect(harness.accessMonitoringRequestCount == 0)
    }

    @Test("Back from screen 13 prevents a late backend response from routing")
    @MainActor
    func returningBackInvalidatesPendingAccountResolution() async {
        let backend = ControlledBackendUserHarness()
        defer { backend.cancelOutstandingRequests() }
        let purchase = ControlledPurchaseHarness()
        defer { purchase.cancelOutstandingRequests() }
        let model = OnboardingFlowModel(
            dependencies: TestDependencyHarness().makeDependencies(
                backendUser: backend.client(),
                purchase: purchase.client()
            )
        )
        model.phase = .onboarding(.returningSignIn)

        let authentication = Task { await model.authenticate(with: .apple, returning: true) }
        await backend.waitForResolutionRequests(1)
        model.goBack()
        backend.succeedResolutionRequest(0, with: Self.resolution(origin: .existing, completed: true))
        await authentication.value

        #expect(model.phase == .onboarding(.welcome))
        #expect(model.isConnectingAccount == false)
        #expect(model.accountOperationStage == .idle)
        #expect(purchase.bindingRequests.isEmpty)
        #expect(purchase.accessRequestCount == 0)
    }

    @Test("Provider cancellation on screen 13 remains silent without backend or purchase work")
    @MainActor
    func returningAuthenticationCancellationIsSilent() async {
        let harness = TestDependencyHarness()
        harness.authenticationFailure = .cancelled
        let model = OnboardingFlowModel(dependencies: harness.makeDependencies())
        model.phase = .onboarding(.returningSignIn)

        await model.authenticate(with: .google, returning: true)

        #expect(model.phase == .onboarding(.returningSignIn))
        #expect(model.authenticationError == nil)
        #expect(model.accountOperationStage == .idle)
        #expect(harness.backendResolutionRequestCount == 0)
        #expect(harness.bindingRequestCount == 0)
    }

    @Test("Cancelling screen 13 resolution leaves its route unchanged")
    @MainActor
    func cancellationDuringReturningResolutionIsSafe() async {
        let backend = ControlledBackendUserHarness()
        defer { backend.cancelOutstandingRequests() }
        let purchase = ControlledPurchaseHarness()
        defer { purchase.cancelOutstandingRequests() }
        let model = OnboardingFlowModel(
            dependencies: TestDependencyHarness().makeDependencies(
                backendUser: backend.client(),
                purchase: purchase.client()
            )
        )
        model.phase = .onboarding(.returningSignIn)

        let authentication = Task { await model.authenticate(with: .apple, returning: true) }
        await backend.waitForResolutionRequests(1)
        authentication.cancel()
        #expect(await eventually { backend.cancelledResolutionRequests == [0] })
        backend.failResolutionRequest(0, with: CancellationError())
        await authentication.value

        #expect(model.phase == .onboarding(.returningSignIn))
        #expect(model.authenticationError == nil)
        #expect(model.accountOperationStage == .idle)
        #expect(purchase.bindingRequests.isEmpty)
    }

    @Test("Incomplete routes never construct or configure the lazy purchase service")
    @MainActor
    func incompleteRouteSkipsLazyPurchaseInitialization() async {
        for entry in IncompleteBackendEntry.allCases {
            let cache = LazyPurchaseClientProxy.Cache()
            let purchase = ControlledPurchaseHarness()
            var configuredStateChecks = 0
            var factoryCalls = 0
            let proxy = LazyPurchaseClientProxy(
                apiKey: "fixture-api-key",
                entitlementID: "fixture-entitlement",
                cache: cache,
                isSDKConfigured: {
                    configuredStateChecks += 1
                    return false
                },
                factory: { _, _ in
                    factoryCalls += 1
                    return .init(client: purchase.client(), serviceOwner: NSObject())
                }
            )
            let harness = TestDependencyHarness()
            entry.prepare(harness: harness)
            let model = OnboardingFlowModel(
                dependencies: harness.makeDependencies(purchase: proxy.client())
            )

            await entry.resolve(in: model)

            #expect(entry.expectedPhase == model.phase)
            #expect(configuredStateChecks == 0)
            #expect(factoryCalls == 0)
            #expect(purchase.bindingRequests.isEmpty)
            #expect(purchase.accessRequestCount == 0)
            #expect(purchase.purchaseRequestCount == 0)
            #expect(purchase.restoreRequestCount == 0)
            #expect(purchase.accessMonitoringRequestCount == 0)
        }
    }

    @Test("Overlapping screen 13 resolutions accept only the newest user")
    @MainActor
    func overlappingReturningResolutionsDiscardStaleResponse() async {
        let backend = ControlledBackendUserHarness()
        defer { backend.cancelOutstandingRequests() }
        let purchase = ControlledPurchaseHarness()
        defer { purchase.cancelOutstandingRequests() }
        let harness = TestDependencyHarness()
        harness.authenticatedUserID = "first-returning-user"
        let model = OnboardingFlowModel(
            dependencies: harness.makeDependencies(
                backendUser: backend.client(),
                purchase: purchase.client()
            )
        )
        model.phase = .onboarding(.returningSignIn)

        let first = Task { await model.authenticate(with: .apple, returning: true) }
        await backend.waitForResolutionRequests(1)
        harness.authenticatedUserID = "second-returning-user"
        let second = Task { await model.authenticate(with: .google, returning: true) }
        await backend.waitForResolutionRequests(2)

        backend.succeedResolutionRequest(1, with: Self.resolution(origin: .existing, completed: false))
        await second.value
        backend.succeedResolutionRequest(0, with: Self.resolution(origin: .existing, completed: true))
        await first.value

        #expect(model.phase == .onboarding(.photoPreparation))
        #expect(purchase.bindingRequests.isEmpty)
        #expect(purchase.accessRequestCount == 0)
    }

    @Test(
        "Screen 13 completed account routes from refreshed access",
        arguments: [AccessStatus.active, .inactive]
    )
    @MainActor
    func returningCompletedAccount(_ status: AccessStatus) async {
        let harness = TestDependencyHarness()
        harness.backendUserOrigin = .existing
        harness.backendOnboardingCompleted = true
        harness.accessStatus = status
        let model = OnboardingFlowModel(dependencies: harness.makeDependencies())
        model.phase = .onboarding(.returningSignIn)

        await model.authenticate(with: .google, returning: true)

        #expect(model.phase == Self.expectedPhase(for: status))
        #expect(harness.events == [
            "signIn:google", "resolveCurrentUser", "bind:test-user", "currentAccess", "accessUpdates"
        ])
    }

    @Test("Screen 13 resolution retry repeats only PUT")
    @MainActor
    func returningResolutionFailureRetriesOnlyResolution() async {
        let harness = TestDependencyHarness()
        harness.backendResolutionFailure = .transport("Account lookup failed")
        let model = OnboardingFlowModel(dependencies: harness.makeDependencies())
        model.phase = .onboarding(.returningSignIn)

        await model.authenticate(with: .apple, returning: true)
        #expect(model.phase == .onboarding(.returningSignIn))
        #expect(model.authenticationError == "Account lookup failed")

        harness.backendResolutionFailure = nil
        harness.backendUserOrigin = .existing
        await model.retryAuthentication()

        #expect(model.phase == .onboarding(.photoPreparation))
        #expect(harness.authenticationRequestCount == 1)
        #expect(harness.backendResolutionRequestCount == 2)
        #expect(harness.bindingRequestCount == 0)
        #expect(harness.events == [
            "signIn:apple", "resolveCurrentUser", "resolveCurrentUser"
        ])
    }

    @Test("Screen 13 Back returns to Welcome")
    @MainActor
    func returningBackReturnsToWelcome() {
        let model = OnboardingFlowModel(dependencies: TestDependencyHarness().makeDependencies())
        model.phase = .onboarding(.returningSignIn)

        model.goBack()

        #expect(model.phase == .onboarding(.welcome))
    }

    @Test(
        "Screen 06, 09, and 11 PATCH before access and clear photo content after acknowledgement",
        arguments: CompletionInitiator.allCases
    )
    @MainActor
    func completionInitiatorsPatchBeforeAccess(_ initiator: CompletionInitiator) async {
        let log = ControlledOperationLog()
        let backend = ControlledBackendUserHarness(log: log)
        defer { backend.cancelOutstandingRequests() }
        let purchase = ControlledPurchaseHarness(log: log)
        defer { purchase.cancelOutstandingRequests() }
        let looks = ControlledLooksHarness()
        let harness = TestDependencyHarness()
        harness.userID = "completion-user"
        let model = OnboardingFlowModel(
            dependencies: harness.makeDependencies(
                backendUser: backend.client(),
                purchase: purchase.client(),
                looks: looks.client()
            )
        )
        await Self.finishIncompleteBootstrap(model, backend: backend)
        let photo = Self.photo(byte: 1)
        Self.populatePhotoDerivedContent(in: model, photo: photo)
        model.phase = .onboarding(initiator.step)

        initiator.begin(in: model)
        await backend.waitForCompletionRequests(1)

        #expect(model.phase == .onboarding(initiator.step))
        #expect(model.accountOperationStage == .completing(
            userID: "completion-user",
            step: initiator.step
        ))
        #expect(model.isCompletingOnboarding)
        #expect(model.draft.preparedPhoto == photo)
        #expect(purchase.bindingRequests.isEmpty)
        #expect(purchase.accessRequestCount == 0)
        #expect(log.events == ["resolveCurrentUser", "completeOnboarding"])

        initiator.begin(in: model)
        await Task.yield()
        #expect(backend.completionRequestCount == 1)

        backend.succeedCompletionRequest(0)
        await purchase.waitForBindingRequests(1)

        #expect(model.phase == .postOnboardingAccess)
        Self.expectPhotoDerivedContentCleared(in: model)
        #expect(await eventually { looks.clearedPhotoIDs == [photo.id] })
        #expect(log.events == [
            "resolveCurrentUser", "completeOnboarding", "bind:completion-user"
        ])

        purchase.succeedBindingRequest(0)
        await purchase.waitForAccessRequests(1)
        purchase.succeedAccessRequest(0, with: .inactive)

        #expect(await eventually { model.phase == .onboarding(.paywall) })
        #expect(log.events == [
            "resolveCurrentUser", "completeOnboarding", "bind:completion-user",
            "currentAccess", "accessUpdates"
        ])
        #expect(looks.clearedPhotoIDs == [photo.id])
    }

    @Test(
        "Completion failure preserves every initiating route and data; retry repeats only PATCH",
        arguments: CompletionInitiator.allCases
    )
    @MainActor
    func completionFailureRetriesOnlyCompletion(_ initiator: CompletionInitiator) async {
        let backend = ControlledBackendUserHarness()
        defer { backend.cancelOutstandingRequests() }
        let purchase = ControlledPurchaseHarness()
        defer { purchase.cancelOutstandingRequests() }
        let harness = TestDependencyHarness()
        harness.userID = "completion-user"
        let model = OnboardingFlowModel(
            dependencies: harness.makeDependencies(
                backendUser: backend.client(),
                purchase: purchase.client()
            )
        )
        await Self.finishIncompleteBootstrap(model, backend: backend)
        let photo = Self.photo(byte: 2)
        Self.populatePhotoDerivedContent(in: model, photo: photo)
        model.phase = .onboarding(initiator.step)

        initiator.begin(in: model)
        await backend.waitForCompletionRequests(1)
        backend.failCompletionRequest(0, with: ServiceFailure.transport("Completion failed"))
        #expect(await eventually {
            model.isCompletingOnboarding == false && model.completionError == "Completion failed"
        })

        #expect(model.phase == .onboarding(initiator.step))
        Self.expectPhotoDerivedContentPreserved(in: model, photo: photo)
        #expect(purchase.bindingRequests.isEmpty)

        model.retryOnboardingCompletion()
        await backend.waitForCompletionRequests(2)

        #expect(backend.resolutionRequestCount == 1)
        #expect(backend.completionRequestCount == 2)
        #expect(harness.authenticationRequestCount == 0)
        #expect(purchase.bindingRequests.isEmpty)

        backend.succeedCompletionRequest(1)
        await purchase.waitForBindingRequests(1)
        purchase.succeedBindingRequest(0)
        await purchase.waitForAccessRequests(1)
        purchase.succeedAccessRequest(0, with: .active)
        #expect(await eventually { model.phase == .main })
    }

    @Test(
        "Cancelled completion preserves every initiating route and photo data",
        arguments: CompletionInitiator.allCases
    )
    @MainActor
    func cancelledCompletionPreservesState(_ initiator: CompletionInitiator) async {
        let backend = ControlledBackendUserHarness()
        defer { backend.cancelOutstandingRequests() }
        let purchase = ControlledPurchaseHarness()
        defer { purchase.cancelOutstandingRequests() }
        let harness = TestDependencyHarness()
        harness.userID = "completion-user"
        let model = OnboardingFlowModel(
            dependencies: harness.makeDependencies(
                backendUser: backend.client(),
                purchase: purchase.client()
            )
        )
        await Self.finishIncompleteBootstrap(model, backend: backend)
        let photo = Self.photo(byte: 3)
        Self.populatePhotoDerivedContent(in: model, photo: photo)
        model.phase = .onboarding(initiator.step)

        initiator.begin(in: model)
        await backend.waitForCompletionRequests(1)
        model.cancelOnboardingCompletion()
        #expect(await eventually { backend.cancelledCompletionRequests == [0] })
        backend.succeedCompletionRequest(0)

        #expect(await eventually { model.isCompletingOnboarding == false })
        #expect(model.phase == .onboarding(initiator.step))
        #expect(model.accountOperationStage == .completing(
            userID: "completion-user",
            step: initiator.step
        ))
        Self.expectPhotoDerivedContentPreserved(in: model, photo: photo)
        #expect(model.completionError == nil)
        #expect(purchase.bindingRequests.isEmpty)
        #expect(purchase.accessRequestCount == 0)
    }

    @Test(
        "Stale completion response from every initiator cannot route or clear data",
        arguments: CompletionInitiator.allCases
    )
    @MainActor
    func staleCompletionResponseIsIgnored(_ initiator: CompletionInitiator) async {
        let backend = ControlledBackendUserHarness()
        defer { backend.cancelOutstandingRequests() }
        let purchase = ControlledPurchaseHarness()
        defer { purchase.cancelOutstandingRequests() }
        let harness = TestDependencyHarness()
        harness.userID = "completion-user"
        let model = OnboardingFlowModel(
            dependencies: harness.makeDependencies(
                backendUser: backend.client(),
                purchase: purchase.client()
            )
        )
        await Self.finishIncompleteBootstrap(model, backend: backend)
        let photo = Self.photo(byte: 4)
        Self.populatePhotoDerivedContent(in: model, photo: photo)
        model.phase = .onboarding(initiator.step)

        initiator.begin(in: model)
        await backend.waitForCompletionRequests(1)
        model.phase = .onboarding(initiator.replacementStep)
        backend.succeedCompletionRequest(0)
        var reachedActorBarrier = false
        Task { @MainActor in reachedActorBarrier = true }
        #expect(await eventually { reachedActorBarrier })

        #expect(model.phase == .onboarding(initiator.replacementStep))
        Self.expectPhotoDerivedContentPreserved(in: model, photo: photo)
        #expect(model.isCompletingOnboarding == false)
        #expect(model.accountOperationStage == .idle)
        #expect(purchase.bindingRequests.isEmpty)
        #expect(purchase.accessRequestCount == 0)
    }

    @Test(
        "Successful completion routes active access to Main and inactive access to paywall",
        arguments: [AccessStatus.active, .inactive]
    )
    @MainActor
    func completionAccessOutcomes(_ status: AccessStatus) async {
        let looks = ControlledLooksHarness()
        let harness = TestDependencyHarness()
        harness.userID = "completion-user"
        harness.accessStatus = status
        let model = OnboardingFlowModel(
            dependencies: harness.makeDependencies(looks: looks.client())
        )
        await model.bootstrap()
        let photo = Self.photo(byte: 5)
        Self.populatePhotoDerivedContent(in: model, photo: photo)

        model.skipHarmonyCheck()

        #expect(await eventually { model.phase == Self.expectedPhase(for: status) })
        #expect(harness.events == [
            "resolveCurrentUser", "completeOnboarding", "bind:completion-user",
            "currentAccess", "accessUpdates"
        ])
        Self.expectPhotoDerivedContentCleared(in: model)
        #expect(await eventually { looks.clearedPhotoIDs == [photo.id] })
    }

    @Test(
        "Binding and access failures remain pending and retry only access handoff",
        arguments: AccessFailureStage.allCases
    )
    @MainActor
    func accessHandoffFailureRetriesOnlyAccess(_ failureStage: AccessFailureStage) async {
        let harness = TestDependencyHarness()
        harness.userID = "access-user"
        harness.backendOnboardingCompleted = true
        failureStage.installFailure(in: harness)
        let model = OnboardingFlowModel(dependencies: harness.makeDependencies())

        await model.bootstrap()

        #expect(model.phase == .postOnboardingAccess)
        #expect(model.accountOperationStage == .accessPending(userID: "access-user"))
        #expect(model.accessError == failureStage.message)
        #expect(harness.accessMonitoringRequestCount == 0)
        let authenticationCount = harness.authenticationRequestCount
        let resolutionCount = harness.backendResolutionRequestCount
        let completionCount = harness.completionRequestCount
        failureStage.removeFailure(from: harness)
        harness.accessStatus = .active

        model.retryAccessHandoff()

        #expect(await eventually { model.phase == .main })
        #expect(harness.authenticationRequestCount == authenticationCount)
        #expect(harness.backendResolutionRequestCount == resolutionCount)
        #expect(harness.completionRequestCount == completionCount)
        #expect(harness.bindingRequestCount == 2)
        #expect(harness.accessRequestCount == failureStage.expectedAccessRequestCount)
        #expect(harness.accessMonitoringRequestCount == 1)
    }

    @Test("Access retry reuses one lazy purchase service without reconfiguration")
    @MainActor
    func accessRetryDoesNotReconfigurePurchaseSDK() async {
        let cache = LazyPurchaseClientProxy.Cache()
        let purchase = FailOnceAccessPurchaseHarness()
        var actions: [LazyPurchaseClientProxy.ConfigurationAction] = []
        var configuredStateChecks = 0
        var factoryCalls = 0
        let proxy = LazyPurchaseClientProxy(
            apiKey: "fixture-api-key",
            entitlementID: "fixture-entitlement",
            cache: cache,
            isSDKConfigured: {
                configuredStateChecks += 1
                return false
            },
            factory: { action, _ in
                actions.append(action)
                factoryCalls += 1
                return .init(client: purchase.client(), serviceOwner: purchase)
            }
        )
        let harness = TestDependencyHarness()
        harness.userID = "access-user"
        harness.backendOnboardingCompleted = true
        let model = OnboardingFlowModel(
            dependencies: harness.makeDependencies(purchase: proxy.client())
        )

        await model.bootstrap()
        #expect(model.phase == .postOnboardingAccess)
        #expect(model.accessError == "Access failed")

        model.retryAccessHandoff()
        #expect(await eventually { model.phase == .main })

        #expect(actions == [.configure(apiKey: "fixture-api-key")])
        #expect(configuredStateChecks == 1)
        #expect(factoryCalls == 1)
        #expect(purchase.events == [
            "bind:access-user", "currentAccess",
            "bind:access-user", "currentAccess", "accessUpdates"
        ])
        #expect(harness.backendResolutionRequestCount == 1)
        #expect(harness.completionRequestCount == 0)
        #expect(harness.authenticationRequestCount == 0)
    }

    @Test("Access monitoring begins only after bind and evaluation both succeed")
    @MainActor
    func monitoringStartsAfterSuccessfulEvaluation() async {
        let purchase = ControlledPurchaseHarness()
        defer { purchase.cancelOutstandingRequests() }
        let harness = TestDependencyHarness()
        harness.userID = "monitor-user"
        harness.backendOnboardingCompleted = true
        let model = OnboardingFlowModel(
            dependencies: harness.makeDependencies(purchase: purchase.client())
        )

        let bootstrap = Task { await model.bootstrap() }
        await purchase.waitForBindingRequests(1)
        #expect(model.phase == .postOnboardingAccess)
        #expect(purchase.accessMonitoringRequestCount == 0)

        purchase.succeedBindingRequest(0)
        await purchase.waitForAccessRequests(1)
        #expect(purchase.accessMonitoringRequestCount == 0)

        purchase.succeedAccessRequest(0, with: .active)
        await bootstrap.value

        #expect(model.phase == .main)
        #expect(purchase.accessMonitoringRequestCount == 1)
    }

    @Test("Cancelled access evaluation remains retryable without repeating backend work")
    @MainActor
    func cancelledAccessEvaluationRemainsRetryable() async {
        let backend = ControlledBackendUserHarness()
        defer { backend.cancelOutstandingRequests() }
        let purchase = ControlledPurchaseHarness()
        defer { purchase.cancelOutstandingRequests() }
        let harness = TestDependencyHarness()
        harness.userID = "access-user"
        let model = OnboardingFlowModel(
            dependencies: harness.makeDependencies(
                backendUser: backend.client(),
                purchase: purchase.client()
            )
        )
        let bootstrap = Task { await model.bootstrap() }
        await backend.waitForResolutionRequests(1)
        backend.succeedResolutionRequest(
            0,
            with: Self.resolution(origin: .existing, completed: true)
        )
        await purchase.waitForBindingRequests(1)

        bootstrap.cancel()
        #expect(await eventually { purchase.cancelledBindingRequests == [0] })
        purchase.succeedBindingRequest(0)
        await bootstrap.value

        #expect(model.phase == .postOnboardingAccess)
        #expect(model.accountOperationStage == .accessPending(userID: "access-user"))
        #expect(model.isVerifyingAccess == false)
        #expect(model.accessError == "Access verification was interrupted. Try again.")
        #expect(purchase.accessRequestCount == 0)

        model.retryAccessHandoff()
        await purchase.waitForBindingRequests(2)
        purchase.succeedBindingRequest(1)
        await purchase.waitForAccessRequests(1)
        purchase.succeedAccessRequest(0, with: .active)

        #expect(await eventually { model.phase == .main })
        #expect(backend.resolutionRequestCount == 1)
        #expect(backend.completionRequestCount == 0)
        #expect(purchase.bindingRequests == ["access-user", "access-user"])
        #expect(purchase.accessRequestCount == 1)
    }

    @Test(
        "Purchase and restore authorize only from paywall after backend completion",
        arguments: PaywallAuthorizationOperation.allCases
    )
    @MainActor
    func paywallAuthorizationRequiresCompletion(_ operation: PaywallAuthorizationOperation) async {
        let harness = TestDependencyHarness()
        harness.userID = "paywall-user"
        harness.accessStatus = .inactive
        operation.setActiveResult(in: harness)
        let model = OnboardingFlowModel(dependencies: harness.makeDependencies())
        await model.bootstrap()
        #expect(model.phase == .onboarding(.photoPreparation))

        await operation.perform(in: model)
        #expect(operation.requestCount(in: harness) == 0)
        #expect(model.phase == .onboarding(.photoPreparation))

        model.skipHarmonyCheck()
        #expect(await eventually { model.phase == .onboarding(.paywall) })
        #expect(harness.completionRequestCount == 1)
        #expect(harness.events.prefix(5) == [
            "resolveCurrentUser", "completeOnboarding", "bind:paywall-user",
            "currentAccess", "accessUpdates"
        ])

        await operation.perform(in: model)

        #expect(model.phase == .main)
        #expect(operation.requestCount(in: harness) == 1)
    }

    @Test(
        "Restore remains on the hard paywall for inactive and failed outcomes after completion",
        arguments: PaywallRestoreOutcome.allCases
    )
    @MainActor
    func restoreFailureAfterCompletion(_ outcome: PaywallRestoreOutcome) async {
        let harness = TestDependencyHarness()
        harness.userID = "restore-user"
        harness.accessStatus = .inactive
        outcome.configure(harness)
        let model = OnboardingFlowModel(dependencies: harness.makeDependencies())
        await model.bootstrap()

        model.skipHarmonyCheck()
        #expect(await eventually { model.phase == .onboarding(.paywall) })
        #expect(harness.completionRequestCount == 1)

        await model.restore()

        #expect(model.phase == .onboarding(.paywall))
        #expect(model.purchaseError == outcome.expectedMessage)
        #expect(harness.restoreRequestCount == 1)
    }

    @Test("Hard paywall remains locked until purchase returns active access")
    @MainActor
    func hardPaywallAuthorization() async {
        let harness = TestDependencyHarness()
        harness.userID = "test-user"
        harness.backendOnboardingCompleted = true
        harness.accessStatus = .inactive
        let model = OnboardingFlowModel(dependencies: harness.makeDependencies())
        await model.bootstrap()
        #expect(model.phase == .onboarding(.paywall))

        model.goBack()
        #expect(model.phase == .onboarding(.paywall))

        harness.purchaseStatus = .inactive
        await model.purchase()
        #expect(model.phase == .onboarding(.paywall))
        #expect(model.purchaseError != nil)

        harness.purchaseStatus = .active
        await model.purchase()
        #expect(model.phase == .main)
        #expect(model.purchaseError == nil)
    }

    @Test(
        "Every completion entry clears the exact photo lifecycle",
        arguments: PaywallEntryRoute.allCases
    )
    @MainActor
    func completionEntryClearsPhotoLifecycle(_ route: PaywallEntryRoute) async {
        let looks = ControlledLooksHarness()
        let harness = TestDependencyHarness()
        harness.userID = "test-user"
        harness.accessStatus = .inactive
        let model = OnboardingFlowModel(
            dependencies: harness.makeDependencies(looks: looks.client())
        )
        await model.bootstrap()
        let photo = Self.photo(byte: 1)
        Self.populatePhotoDerivedContent(in: model, photo: photo)

        route.beginCompletion(in: model)

        #expect(await eventually { model.phase == .onboarding(.paywall) })
        #expect(harness.completionRequestCount == 1)
        Self.expectPhotoDerivedContentCleared(in: model)
        #expect(await eventually { looks.clearedPhotoIDs == [photo.id] })
    }

    @Test("Skip invalidates photo preparation before PATCH acknowledgement")
    @MainActor
    func skipInvalidatesPhotoPreparation() async {
        let backend = ControlledBackendUserHarness()
        defer { backend.cancelOutstandingRequests() }
        let processor = ControlledPhotoProcessor()
        let harness = TestDependencyHarness()
        harness.userID = "test-user"
        harness.accessStatus = .inactive
        let model = OnboardingFlowModel(
            dependencies: harness.makeDependencies(
                backendUser: backend.client(),
                photoProcessing: processor.client()
            )
        )
        await Self.finishIncompleteBootstrap(model, backend: backend)
        let input = Data([1])
        let preparation = Task { await model.preparePhoto(data: input) }
        await processor.waitUntilRequested(input)

        model.skipHarmonyCheck()
        await backend.waitForCompletionRequests(1)
        await processor.succeed(Self.photo(byte: 1), for: input)
        await preparation.value

        #expect(model.phase == .onboarding(.photoPreparation))
        #expect(model.isCompletingOnboarding)
        #expect(model.draft.preparedPhoto == nil)

        backend.failCompletionRequest(0, with: ServiceFailure.transport("Completion failed"))
        #expect(await eventually { model.completionError == "Completion failed" })
        #expect(model.phase == .onboarding(.photoPreparation))
        #expect(model.draft.preparedPhoto == nil)
    }

    @Test("Skip invalidates pending camera permission before PATCH acknowledgement")
    @MainActor
    func skipInvalidatesCameraPermission() async {
        let backend = ControlledBackendUserHarness()
        defer { backend.cancelOutstandingRequests() }
        var permissionContinuation: CheckedContinuation<Bool, Never>?
        let cameraAccess = CameraAccessClient(
            isAvailable: { true },
            authorizationState: { .notDetermined },
            requestAccess: {
                await withCheckedContinuation { permissionContinuation = $0 }
            }
        )
        let harness = TestDependencyHarness()
        harness.userID = "test-user"
        let model = OnboardingFlowModel(
            dependencies: harness.makeDependencies(
                backendUser: backend.client(),
                cameraAccess: cameraAccess
            )
        )
        await Self.finishIncompleteBootstrap(model, backend: backend)
        let permission = Task { await model.requestCamera() }
        #expect(await eventually { permissionContinuation != nil })

        model.skipHarmonyCheck()
        await backend.waitForCompletionRequests(1)
        permissionContinuation?.resume(returning: true)
        permissionContinuation = nil

        #expect(await permission.value == false)
        #expect(model.phase == .onboarding(.photoPreparation))
        #expect(model.isCompletingOnboarding)
    }

    @Test("A replacement clears the prior session and retains only the latest photo bytes")
    @MainActor
    func replacementPhotoRetainsLatestSelection() async {
        let processor = ControlledPhotoProcessor()
        let looks = ControlledLooksHarness()
        let model = OnboardingFlowModel(
            dependencies: TestDependencyHarness().makeDependencies(
                looks: looks.client(),
                photoProcessing: processor.client()
            )
        )
        model.phase = .onboarding(.photoPreparation)
        let originalPhoto = Self.photo(byte: 0)
        Self.populatePhotoDerivedContent(in: model, photo: originalPhoto)
        let firstInput = Data([1])
        let secondInput = Data([2])
        let firstPhoto = Self.photo(byte: 1)
        let secondPhoto = Self.photo(byte: 2)

        let first = Task { await model.preparePhoto(data: firstInput) }
        await processor.waitUntilRequested(firstInput)
        let second = Task { await model.preparePhoto(data: secondInput) }
        await processor.waitUntilRequested(secondInput)

        await processor.succeed(secondPhoto, for: secondInput)
        await second.value
        #expect(model.draft.preparedPhoto?.displayData == secondPhoto.displayData)
        #expect(model.draft.preparedPhoto?.uploadData == secondPhoto.uploadData)
        #expect(model.draft.harmonyResult?.annotatedImageData == nil)
        #expect(model.draft.generatedLook?.imageData == nil)
        #expect(Self.isIdle(model.analysisPhase))
        #expect(Self.isIdle(model.generationPhase))
        #expect(model.comparisonSplit == 0.46)
        #expect(await eventually { looks.clearedPhotoIDs == [originalPhoto.id] })

        await processor.succeed(firstPhoto, for: firstInput)
        await first.value

        #expect(model.phase == .onboarding(.photoReview))
        #expect(model.draft.preparedPhoto == secondPhoto)
        #expect(looks.clearedPhotoIDs == [originalPhoto.id])
    }

    @Test("Analysis retry cancels the prior request and ignores its stale completion")
    @MainActor
    func analysisRetryReplacesPriorRequest() async {
        let looks = ControlledLooksHarness()
        defer { looks.cancelOutstandingRequests() }
        let model = OnboardingFlowModel(
            dependencies: TestDependencyHarness().makeDependencies(looks: looks.client())
        )
        let photo = Self.photo(byte: 1)
        let staleResult = Self.harmony(title: "Stale")
        let latestResult = Self.harmony(title: "Latest")
        model.phase = .onboarding(.photoReview)
        model.draft.preparedPhoto = photo

        model.usePhoto()
        await looks.waitForAnalysisRequests(1)
        #expect(looks.analysisInputs == [photo])
        #expect(model.phase == .onboarding(.analysisProcessing))
        #expect(model.analysisPhase.isLoading)

        model.retryAnalysis()
        await looks.waitForAnalysisRequests(2)
        #expect(await eventually { looks.cancelledAnalysisRequests == [0] })

        looks.succeedAnalysisRequest(1, with: latestResult)
        #expect(await eventually { model.phase == .onboarding(.harmonySnapshot) })
        #expect(model.draft.harmonyResult == latestResult)

        looks.succeedAnalysisRequest(0, with: staleResult)
        for _ in 0..<10 { await Task.yield() }
        #expect(model.phase == .onboarding(.harmonySnapshot))
        #expect(model.draft.harmonyResult == latestResult)
    }

    @Test("Generation retry cancels the prior request and keeps only the latest presentation-ready result")
    @MainActor
    func generationRetryReplacesPriorRequest() async {
        let looks = ControlledLooksHarness()
        defer { looks.cancelOutstandingRequests() }
        let model = OnboardingFlowModel(
            dependencies: TestDependencyHarness().makeDependencies(looks: looks.client())
        )
        let photo = Self.photo(byte: 1)
        let harmony = Self.harmony(title: "Current")
        let staleLook = Self.look(name: "Stale", path: "stale.jpg")
        let latestLook = Self.look(name: "Latest", path: "latest.jpg")
        model.phase = .onboarding(.harmonySnapshot)
        model.draft.preparedPhoto = photo
        model.draft.harmonyResult = harmony

        model.showMatchingStyle()
        await looks.waitForGenerationRequests(1)
        #expect(looks.generationInputs.count == 1)
        #expect(looks.generationInputs[0].0 == photo)
        #expect(looks.generationInputs[0].1 == harmony)
        #expect(model.phase == .onboarding(.generationProcessing))
        #expect(model.generationPhase.isLoading)

        model.retryGeneration()
        await looks.waitForGenerationRequests(2)
        #expect(await eventually { looks.cancelledGenerationRequests == [0] })

        looks.succeedGenerationRequest(1, with: latestLook)
        #expect(await eventually { model.phase == .onboarding(.firstResult) })
        #expect(model.draft.generatedLook == latestLook)

        looks.succeedGenerationRequest(0, with: staleLook)
        for _ in 0..<10 { await Task.yield() }
        #expect(model.phase == .onboarding(.firstResult))
        #expect(model.draft.generatedLook == latestLook)
    }

    @Test(
        "Memory pressure clears the exact photo lifecycle and cancels in-flight work",
        arguments: InFlightLookOperation.allCases
    )
    @MainActor
    func memoryWarningCleanup(_ operation: InFlightLookOperation) async {
        let looks = ControlledLooksHarness()
        defer { looks.cancelOutstandingRequests() }
        let model = OnboardingFlowModel(
            dependencies: TestDependencyHarness().makeDependencies(looks: looks.client())
        )
        let photo = Self.photo(byte: 1)
        Self.populatePhotoDerivedContent(in: model, photo: photo)

        switch operation {
        case .analysis:
            model.phase = .onboarding(.photoReview)
            model.usePhoto()
            await looks.waitForAnalysisRequests(1)
        case .generation:
            model.phase = .onboarding(.harmonySnapshot)
            model.showMatchingStyle()
            await looks.waitForGenerationRequests(1)
        }

        model.handleMemoryWarning()

        #expect(model.phase == .onboarding(.photoPreparation))
        Self.expectPhotoDerivedContentCleared(in: model)
        #expect(model.photoError != nil)
        #expect(await eventually {
            looks.clearedPhotoIDs == [photo.id]
                && operation.wasRequestCancelled(by: looks)
        })
    }

    @Test("Termination-style model replacement restores backend route without photo content")
    @MainActor
    func terminationDoesNotRestorePhotoContent() async {
        let harness = TestDependencyHarness()
        harness.userID = "test-user"
        harness.accessStatus = .inactive
        let dependencies = harness.makeDependencies()
        let firstModel = OnboardingFlowModel(dependencies: dependencies)
        await firstModel.bootstrap()
        firstModel.phase = .onboarding(.firstResult)
        firstModel.draft.preparedPhoto = Self.photo(byte: 1)
        firstModel.draft.harmonyResult = Self.harmony(title: "Stored only in memory")
        firstModel.draft.generatedLook = Self.look(name: "Stored only in memory", path: "memory.jpg")

        let relaunchedModel = OnboardingFlowModel(dependencies: dependencies)
        await relaunchedModel.bootstrap()

        #expect(relaunchedModel.phase == .onboarding(.photoPreparation))
        #expect(relaunchedModel.draft.preparedPhoto == nil)
        #expect(relaunchedModel.draft.harmonyResult == nil)
        #expect(relaunchedModel.draft.generatedLook == nil)
    }

    @Test(
        "Every legacy persisted gate value has no routing effect",
        arguments: LegacyGateFixture.allCases
    )
    @MainActor
    func legacyGateHasNoRoutingEffect(_ fixture: LegacyGateFixture) async {
        let defaults = UserDefaults.standard
        let userID = "legacy-gate-\(UUID().uuidString)"
        let key = "notmeyet.onboarding.gate.\(Data(userID.utf8).base64EncodedString())"
        defaults.set(fixture.data, forKey: key)
        defer { defaults.removeObject(forKey: key) }
        let harness = TestDependencyHarness()
        harness.userID = userID
        harness.accessStatus = .inactive
        let model = OnboardingFlowModel(dependencies: harness.makeDependencies())

        await model.bootstrap()

        #expect(model.phase == .onboarding(.photoPreparation))
        #expect(harness.events == ["resolveCurrentUser"])
        #expect(harness.bindingRequestCount == 0)
        #expect(harness.accessRequestCount == 0)
        #expect(defaults.data(forKey: key) != nil)
    }

    @Test(
        "Retake and Main entry clear the exact photo lifecycle",
        arguments: PhotoLifecycleRoute.allCases
    )
    @MainActor
    func photoLifecycleCleanup(_ route: PhotoLifecycleRoute) async {
        let looks = ControlledLooksHarness()
        let harness = TestDependencyHarness()
        if route == .mainEntry {
            harness.userID = "test-user"
            harness.backendOnboardingCompleted = true
            harness.accessStatus = .inactive
            harness.purchaseStatus = .active
        }
        let model = OnboardingFlowModel(
            dependencies: harness.makeDependencies(looks: looks.client())
        )
        if route == .mainEntry {
            await model.bootstrap()
            #expect(model.phase == .onboarding(.paywall))
        }
        let photo = Self.photo(byte: 1)
        Self.populatePhotoDerivedContent(in: model, photo: photo)

        switch route {
        case .retake:
            model.phase = .onboarding(.photoReview)
            model.retakePhoto()
            #expect(model.phase == .onboarding(.photoPreparation))
        case .mainEntry:
            await model.purchase()
            #expect(model.phase == .main)
        }

        Self.expectPhotoDerivedContentCleared(in: model)
        #expect(await eventually { looks.clearedPhotoIDs == [photo.id] })
    }

    @Test("Long-lived access updates do not retain the flow model")
    @MainActor
    func accessMonitoringDoesNotRetainModel() async {
        let harness = TestDependencyHarness()
        harness.userID = "test-user"
        harness.backendOnboardingCompleted = true
        harness.accessStatus = .active
        var model: OnboardingFlowModel? = OnboardingFlowModel(
            dependencies: harness.makeDependencies()
        )
        await model?.bootstrap()
        #expect(await eventually { harness.isMonitoringAccess })
        let modelReference = WeakReference(model)

        model = nil

        #expect(await eventually { modelReference.value == nil })
    }

    @Test("Later entitlement revocation removes Main access")
    @MainActor
    func entitlementRevocation() async {
        let harness = TestDependencyHarness()
        harness.userID = "test-user"
        harness.backendOnboardingCompleted = true
        harness.accessStatus = .active
        let model = OnboardingFlowModel(dependencies: harness.makeDependencies())
        await model.bootstrap()
        #expect(model.phase == .main)
        let monitoringStarted = await eventually { harness.isMonitoringAccess }
        #expect(monitoringStarted)

        harness.sendAccessUpdate(.inactive)

        let reachedPaywall = await eventually { model.phase == .onboarding(.paywall) }
        #expect(reachedPaywall)
    }

    @MainActor
    private static func expectedPhase(for status: AccessStatus) -> AppAccessPhase {
        status == .active ? .main : .onboarding(.paywall)
    }

    private static func resolution(
        origin: BackendUserOrigin = .created,
        completed: Bool
    ) -> BackendUserResolution {
        BackendUserResolution(origin: origin, onboardingCompleted: completed)
    }

    @MainActor
    private static func finishIncompleteBootstrap(
        _ model: OnboardingFlowModel,
        backend: ControlledBackendUserHarness
    ) async {
        let bootstrap = Task { await model.bootstrap() }
        await backend.waitForResolutionRequests(1)
        backend.succeedResolutionRequest(0, with: resolution(completed: false))
        await bootstrap.value
        #expect(model.phase == .onboarding(.photoPreparation))
    }

    private static func photo(byte: UInt8) -> PreparedPhoto {
        PreparedPhoto(
            displayData: Data([byte]),
            uploadData: Data([byte]),
            pixelWidth: 10,
            pixelHeight: 12
        )
    }

    private static func harmony(title: String) -> HarmonyResult {
        HarmonyResult(
            annotatedImageData: Data(title.utf8),
            faceShape: title,
            harmonyScore: 88.6
        )
    }

    private static func look(name: String, path: String) -> GeneratedLook {
        GeneratedLook(
            imageData: Data(path.utf8),
            styleName: name,
            styleDescription: "Description for \(name)"
        )
    }

    @MainActor
    private static func populatePhotoDerivedContent(
        in model: OnboardingFlowModel,
        photo: PreparedPhoto
    ) {
        let harmonyResult = harmony(title: "Current")
        let generatedLook = look(name: "Current", path: "current.jpg")
        model.draft.preparedPhoto = photo
        model.draft.harmonyResult = harmonyResult
        model.draft.generatedLook = generatedLook
        model.analysisPhase = .loaded(harmonyResult)
        model.generationPhase = .loaded(generatedLook)
        model.setComparisonSplit(0.8)
    }

    @MainActor
    private static func expectPhotoDerivedContentPreserved(
        in model: OnboardingFlowModel,
        photo: PreparedPhoto
    ) {
        #expect(model.draft.preparedPhoto == photo)
        #expect(model.draft.harmonyResult == harmony(title: "Current"))
        #expect(model.draft.generatedLook == look(name: "Current", path: "current.jpg"))
        #expect(model.comparisonSplit == 0.8)
    }

    @MainActor
    private static func expectPhotoDerivedContentCleared(in model: OnboardingFlowModel) {
        #expect(model.draft.preparedPhoto?.displayData == nil)
        #expect(model.draft.preparedPhoto?.uploadData == nil)
        #expect(model.draft.harmonyResult?.annotatedImageData == nil)
        #expect(model.draft.generatedLook?.imageData == nil)
        #expect(model.comparisonSplit == 0.46)
        #expect(isIdle(model.analysisPhase))
        #expect(isIdle(model.generationPhase))
    }

    private static func isIdle<Value>(_ phase: OperationPhase<Value>) -> Bool {
        if case .idle = phase { return true }
        return false
    }

    enum PaywallEntryRoute: CaseIterable, Sendable {
        case skipHarmonyCheck
        case skipLook
        case tryMore

        @MainActor
        func beginCompletion(in model: OnboardingFlowModel) {
            switch self {
            case .skipHarmonyCheck:
                model.phase = .onboarding(.photoPreparation)
                model.skipHarmonyCheck()
            case .skipLook:
                model.phase = .onboarding(.harmonySnapshot)
                model.skipLook()
            case .tryMore:
                model.phase = .onboarding(.firstResult)
                model.tryMore()
            }
        }
    }

    enum CompletionInitiator: CaseIterable, Sendable {
        case screen06
        case screen09
        case screen11

        var step: OnboardingStep {
            switch self {
            case .screen06: .photoPreparation
            case .screen09: .harmonySnapshot
            case .screen11: .firstResult
            }
        }

        var replacementStep: OnboardingStep {
            switch self {
            case .screen06, .screen11: .harmonySnapshot
            case .screen09: .firstResult
            }
        }

        @MainActor
        func begin(in model: OnboardingFlowModel) {
            switch self {
            case .screen06: model.skipHarmonyCheck()
            case .screen09: model.skipLook()
            case .screen11: model.tryMore()
            }
        }
    }

    enum AccessFailureStage: CaseIterable, Sendable {
        case binding
        case access

        var message: String {
            switch self {
            case .binding: "Binding failed"
            case .access: "Access failed"
            }
        }

        var expectedAccessRequestCount: Int {
            switch self {
            case .binding: 1
            case .access: 2
            }
        }

        @MainActor
        func installFailure(in harness: TestDependencyHarness) {
            switch self {
            case .binding: harness.bindingFailure = .identityBinding(message)
            case .access: harness.accessFailure = .access(message)
            }
        }

        @MainActor
        func removeFailure(from harness: TestDependencyHarness) {
            switch self {
            case .binding: harness.bindingFailure = nil
            case .access: harness.accessFailure = nil
            }
        }
    }

    enum PaywallAuthorizationOperation: CaseIterable, Sendable {
        case purchase
        case restore

        @MainActor
        func setActiveResult(in harness: TestDependencyHarness) {
            switch self {
            case .purchase: harness.purchaseStatus = .active
            case .restore: harness.restoreStatus = .active
            }
        }

        @MainActor
        func perform(in model: OnboardingFlowModel) async {
            switch self {
            case .purchase: await model.purchase()
            case .restore: await model.restore()
            }
        }

        @MainActor
        func requestCount(in harness: TestDependencyHarness) -> Int {
            switch self {
            case .purchase: harness.purchaseRequestCount
            case .restore: harness.restoreRequestCount
            }
        }
    }

    enum BackendResolutionEntry: CaseIterable, Sendable {
        case launch
        case account
        case returning

        @MainActor
        func prepare(harness: TestDependencyHarness) {
            if self == .launch {
                harness.userID = "invalid-user"
            }
        }

        @MainActor
        func resolve(in model: OnboardingFlowModel) async {
            switch self {
            case .launch:
                await model.bootstrap()
            case .account:
                model.phase = .onboarding(.account)
                await model.authenticate(with: .apple, returning: false)
            case .returning:
                model.phase = .onboarding(.returningSignIn)
                await model.authenticate(with: .google, returning: true)
            }
        }

        @MainActor
        func didRemainFailClosed(_ model: OnboardingFlowModel) -> Bool {
            switch self {
            case .launch:
                if case .configurationUnavailable = model.phase { return true }
                return false
            case .account:
                return model.phase == .onboarding(.account) && model.authenticationError != nil
            case .returning:
                return model.phase == .onboarding(.returningSignIn) && model.authenticationError != nil
            }
        }
    }

    enum IncompleteBackendEntry: CaseIterable, Sendable {
        case launch
        case account
        case returningCreated
        case returningExisting

        var expectedPhase: AppAccessPhase {
            switch self {
            case .launch, .account, .returningExisting:
                .onboarding(.photoPreparation)
            case .returningCreated:
                .onboarding(.returningSignIn)
            }
        }

        @MainActor
        func prepare(harness: TestDependencyHarness) {
            harness.backendOnboardingCompleted = false
            switch self {
            case .launch:
                harness.userID = "incomplete-user"
                harness.backendUserOrigin = .existing
            case .account, .returningExisting:
                harness.backendUserOrigin = .existing
            case .returningCreated:
                harness.backendUserOrigin = .created
            }
        }

        @MainActor
        func resolve(in model: OnboardingFlowModel) async {
            switch self {
            case .launch:
                await model.bootstrap()
            case .account:
                model.phase = .onboarding(.account)
                await model.authenticate(with: .apple, returning: false)
            case .returningCreated, .returningExisting:
                model.phase = .onboarding(.returningSignIn)
                await model.authenticate(with: .google, returning: true)
            }
        }
    }

    enum PaywallRestoreOutcome: CaseIterable, Sendable {
        case inactive
        case failure

        var expectedMessage: String {
            switch self {
            case .inactive:
                "No active purchases were found for this account."
            case .failure:
                "Restore failed"
            }
        }

        @MainActor
        func configure(_ harness: TestDependencyHarness) {
            switch self {
            case .inactive:
                harness.restoreStatus = .inactive
            case .failure:
                harness.restoreFailure = .access(expectedMessage)
            }
        }
    }

    enum InFlightLookOperation: CaseIterable, Sendable {
        case analysis
        case generation

        @MainActor
        func wasRequestCancelled(by looks: ControlledLooksHarness) -> Bool {
            switch self {
            case .analysis:
                looks.cancelledAnalysisRequests == [0]
                    && looks.cancelledGenerationRequests.isEmpty
            case .generation:
                looks.cancelledGenerationRequests == [0]
                    && looks.cancelledAnalysisRequests.isEmpty
            }
        }
    }

    enum PhotoLifecycleRoute: CaseIterable, Sendable {
        case retake
        case mainEntry
    }

    enum LegacyGateFixture: CaseIterable, Sendable, CustomTestStringConvertible {
        case start
        case photo
        case paywall
        case corrupt
        case unsupported

        var testDescription: String {
            switch self {
            case .start: "start"
            case .photo: "photo"
            case .paywall: "paywall"
            case .corrupt: "corrupt"
            case .unsupported: "unsupported"
            }
        }

        var data: Data {
            switch self {
            case .start, .photo, .paywall:
                Data(#"{"version":1,"gate":"\#(testDescription)"}"#.utf8)
            case .corrupt:
                Data("not-json".utf8)
            case .unsupported:
                Data(#"{"version":99,"gate":"future"}"#.utf8)
            }
        }
    }
}

@MainActor
private final class WeakReference<Value: AnyObject> {
    weak var value: Value?

    init(_ value: Value?) {
        self.value = value
    }
}

@MainActor
private final class FailOnceAccessPurchaseHarness {
    private(set) var events: [String] = []
    private var shouldFailAccess = true
    private var accessContinuation: AsyncStream<AccessStatus>.Continuation?

    func client() -> PurchaseClient {
        PurchaseClient(
            bindUser: { [self] userID in
                events.append("bind:\(userID)")
            },
            currentAccess: { [self] in
                events.append("currentAccess")
                if shouldFailAccess {
                    shouldFailAccess = false
                    throw ServiceFailure.access("Access failed")
                }
                return .active
            },
            purchase: { .active },
            restore: { .active },
            accessUpdates: { [self] in
                events.append("accessUpdates")
                return AsyncStream { accessContinuation = $0 }
            }
        )
    }
}

private actor ControlledPhotoProcessor {
    private var requestedInputs: Set<Data> = []
    private var requestWaiters: [Data: [CheckedContinuation<Void, Never>]] = [:]
    private var completions: [Data: CheckedContinuation<PreparedPhoto, Error>] = [:]

    nonisolated func client() -> PhotoProcessingClient {
        PhotoProcessingClient { [self] data, _ in
            try await prepare(data)
        }
    }

    func waitUntilRequested(_ data: Data) async {
        guard requestedInputs.contains(data) == false else { return }
        await withCheckedContinuation { continuation in
            requestWaiters[data, default: []].append(continuation)
        }
    }

    func succeed(_ photo: PreparedPhoto, for data: Data) {
        completions.removeValue(forKey: data)?.resume(returning: photo)
    }

    private func prepare(_ data: Data) async throws -> PreparedPhoto {
        requestedInputs.insert(data)
        requestWaiters.removeValue(forKey: data)?.forEach { $0.resume() }
        return try await withCheckedThrowingContinuation { continuation in
            completions[data] = continuation
        }
    }
}
