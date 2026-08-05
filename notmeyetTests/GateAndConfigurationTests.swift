import Foundation
import Testing
@testable import notmeyet

@Suite("Routing gates")
struct RoutingGateTests {
    @Test("Gates round-trip independently per Firebase UID")
    @MainActor
    func gatesRoundTripPerAccount() {
        let fixture = makeDefaults()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.name) }
        let store = OnboardingGateStore(defaults: fixture.defaults)

        store.setGate(.photo, for: "first-user")
        store.setGate(.paywall, for: "second-user")

        #expect(store.gate(for: "first-user") == .photo)
        #expect(store.gate(for: "second-user") == .paywall)
        #expect(store.gate(for: "unknown-user") == .start)
    }

    @Test("Corrupt and unsupported gates fail to start and are cleared")
    @MainActor
    func invalidGatesFailToStart() throws {
        let fixture = makeDefaults()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.name) }
        let store = OnboardingGateStore(defaults: fixture.defaults)

        let corruptKey = key(for: "corrupt-user")
        fixture.defaults.set(Data("not-json".utf8), forKey: corruptKey)
        #expect(store.gate(for: "corrupt-user") == .start)
        #expect(fixture.defaults.object(forKey: corruptKey) == nil)

        let futureKey = key(for: "future-user")
        let futureData = try JSONSerialization.data(withJSONObject: ["version": 2, "gate": "paywall"])
        fixture.defaults.set(futureData, forKey: futureKey)
        #expect(store.gate(for: "future-user") == .start)
        #expect(fixture.defaults.object(forKey: futureKey) == nil)
    }

    @MainActor
    private func makeDefaults() -> (defaults: UserDefaults, name: String) {
        let name = "RoutingGateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (defaults, name)
    }

    private func key(for userID: String) -> String {
        "notmeyet.onboarding.gate.\(Data(userID.utf8).base64EncodedString())"
    }
}

@Suite("App configuration")
struct AppConfigurationTests {
    @Test("Explicit Debug mock mode is accepted")
    @MainActor
    func debugMockMode() {
        #expect(resolve(mode: " mock ", debug: true) == .mock)
        #expect(resolve(mode: "live", arguments: ["--mock-services"], debug: true) == .mock)
    }

    @Test("Release rejects every mock selector")
    @MainActor
    func releaseRejectsMockSelectors() {
        #expect(isInvalid(resolve(mode: "mock", debug: false)))
        #expect(isInvalid(resolve(mode: "live", arguments: ["--mock-services"], debug: false)))
        #expect(isInvalid(resolve(
            mode: "live",
            arguments: ["--mock-services", "--ui-test-presentation=main"],
            debug: false
        )))
        #expect(resolve(mode: "live", arguments: ["--mock-entitled"], debug: false) == .live)
        #expect(resolve(mode: "live", arguments: ["--ui-test-presentation=main"], debug: false) == .live)
    }

    @Test("Release cannot construct access-granting clients from injected mock configuration")
    @MainActor
    func releaseCannotConstructMockClients() async {
        #if !DEBUG
        let configuration = AppConfiguration(
            mode: .mock,
            googleClientID: "",
            revenueCatAPIKey: "",
            revenueCatEntitlementID: "pro",
            looksAPIBaseURL: nil,
            looksAuthToken: "",
            termsURL: nil,
            privacyURL: nil,
            facialDataDisclosuresApproved: false
        )
        let dependencies = AppDependencies.make(configuration: configuration)

        #expect(dependencies.authentication.currentUserID() == nil)
        await #expect(throws: ServiceFailure.self) {
            try await dependencies.purchase.currentAccess()
        }
        #endif
    }

    @Test("Complete live configuration is accepted")
    @MainActor
    func validLiveMode() {
        #expect(resolve(mode: " LIVE ", debug: false) == .live)
    }

    @Test("Unknown modes and placeholder values fail closed")
    @MainActor
    func invalidLiveMode() {
        #expect(isInvalid(resolve(mode: "automatic", debug: true)))
        #expect(isInvalid(resolve(mode: "live", googleClientID: " placeholder_google ", debug: true)))
        #expect(isInvalid(resolve(mode: "live", entitlementID: "PLACEHOLDER_ENTITLEMENT", debug: true)))
    }

    @MainActor
    private func resolve(
        mode: String,
        arguments: [String] = [],
        googleClientID: String = "google-client",
        entitlementID: String = "pro",
        debug: Bool
    ) -> ServiceMode {
        AppConfiguration.resolveMode(
            requestedMode: mode,
            arguments: arguments,
            googleClientID: googleClientID,
            revenueCatAPIKey: "revenuecat-key",
            entitlementID: entitlementID,
            looksURL: URL(string: "https://api.example.com")!,
            looksAuthToken: "looks-token",
            termsURL: URL(string: "https://example.com/terms")!,
            privacyURL: URL(string: "https://example.com/privacy")!,
            disclosuresApproved: true,
            hasFirebaseConfiguration: true,
            isDebugBuild: debug
        )
    }

    private func isInvalid(_ mode: ServiceMode) -> Bool {
        if case .invalid = mode { return true }
        return false
    }
}
