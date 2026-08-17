import XCTest

@MainActor
final class VisualVerificationUITests: XCTestCase {
    private struct Scenario {
        let name: String
        let presentation: String
        let readinessIdentifier: String
        let heading: String?
        let readinessLabel: String?

        init(
            name: String,
            presentation: String,
            readinessIdentifier: String,
            heading: String?,
            readinessLabel: String? = nil
        ) {
            self.name = name
            self.presentation = presentation
            self.readinessIdentifier = readinessIdentifier
            self.heading = heading
            self.readinessLabel = readinessLabel
        }
    }

    private let scenarios = [
        Scenario(name: "screen-01", presentation: "01", readinessIdentifier: "welcome.discover", heading: "See who you could be."),
        Scenario(name: "screen-02", presentation: "02", readinessIdentifier: "goal.continue", heading: "What brought you here today?"),
        Scenario(name: "screen-03", presentation: "03", readinessIdentifier: "pain.continue", heading: "What makes changing your look difficult?"),
        Scenario(name: "screen-04", presentation: "04", readinessIdentifier: "direction.continue", heading: "How different should your next look feel?"),
        Scenario(name: "screen-05", presentation: "05", readinessIdentifier: "auth.apple", heading: "Continue to your free harmony check"),
        Scenario(name: "screen-05-backend-resolving", presentation: "05-backend-resolving", readinessIdentifier: "auth.progress", heading: "Continue to your free harmony check"),
        Scenario(name: "screen-06", presentation: "06", readinessIdentifier: "photo.skipHarmony", heading: "Let's find what works with your features."),
        Scenario(name: "screen-06-completion-progress", presentation: "06-completion-progress", readinessIdentifier: "completion.progress", heading: "Let's find what works with your features."),
        Scenario(name: "screen-07", presentation: "07", readinessIdentifier: "photo.review.image", heading: "Use this photo?"),
        Scenario(name: "screen-08-loading", presentation: "08-loading", readinessIdentifier: "screen.heading", heading: "Finding your natural harmony..."),
        Scenario(name: "screen-08-error", presentation: "08-error", readinessIdentifier: "error.panel", heading: "Finding your natural harmony..."),
        Scenario(name: "screen-09", presentation: "09", readinessIdentifier: "harmony.showStyle", heading: "Here's what works in harmony"),
        Scenario(name: "screen-09-completion-progress", presentation: "09-completion-progress", readinessIdentifier: "completion.progress", heading: "Here's what works in harmony"),
        Scenario(name: "screen-10-loading", presentation: "10-loading", readinessIdentifier: "screen.heading", heading: "Creating your first NotMeYet look..."),
        Scenario(name: "screen-10-error", presentation: "10-error", readinessIdentifier: "error.panel", heading: "Creating your first NotMeYet look..."),
        Scenario(name: "screen-11-success", presentation: "11-success", readinessIdentifier: "result.comparison", heading: "Not you yet - but should it be?"),
        Scenario(name: "screen-11-completion-progress", presentation: "11-completion-progress", readinessIdentifier: "completion.progress", heading: "Not you yet - but should it be?"),
        Scenario(name: "screen-12-mock", presentation: "12-mock", readinessIdentifier: "paywall.purchase", heading: "Meet more versions of you"),
        Scenario(name: "screen-13", presentation: "13", readinessIdentifier: "returning.startOnboarding", heading: "Welcome back"),
        Scenario(name: "screen-13-created-incomplete", presentation: "13-created-incomplete", readinessIdentifier: "returning.incompleteNotice", heading: "Welcome back"),
        Scenario(name: "access-pending-progress", presentation: "access-pending-progress", readinessIdentifier: "access.progress", heading: "Checking your access"),
        Scenario(name: "access-failure", presentation: "access-failure", readinessIdentifier: "error.panel", heading: "Checking your access"),
        Scenario(name: "main-skeleton", presentation: "main", readinessIdentifier: "main.skeleton", heading: nil)
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureDeterministicVisualStates() {
        for scenario in scenarios {
            let app = XCUIApplication()
            app.launchArguments = [
                "--mock-services",
                "--reset-onboarding",
                "--ui-test-presentation=\(scenario.presentation)"
            ]
            app.launch()

            let ready = app.descendants(matching: .any)[scenario.readinessIdentifier]
            XCTAssertTrue(
                ready.waitForExistence(timeout: 6),
                "Presentation did not become ready: \(scenario.name)\n\(app.debugDescription)"
            )
            if let readinessLabel = scenario.readinessLabel {
                XCTAssertEqual(ready.label, readinessLabel)
            }
            if let heading = scenario.heading {
                assertHeading(heading, in: app)
            }

            let window = app.windows.firstMatch
            XCTAssertTrue(window.exists)
            let viewport = "\(Int(window.frame.width.rounded()))x\(Int(window.frame.height.rounded()))"
            XCTAssertTrue(
                ["390x844", "393x852", "402x874", "430x932"].contains(viewport),
                "Unexpected visual-verification viewport: \(viewport)"
            )

            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = "native__\(scenario.name)__\(viewport)__ios-26.2"
            attachment.lifetime = .keepAlways
            add(attachment)

            app.terminate()
        }
    }

    func testLifecycleActionsRemainReachableAtAccessibilityTextSize() {
        let scenarios = [
            (name: "screen-05", presentation: "05", ready: "auth.apple", action: "auth.google"),
            (name: "screen-06", presentation: "06", ready: "photo.skipHarmony", action: "photo.camera"),
            (name: "screen-09", presentation: "09", ready: "harmony.showStyle", action: "harmony.showStyle"),
            (name: "screen-11", presentation: "11-success", ready: "result.comparison", action: "result.tryMore"),
            (name: "screen-13", presentation: "13-created-incomplete", ready: "returning.incompleteNotice", action: "returning.startOnboarding"),
            (name: "access-failure", presentation: "access-failure", ready: "error.panel", action: "error.retry")
        ]

        for scenario in scenarios {
            let app = launch(presentation: scenario.presentation, ready: scenario.ready)
            let action = app.descendants(matching: .any)[scenario.action]

            scrollUntilVisible(action, in: app)
            XCTAssertTrue(action.isEnabled, "Action is disabled: \(scenario.action)")
            XCTAssertTrue(action.isHittable, "Action is not reachable: \(scenario.action)")
            attachScreenshot(named: "dynamic-type-action__\(scenario.name)")
            app.terminate()
        }
    }

    func testCompletionProgressActionsRemainVisibleAndDisabledAtAccessibilityTextSize() {
        let scenarios = [
            (name: "screen-06-progress", presentation: "06-completion-progress", action: "photo.camera"),
            (name: "screen-09-progress", presentation: "09-completion-progress", action: "harmony.showStyle"),
            (name: "screen-11-progress", presentation: "11-completion-progress", action: "result.tryMore")
        ]

        for scenario in scenarios {
            let app = launch(presentation: scenario.presentation, ready: "completion.progress")
            let action = app.descendants(matching: .any)[scenario.action]

            scrollUntilVisible(action, in: app)
            XCTAssertFalse(action.isEnabled, "Completion action remained enabled: \(scenario.action)")
            attachScreenshot(named: "dynamic-type-disabled-action__\(scenario.name)")
            app.terminate()
        }
    }

    private func assertHeading(_ expectedLabel: String, in app: XCUIApplication) {
        let heading = app.descendants(matching: .any)["screen.heading"]
        let predicate = NSPredicate { object, _ in
            guard let heading = object as? XCUIElement else { return false }
            return heading.exists && heading.label == expectedLabel
        }
        let result = XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: predicate, object: heading)],
            timeout: 3
        )
        XCTAssertEqual(result, .completed, "Missing heading: \(expectedLabel)")
    }

    private func launch(presentation: String, ready readinessIdentifier: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--mock-services",
            "--reset-onboarding",
            "--ui-test-presentation=\(presentation)",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()
        XCTAssertTrue(
            app.descendants(matching: .any)[readinessIdentifier].waitForExistence(timeout: 6),
            "Presentation did not become ready: \(presentation)\n\(app.debugDescription)"
        )
        return app
    }

    private func scrollUntilVisible(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 3), "Missing element: \(element)")
        let viewport = app.windows.firstMatch.frame
        for _ in 0..<10 where !element.frame.intersects(viewport) || element.frame.isEmpty {
            app.swipeUp()
        }
        XCTAssertTrue(
            element.frame.intersects(viewport) && !element.frame.isEmpty,
            "Element did not scroll into the viewport: \(element)"
        )
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
