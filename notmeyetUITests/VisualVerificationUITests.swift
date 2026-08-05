import XCTest

@MainActor
final class VisualVerificationUITests: XCTestCase {
    private struct Scenario {
        let name: String
        let presentation: String
        let readinessIdentifier: String
        let heading: String?
    }

    private let scenarios = [
        Scenario(name: "screen-01", presentation: "01", readinessIdentifier: "welcome.discover", heading: "See who you could be."),
        Scenario(name: "screen-02", presentation: "02", readinessIdentifier: "goal.continue", heading: "What brought you here today?"),
        Scenario(name: "screen-03", presentation: "03", readinessIdentifier: "pain.continue", heading: "What makes changing your look difficult?"),
        Scenario(name: "screen-04", presentation: "04", readinessIdentifier: "direction.continue", heading: "How different should your next look feel?"),
        Scenario(name: "screen-05", presentation: "05", readinessIdentifier: "auth.apple", heading: "Continue to your free harmony check"),
        Scenario(name: "screen-06", presentation: "06", readinessIdentifier: "photo.skipHarmony", heading: "Let's find what works with your features."),
        Scenario(name: "screen-07", presentation: "07", readinessIdentifier: "photo.review.image", heading: "Use this photo?"),
        Scenario(name: "screen-08-loading", presentation: "08-loading", readinessIdentifier: "screen.heading", heading: "Finding your natural harmony..."),
        Scenario(name: "screen-08-error", presentation: "08-error", readinessIdentifier: "error.panel", heading: "Finding your natural harmony..."),
        Scenario(name: "screen-09", presentation: "09", readinessIdentifier: "harmony.showStyle", heading: "Here's what works in harmony"),
        Scenario(name: "screen-10-loading", presentation: "10-loading", readinessIdentifier: "screen.heading", heading: "Creating your first NotMeYet look..."),
        Scenario(name: "screen-10-error", presentation: "10-error", readinessIdentifier: "error.panel", heading: "Creating your first NotMeYet look..."),
        Scenario(name: "screen-11-loading", presentation: "11-loading", readinessIdentifier: "result.loading", heading: "Not you yet - but should it be?"),
        Scenario(name: "screen-11-error", presentation: "11-error", readinessIdentifier: "error.panel", heading: "Not you yet - but should it be?"),
        Scenario(name: "screen-11-success", presentation: "11-success", readinessIdentifier: "result.comparison", heading: "Not you yet - but should it be?"),
        Scenario(name: "screen-12-mock", presentation: "12-mock", readinessIdentifier: "paywall.purchase", heading: "Meet more versions of you"),
        Scenario(name: "screen-13", presentation: "13", readinessIdentifier: "returning.startOnboarding", heading: "Welcome back"),
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
            if let heading = scenario.heading {
                assertHeading(heading, in: app)
            }

            let window = app.windows.firstMatch
            XCTAssertTrue(window.exists)
            let viewport = "\(Int(window.frame.width.rounded()))x\(Int(window.frame.height.rounded()))"
            XCTAssertTrue(
                ["390x844", "393x852", "430x932"].contains(viewport),
                "Unexpected visual-verification viewport: \(viewport)"
            )

            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = "native__\(scenario.name)__\(viewport)__ios-26.2"
            attachment.lifetime = .keepAlways
            add(attachment)

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
}
