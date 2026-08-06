import XCTest

@MainActor
final class OnboardingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        await MainActor.run {
            app?.terminate()
            app = nil
        }
    }

    func testNewUserCanSkipToHardPaywallAndPurchase() {
        launchResetApp()
        advanceEmptyQuestionnairesToPhotoPreparation()

        tap("photo.skipHarmony")
        assertHardPaywall()
        tap("paywall.purchase")

        XCTAssertTrue(element("main.skeleton").waitForExistence(timeout: 3))
    }

    func testPaywallGatePersistsAcrossRelaunch() {
        launchResetApp()
        advanceEmptyQuestionnairesToPhotoPreparation()
        tap("photo.skipHarmony")
        assertHardPaywall()

        app.terminate()
        app.launchArguments = ["--mock-services"]
        app.launch()

        assertHardPaywall()
    }

    func testReturningUserWithActiveEntitlementRoutesToMain() {
        launchResetApp(arguments: ["--mock-entitled"])

        tap("welcome.signIn")
        XCTAssertTrue(app.buttons["auth.google"].waitForExistence(timeout: 2))
        tap("auth.google")

        XCTAssertTrue(element("main.skeleton").waitForExistence(timeout: 3))
    }

    func testReturningUserWithoutEntitlementRoutesToHardPaywall() {
        launchResetApp()

        tap("welcome.signIn")
        tap("auth.apple")

        assertHardPaywall()
    }

    func testWelcomeRoutingSurvivesBackgroundAndReturn() {
        launchResetApp()
        assertHeading("See who you could be.")

        let discover = app.buttons["welcome.discover"]
        let signIn = app.buttons["welcome.signIn"]
        XCTAssertEqual(discover.label, "Discover my next look")
        XCTAssertEqual(signIn.label, "Already have an account? Sign in")

        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 3))
        assertHeading("See who you could be.")
        XCTAssertTrue(discover.exists)

        tap("welcome.signIn")
        assertHeading("Welcome back")
        tap("navigation.back")
        assertHeading("See who you could be.")
    }

    func testChoicesClearAndRemainSelectedThroughBackNavigation() {
        launchResetApp()
        assertHeading("See who you could be.")
        tap("welcome.discover")
        assertHeading("What brought you here today?")

        let goal = app.buttons["goal.confidence"]
        let secondGoal = app.buttons["goal.suitableHaircut"]
        XCTAssertTrue(goal.waitForExistence(timeout: 2))
        XCTAssertFalse(goal.isSelected)
        XCTAssertFalse(secondGoal.isSelected)
        goal.tap()
        XCTAssertTrue(goal.isSelected)
        secondGoal.tap()
        XCTAssertFalse(goal.isSelected)
        XCTAssertTrue(secondGoal.isSelected)
        secondGoal.tap()
        XCTAssertFalse(secondGoal.isSelected)
        tap("goal.continue")
        assertHeading("What makes changing your look difficult?")

        let firstPain = app.buttons["pain.unknownFit"]
        let secondPain = app.buttons["pain.barberLanguage"]
        XCTAssertFalse(firstPain.isSelected)
        XCTAssertFalse(secondPain.isSelected)
        firstPain.tap()
        secondPain.tap()
        XCTAssertTrue(firstPain.isSelected)
        XCTAssertTrue(secondPain.isSelected)
        tap("pain.continue")
        assertHeading("How different should your next look feel?")
        tap("navigation.back")

        XCTAssertTrue(firstPain.isSelected)
        XCTAssertTrue(secondPain.isSelected)
        firstPain.tap()
        XCTAssertFalse(firstPain.isSelected)
        XCTAssertTrue(secondPain.isSelected)
        secondPain.tap()
        XCTAssertFalse(secondPain.isSelected)
        tap("pain.continue")
        assertHeading("How different should your next look feel?")

        let direction = app.buttons["direction.noticeable"]
        XCTAssertFalse(direction.isSelected)
        XCTAssertTrue(direction.label.contains("Noticeable"))
        XCTAssertTrue(direction.label.contains("Clearly different, but still easy to wear"))
        direction.tap()
        XCTAssertTrue(direction.isSelected)
        direction.tap()
        XCTAssertFalse(direction.isSelected)
        tap("direction.continue")
        assertHeading("Continue to your free harmony check")
    }

    func testAuthenticatedPaywallGateLaunchesDirectly() {
        launchApp(
            arguments: ["--mock-services", "--reset-onboarding", "--mock-authenticated", "--mock-gate=paywall"],
            expectedIdentifier: "paywall.purchase"
        )

        assertHardPaywall()
    }

    func testProductionPaywallShellHasNoAppOwnedDismissal() {
        launchApp(
            arguments: ["--mock-services", "--reset-onboarding", "--ui-test-presentation=12-production-shell"],
            expectedIdentifier: "paywall.production.fixture"
        )

        assertHeading("Meet more versions of you")
        assertNoAppOwnedPaywallDismissal()
        XCTAssertTrue(element("paywall.production.fixture").exists)
    }

    func testFixturePhotoCompletesPreviewAndPurchaseFlow() {
        launchResetApp(arguments: ["--mock-photo-fixture"])
        advanceEmptyQuestionnairesToPhotoPreparation()
        advanceFixturePhotoToHarmony()

        tap("harmony.showStyle")
        let comparison = element("result.comparison")
        XCTAssertTrue(comparison.waitForExistence(timeout: 6))
        assertGeneratedLookResult()
        XCTAssertEqual(comparison.label, "Before and after hairstyle comparison")
        let initialValue = comparison.value as? String
        XCTAssertTrue(initialValue?.contains("46") == true)

        let slider = app.sliders["result.slider"]
        XCTAssertTrue(slider.exists)
        XCTAssertEqual(slider.label, "Compare before and after")
        slider.adjust(toNormalizedSliderPosition: 0.5)
        waitForValue(toDifferFrom: initialValue, in: comparison)
        let adjustedValue = comparison.value as? String
        XCTAssertNotEqual(adjustedValue, initialValue)
        XCTAssertEqual(adjustedValue, slider.value as? String)
        let adjustedPercentage = adjustedValue
            .flatMap { $0.split(separator: " ").first }
            .flatMap { Int($0) }
        XCTAssertNotNil(adjustedPercentage)
        if let adjustedPercentage {
            XCTAssertTrue((12...88).contains(adjustedPercentage))
        }

        tap("result.tryMore")
        assertHardPaywall()
        tap("paywall.purchase")
        XCTAssertTrue(element("main.skeleton").waitForExistence(timeout: 5))
    }

    func testHarmonySkipPersistsPaywallGate() {
        launchResetApp(arguments: ["--mock-photo-fixture"])
        advanceEmptyQuestionnairesToPhotoPreparation()
        advanceFixturePhotoToHarmony()

        tap("harmony.skipLook")
        assertHardPaywall()

        app.terminate()
        app.launchArguments = ["--mock-services"]
        app.launch()
        assertHardPaywall()
    }

    func testRetakeClearsPhotoReviewAndReturnsToPreparation() {
        launchResetApp(arguments: ["--mock-photo-fixture"])
        advanceEmptyQuestionnairesToPhotoPreparation()

        tap("photo.fixture")
        XCTAssertTrue(element("photo.review.image").waitForExistence(timeout: 5))
        tap("photo.retake")

        XCTAssertTrue(app.buttons["photo.fixture"].waitForExistence(timeout: 5))
        XCTAssertFalse(element("photo.review.image").exists)
        XCTAssertFalse(app.buttons["photo.use"].exists)
    }

    func testAnalysisFailureRetriesSuccessfully() {
        launchResetApp(arguments: ["--mock-photo-fixture", "--mock-analysis-fail-once"])
        advanceEmptyQuestionnairesToPhotoPreparation()
        tap("photo.fixture")
        tap("photo.use")

        tap("error.retry", timeout: 6)
        XCTAssertTrue(app.buttons["harmony.showStyle"].waitForExistence(timeout: 6))
    }

    func testGenerationFailureRetriesSuccessfully() {
        launchResetApp(arguments: ["--mock-photo-fixture", "--mock-generation-fail-once"])
        advanceEmptyQuestionnairesToPhotoPreparation()
        advanceFixturePhotoToHarmony()
        tap("harmony.showStyle")

        tap("error.retry", timeout: 6)
        XCTAssertTrue(app.sliders["result.slider"].waitForExistence(timeout: 6))
        assertGeneratedLookResult()
    }

    func testGeneratedImageFailureRetriesSuccessfully() {
        launchResetApp(arguments: ["--mock-photo-fixture", "--mock-image-fail-once"])
        advanceEmptyQuestionnairesToPhotoPreparation()
        advanceFixturePhotoToHarmony()
        tap("harmony.showStyle")

        tap("error.retry", timeout: 6)
        XCTAssertTrue(app.sliders["result.slider"].waitForExistence(timeout: 6))
        assertGeneratedLookResult()
    }

    private func launchResetApp(arguments: [String] = []) {
        launchApp(
            arguments: ["--mock-services", "--reset-onboarding"] + arguments,
            expectedIdentifier: "welcome.discover"
        )
    }

    private func launchApp(arguments: [String], expectedIdentifier: String) {
        app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(
            element(expectedIdentifier).waitForExistence(timeout: 6),
            app.debugDescription
        )
    }

    private func advanceEmptyQuestionnairesToPhotoPreparation() {
        tap("welcome.discover")
        assertHeading("What brought you here today?")
        tap("goal.continue")
        assertHeading("What makes changing your look difficult?")
        tap("pain.continue")
        assertHeading("How different should your next look feel?")
        tap("direction.continue")
        assertHeading("Continue to your free harmony check")
        tap("auth.apple")
        XCTAssertTrue(app.buttons["photo.skipHarmony"].waitForExistence(timeout: 3))
        assertHeading("Let's find what works with your features.")
    }

    private func advanceFixturePhotoToHarmony() {
        tap("photo.fixture")
        XCTAssertTrue(element("photo.review.image").waitForExistence(timeout: 5))
        assertHeading("Use this photo?")
        tap("photo.use")
        XCTAssertTrue(app.buttons["harmony.showStyle"].waitForExistence(timeout: 6))
        assertHeading("Here's what works in harmony")
        let annotatedImage = element("harmony.annotatedImage")
        XCTAssertTrue(annotatedImage.exists)
        XCTAssertEqual(annotatedImage.label, "Annotated facial harmony image")

        let faceShape = element("harmony.faceShape")
        XCTAssertTrue(faceShape.exists)
        XCTAssertTrue(faceShape.label.contains("Oval"))

        let harmonyScore = element("harmony.score")
        XCTAssertTrue(harmonyScore.exists)
        XCTAssertEqual(harmonyScore.label, "Overall harmony")
        XCTAssertEqual(harmonyScore.value as? String, "88.6 out of 100")
    }

    private func assertGeneratedLookResult() {
        let styleName = element("result.styleName")
        XCTAssertTrue(styleName.waitForExistence(timeout: 2))
        XCTAssertEqual(styleName.label, "Textured crop")
        XCTAssertEqual(element("result.aboutHeading").label, "About this look")
        XCTAssertEqual(
            element("result.styleDescription").label,
            "A short, textured style with clean sides and natural movement on top."
        )
        XCTAssertFalse(app.buttons["error.retry"].exists)
        XCTAssertFalse(app.progressIndicators["Processing"].exists)
        XCTAssertFalse(app.staticTexts["Loading your first look."].exists)
    }

    private func assertHardPaywall() {
        XCTAssertTrue(app.buttons["paywall.purchase"].waitForExistence(timeout: 5))
        assertHeading("Meet more versions of you")
        XCTAssertEqual(app.buttons["paywall.purchase"].label, "Unlock more looks")
        XCTAssertEqual(app.buttons["paywall.restore"].label, "Restore purchases")
        assertNoAppOwnedPaywallDismissal()
        XCTAssertTrue(app.buttons["paywall.restore"].exists)
    }

    private func assertNoAppOwnedPaywallDismissal() {
        XCTAssertFalse(app.buttons["navigation.back"].exists)
        for label in ["Back", "Close", "Dismiss", "Not now"] {
            XCTAssertFalse(app.buttons[label].exists, "Unexpected paywall dismissal control: \(label)")
        }
        XCTAssertFalse(app.sheets.firstMatch.exists)
    }

    private func assertHeading(_ expectedLabel: String, timeout: TimeInterval = 2) {
        let heading = element("screen.heading")
        let predicate = NSPredicate { object, _ in
            guard let heading = object as? XCUIElement else { return false }
            return heading.exists && heading.label == expectedLabel
        }
        let result = XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: predicate, object: heading)],
            timeout: timeout
        )
        XCTAssertEqual(result, .completed, "Missing heading: \(expectedLabel)")
    }

    private func tap(_ identifier: String, timeout: TimeInterval = 5) {
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "Missing button: \(identifier)")
        button.tap()
    }

    private func waitForValue(toDifferFrom originalValue: String?, in element: XCUIElement) {
        let predicate = NSPredicate { object, _ in
            guard let element = object as? XCUIElement, let value = element.value as? String else {
                return false
            }
            return value != originalValue
        }
        let result = XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: predicate, object: element)],
            timeout: 3
        )
        XCTAssertEqual(result, .completed)
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
