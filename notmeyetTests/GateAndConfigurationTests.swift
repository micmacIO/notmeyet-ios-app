import Foundation
import Testing
@testable import notmeyet

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
        #expect(isInvalid(resolve(mode: "live", arguments: ["--mock-entitled"], debug: false)))
        #expect(isInvalid(resolve(mode: "live", arguments: ["--reset-onboarding"], debug: false)))
        #expect(isInvalid(resolve(
            mode: "live",
            arguments: ["--ui-test-presentation=main"],
            debug: false
        )))
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
            termsURL: nil,
            privacyURL: nil,
            facialDataDisclosuresApproved: false,
            backendUserLifecycleContractConfirmed: false
        )
        let dependencies = AppDependencies.make(configuration: configuration)

        #expect(dependencies.authentication.currentUserID() == nil)
        await #expect(throws: ServiceFailure.self) {
            try await dependencies.backendUser.resolveCurrentUser()
        }
        await #expect(throws: ServiceFailure.self) {
            try await dependencies.backendUser.completeOnboarding()
        }
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
        #expect(isInvalid(resolve(mode: "live", googleClientID: "google-client", debug: true)))
        #expect(isInvalid(resolve(mode: "live", googleCallbackSchemes: [], debug: true)))
        #expect(isInvalid(resolve(
            mode: "live",
            googleCallbackSchemes: ["com.googleusercontent.apps.PLACEHOLDER"],
            debug: true
        )))
        #expect(isInvalid(resolve(
            mode: "live",
            googleCallbackSchemes: ["com.googleusercontent.apps.wrong-client"],
            debug: true
        )))
        #expect(isInvalid(resolve(mode: "live", revenueCatAPIKey: " PLACEHOLDER_REVENUECAT ", debug: true)))
        #expect(isInvalid(resolve(mode: "live", entitlementID: "PLACEHOLDER_ENTITLEMENT", debug: true)))
        #expect(isInvalid(resolve(mode: "live", looksURL: URL(string: "https://api.example.com"), debug: true)))
        #expect(isInvalid(resolve(mode: "live", termsURL: URL(string: "https://legal.notmeyet.app/PLACEHOLDER"), debug: true)))
        #expect(isInvalid(resolve(mode: "live", privacyURL: URL(string: "https://privacy.notmeyet.test"), debug: true)))
        #expect(isInvalid(resolve(mode: "live", lifecycleContractConfirmed: false, debug: true)))
    }

    @Test(
        "Injected live configuration validates purchase inputs before constructing services",
        arguments: [
            (apiKey: " placeholder_revenuecat ", entitlementID: "pro"),
            (apiKey: "revenuecat-key", entitlementID: " placeholder_entitlement ")
        ]
    )
    @MainActor
    func injectedInvalidPurchaseConfigurationFailsClosed(
        apiKey: String,
        entitlementID: String
    ) async {
        let configuration = AppConfiguration(
            mode: .live,
            googleClientID: "1234567890-fixture.apps.googleusercontent.com",
            revenueCatAPIKey: apiKey,
            revenueCatEntitlementID: entitlementID,
            looksAPIBaseURL: URL(string: "https://api.notmeyet.app")!,
            termsURL: URL(string: "https://notmeyet.app/terms")!,
            privacyURL: URL(string: "https://notmeyet.app/privacy")!,
            facialDataDisclosuresApproved: true,
            backendUserLifecycleContractConfirmed: true
        )

        let dependencies = AppDependencies.make(configuration: configuration)

        guard case .invalid = dependencies.configuration.mode else {
            Issue.record("Invalid purchase configuration did not fail closed")
            return
        }
        await #expect(throws: ServiceFailure.self) {
            try await dependencies.purchase.currentAccess()
        }
    }

    @Test("Unconfirmed lifecycle configuration fails before any service operation")
    @MainActor
    func unconfirmedLifecycleSkipsServices() async {
        let harness = TestDependencyHarness()
        harness.userID = "configured-user"
        let configuration = AppConfiguration(
            mode: resolve(mode: "live", lifecycleContractConfirmed: false, debug: false),
            googleClientID: "1234567890-fixture.apps.googleusercontent.com",
            revenueCatAPIKey: "revenuecat-key",
            revenueCatEntitlementID: "pro",
            looksAPIBaseURL: URL(string: "https://api.notmeyet.app")!,
            termsURL: URL(string: "https://notmeyet.app/terms")!,
            privacyURL: URL(string: "https://notmeyet.app/privacy")!,
            facialDataDisclosuresApproved: true,
            backendUserLifecycleContractConfirmed: false
        )
        let model = OnboardingFlowModel(
            dependencies: harness.makeDependencies(configuration: configuration)
        )

        await model.bootstrap()

        #expect(harness.backendResolutionRequestCount == 0)
        #expect(harness.completionRequestCount == 0)
        #expect(harness.bindingRequestCount == 0)
        #expect(harness.accessRequestCount == 0)
        guard case .configurationUnavailable = model.phase else {
            Issue.record("Unconfirmed lifecycle configuration did not fail closed")
            return
        }
    }

    @Test("Directly injected live configuration cannot bypass lifecycle confirmation")
    @MainActor
    func injectedUnconfirmedLifecycleFailsClosed() async {
        let configuration = AppConfiguration(
            mode: .live,
            googleClientID: "1234567890-fixture.apps.googleusercontent.com",
            revenueCatAPIKey: "revenuecat-key",
            revenueCatEntitlementID: "pro",
            looksAPIBaseURL: URL(string: "https://api.notmeyet.app")!,
            termsURL: URL(string: "https://notmeyet.app/terms")!,
            privacyURL: URL(string: "https://notmeyet.app/privacy")!,
            facialDataDisclosuresApproved: true,
            backendUserLifecycleContractConfirmed: false
        )

        let dependencies = AppDependencies.make(configuration: configuration)

        guard case .invalid = dependencies.configuration.mode else {
            Issue.record("Injected unconfirmed lifecycle configuration did not fail closed")
            return
        }
        await #expect(throws: ServiceFailure.self) {
            try await dependencies.backendUser.resolveCurrentUser()
        }
        await #expect(throws: ServiceFailure.self) {
            try await dependencies.backendUser.completeOnboarding()
        }
        await #expect(throws: ServiceFailure.self) {
            try await dependencies.purchase.currentAccess()
        }
    }

    @MainActor
    private func resolve(
        mode: String,
        arguments: [String] = [],
        googleClientID: String = "1234567890-fixture.apps.googleusercontent.com",
        googleCallbackSchemes: [String] = ["com.googleusercontent.apps.1234567890-fixture"],
        revenueCatAPIKey: String = "revenuecat-key",
        entitlementID: String = "pro",
        looksURL: URL? = URL(string: "https://api.notmeyet.app"),
        termsURL: URL? = URL(string: "https://notmeyet.app/terms"),
        privacyURL: URL? = URL(string: "https://notmeyet.app/privacy"),
        lifecycleContractConfirmed: Bool = true,
        debug: Bool
    ) -> ServiceMode {
        AppConfiguration.resolveMode(
            requestedMode: mode,
            arguments: arguments,
            googleClientID: googleClientID,
            googleCallbackSchemes: googleCallbackSchemes,
            revenueCatAPIKey: revenueCatAPIKey,
            entitlementID: entitlementID,
            looksURL: looksURL,
            termsURL: termsURL,
            privacyURL: privacyURL,
            disclosuresApproved: true,
            lifecycleContractConfirmed: lifecycleContractConfirmed,
            hasFirebaseConfiguration: true,
            isDebugBuild: debug
        )
    }

    private func isInvalid(_ mode: ServiceMode) -> Bool {
        if case .invalid = mode { return true }
        return false
    }
}
