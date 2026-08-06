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

        model.generationPhase = .loaded(Self.look(name: "Ready", path: "ready"))
        #expect(model.accessibilityAnnouncement?.message == "Your look is ready.")

        model.phase = .configurationUnavailable("Configuration failed")
        #expect(model.accessibilityAnnouncement?.message == "Configuration failed")
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

    @Test("Bootstrap routes signed-out, active, and gated inactive users")
    @MainActor
    func bootstrapRoutes() async {
        let signedOutHarness = TestDependencyHarness()
        let signedOut = OnboardingFlowModel(dependencies: signedOutHarness.makeDependencies())
        await signedOut.bootstrap()
        #expect(signedOut.phase == .onboarding(.welcome))

        let activeHarness = TestDependencyHarness()
        activeHarness.userID = "active-user"
        activeHarness.accessStatus = .active
        let active = OnboardingFlowModel(dependencies: activeHarness.makeDependencies())
        await active.bootstrap()
        #expect(active.phase == .main)

        for (gate, expectedStep) in [
            (RoutingGate.start, OnboardingStep.welcome),
            (.photo, .photoPreparation),
            (.paywall, .paywall)
        ] {
            let harness = TestDependencyHarness()
            harness.userID = "inactive-user"
            harness.accessStatus = .inactive
            harness.gates["inactive-user"] = gate
            let model = OnboardingFlowModel(dependencies: harness.makeDependencies())
            await model.bootstrap()
            #expect(model.phase == .onboarding(expectedStep))
        }
    }

    @Test("New-user authentication binds identity, writes photo gate, and always enters screen 06")
    @MainActor
    func newUserAuthentication() async {
        let harness = TestDependencyHarness()
        harness.accessStatus = .active
        let model = OnboardingFlowModel(dependencies: harness.makeDependencies())
        model.phase = .onboarding(.account)

        await model.authenticate(with: .apple, returning: false)

        #expect(model.phase == .onboarding(.photoPreparation))
        #expect(harness.gates["test-user"] == .photo)
        #expect(harness.events == ["signIn:apple", "bind:test-user", "setGate:photo:test-user"])
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
        #expect(harness.events == [
            "signIn:google", "signIn:google", "bind:test-user", "setGate:photo:test-user"
        ])
    }

    @Test("Identity-binding retry does not repeat provider authentication")
    @MainActor
    func bindingFailureRetriesOnlyBinding() async {
        let harness = TestDependencyHarness()
        harness.bindingFailure = .identityBinding("Binding failed")
        let model = OnboardingFlowModel(dependencies: harness.makeDependencies())
        model.phase = .onboarding(.account)

        await model.authenticate(with: .apple, returning: false)
        #expect(model.phase == .onboarding(.account))
        #expect(model.authenticationError == "Binding failed")

        harness.bindingFailure = nil
        await model.retryAuthentication()

        #expect(model.phase == .onboarding(.photoPreparation))
        #expect(harness.events == [
            "signIn:apple", "bind:test-user", "bind:test-user", "setGate:photo:test-user"
        ])
    }

    @Test("Provider cancellation leaves screen 05 unchanged without an error or gate write")
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
        #expect(harness.gates.isEmpty)
    }

    @Test("Leaving screen 05 prevents a late identity binding from routing or writing a gate")
    @MainActor
    func backInvalidatesPendingIdentityBinding() async {
        let purchase = ControlledPurchaseHarness()
        defer { purchase.cancelOutstandingRequests() }
        let harness = TestDependencyHarness()
        let model = OnboardingFlowModel(
            dependencies: harness.makeDependencies(purchase: purchase.client())
        )
        model.phase = .onboarding(.account)

        let authentication = Task {
            await model.authenticate(with: .google, returning: false)
        }
        await purchase.waitForBindingRequests(1)
        #expect(model.isAuthenticating)

        model.goBack()
        #expect(model.phase == .onboarding(.direction))
        purchase.succeedBindingRequest(0)
        await authentication.value

        #expect(model.phase == .onboarding(.direction))
        #expect(model.isAuthenticating == false)
        #expect(harness.gates.isEmpty)
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

    @Test("Returning users route only from refreshed entitlement state")
    @MainActor
    func returningUserAuthentication() async {
        let activeHarness = TestDependencyHarness()
        activeHarness.accessStatus = .active
        let activeModel = OnboardingFlowModel(dependencies: activeHarness.makeDependencies())
        activeModel.phase = .onboarding(.returningSignIn)
        await activeModel.authenticate(with: .google, returning: true)
        #expect(activeModel.phase == .main)
        #expect(activeHarness.events == ["signIn:google", "bind:test-user", "currentAccess"])

        let inactiveHarness = TestDependencyHarness()
        inactiveHarness.accessStatus = .inactive
        let inactiveModel = OnboardingFlowModel(dependencies: inactiveHarness.makeDependencies())
        inactiveModel.phase = .onboarding(.returningSignIn)
        await inactiveModel.authenticate(with: .apple, returning: true)
        #expect(inactiveModel.phase == .onboarding(.paywall))
        #expect(inactiveHarness.gates["test-user"] == .paywall)
    }

    @Test("Returning-user access failure retries binding without repeating provider sign-in")
    @MainActor
    func returningAccessFailureRetriesBinding() async {
        let harness = TestDependencyHarness()
        harness.accessFailure = .access("Access failed")
        let model = OnboardingFlowModel(dependencies: harness.makeDependencies())
        model.phase = .onboarding(.returningSignIn)

        await model.authenticate(with: .google, returning: true)
        #expect(model.phase == .onboarding(.returningSignIn))
        #expect(model.authenticationError == "Access failed")

        harness.accessFailure = nil
        harness.accessStatus = .active
        await model.retryAuthentication()

        #expect(model.phase == .main)
        #expect(model.authenticationError == nil)
        #expect(harness.events == [
            "signIn:google", "bind:test-user", "currentAccess",
            "bind:test-user", "currentAccess"
        ])
    }

    @Test("Returning-user Back and start-onboarding actions return to Welcome")
    @MainActor
    func returningNavigationReturnsToWelcome() {
        let model = OnboardingFlowModel(dependencies: TestDependencyHarness().makeDependencies())

        model.phase = .onboarding(.returningSignIn)
        model.goBack()
        #expect(model.phase == .onboarding(.welcome))

        model.showReturningSignIn()
        model.goBack()
        #expect(model.phase == .onboarding(.welcome))
    }

    @Test("Hard paywall remains locked until active access is returned")
    @MainActor
    func hardPaywallAuthorization() async {
        let harness = TestDependencyHarness()
        harness.userID = "test-user"
        harness.accessStatus = .inactive
        harness.gates["test-user"] = .photo
        let model = OnboardingFlowModel(dependencies: harness.makeDependencies())
        await model.bootstrap()

        model.skipHarmonyCheck()
        #expect(model.phase == .onboarding(.paywall))
        #expect(harness.gates["test-user"] == .paywall)
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

    @Test("An active purchase result cannot authorize Main outside the hard paywall")
    @MainActor
    func purchaseCannotBypassPaywallRoute() async {
        let harness = TestDependencyHarness()
        harness.userID = "test-user"
        harness.accessStatus = .inactive
        harness.purchaseStatus = .active
        let model = OnboardingFlowModel(dependencies: harness.makeDependencies())
        await model.bootstrap()
        #expect(model.phase == .onboarding(.welcome))

        await model.purchase()

        #expect(model.phase == .onboarding(.welcome))
        #expect(harness.events.contains("purchase") == false)
    }

    @Test(
        "Every post-photo paywall entry clears the exact photo lifecycle",
        arguments: PaywallEntryRoute.allCases
    )
    @MainActor
    func paywallGateWritesFromEveryEntry(_ route: PaywallEntryRoute) async {
        let looks = ControlledLooksHarness()
        let harness = TestDependencyHarness()
        harness.userID = "test-user"
        harness.accessStatus = .inactive
        harness.gates["test-user"] = .photo
        let model = OnboardingFlowModel(
            dependencies: harness.makeDependencies(looks: looks.client())
        )
        await model.bootstrap()
        let photo = Self.photo(byte: 1)
        Self.populatePhotoDerivedContent(in: model, photo: photo)

        switch route {
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

        #expect(model.phase == .onboarding(.paywall))
        #expect(harness.gates["test-user"] == .paywall)
        Self.expectPhotoDerivedContentCleared(in: model)
        #expect(await eventually { looks.clearedPhotoIDs == [photo.id] })
    }

    @Test("Skip invalidates an in-flight photo preparation")
    @MainActor
    func skipInvalidatesPhotoPreparation() async {
        let processor = ControlledPhotoProcessor()
        let harness = TestDependencyHarness()
        harness.userID = "test-user"
        harness.accessStatus = .inactive
        harness.gates["test-user"] = .photo
        let model = OnboardingFlowModel(
            dependencies: harness.makeDependencies(photoProcessing: processor.client())
        )
        await model.bootstrap()
        let input = Data([1])
        let preparation = Task { await model.preparePhoto(data: input) }
        await processor.waitUntilRequested(input)

        model.skipHarmonyCheck()
        await processor.succeed(Self.photo(byte: 1), for: input)
        await preparation.value

        #expect(model.phase == .onboarding(.paywall))
        #expect(model.draft.preparedPhoto == nil)
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

    @Test("Termination-style model replacement restores only the photo routing gate")
    @MainActor
    func terminationDoesNotRestorePhotoContent() async {
        let harness = TestDependencyHarness()
        harness.userID = "test-user"
        harness.accessStatus = .inactive
        harness.gates["test-user"] = .photo
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

    @Test("Corrupt persisted gate is cleared and bootstrap falls back to Welcome")
    @MainActor
    func corruptGateBootstrapFallsBackToWelcome() async {
        let suiteName = "OnboardingFlowModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let userID = "corrupt-user"
        let key = "notmeyet.onboarding.gate.\(Data(userID.utf8).base64EncodedString())"
        defaults.set(Data("not-json".utf8), forKey: key)
        let store = OnboardingGateStore(defaults: defaults)
        let harness = TestDependencyHarness()
        harness.userID = userID
        harness.accessStatus = .inactive
        let model = OnboardingFlowModel(
            dependencies: harness.makeDependencies(routingGate: store.client())
        )

        await model.bootstrap()

        #expect(model.phase == .onboarding(.welcome))
        #expect(defaults.object(forKey: key) == nil)
    }

    @Test("Bootstrap binding and entitlement failures fail closed and can recover")
    @MainActor
    func bootstrapFailuresFailClosedAndRetry() async {
        let bindingHarness = TestDependencyHarness()
        bindingHarness.userID = "binding-user"
        bindingHarness.bindingFailure = .identityBinding("Binding failed")
        let bindingModel = OnboardingFlowModel(dependencies: bindingHarness.makeDependencies())

        await bindingModel.bootstrap()
        #expect(bindingModel.phase == .configurationUnavailable("Binding failed"))

        bindingHarness.bindingFailure = nil
        bindingHarness.gates["binding-user"] = .photo
        await bindingModel.retryBootstrap()
        #expect(bindingModel.phase == .onboarding(.photoPreparation))

        let accessHarness = TestDependencyHarness()
        accessHarness.userID = "access-user"
        accessHarness.accessFailure = .access("Access failed")
        let accessModel = OnboardingFlowModel(dependencies: accessHarness.makeDependencies())

        await accessModel.bootstrap()
        #expect(accessModel.phase == .configurationUnavailable("Access failed"))
        #expect(accessModel.phase != .main)
    }

    @Test(
        "Retake, Main entry, and bootstrap reset clear the exact photo lifecycle",
        arguments: PhotoLifecycleRoute.allCases
    )
    @MainActor
    func photoLifecycleCleanup(_ route: PhotoLifecycleRoute) async {
        let looks = ControlledLooksHarness()
        let harness = TestDependencyHarness()
        if route == .mainEntry {
            harness.userID = "test-user"
            harness.accessStatus = .inactive
            harness.purchaseStatus = .active
            harness.gates["test-user"] = .paywall
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
        case .bootstrapReset:
            model.phase = .onboarding(.firstResult)
            await model.bootstrap()
            #expect(model.phase == .onboarding(.welcome))
        }

        Self.expectPhotoDerivedContentCleared(in: model)
        #expect(await eventually { looks.clearedPhotoIDs == [photo.id] })
    }

    @Test("Long-lived access updates do not retain the flow model")
    @MainActor
    func accessMonitoringDoesNotRetainModel() async {
        let harness = TestDependencyHarness()
        harness.userID = "test-user"
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
        harness.accessStatus = .active
        let model = OnboardingFlowModel(dependencies: harness.makeDependencies())
        await model.bootstrap()
        #expect(model.phase == .main)
        let monitoringStarted = await eventually { harness.isMonitoringAccess }
        #expect(monitoringStarted)

        harness.sendAccessUpdate(.inactive)

        let reachedPaywall = await eventually { model.phase == .onboarding(.paywall) }
        #expect(reachedPaywall)
        #expect(harness.gates["test-user"] == .paywall)
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
        case bootstrapReset
    }
}

@MainActor
private final class WeakReference<Value: AnyObject> {
    weak var value: Value?

    init(_ value: Value?) {
        self.value = value
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
