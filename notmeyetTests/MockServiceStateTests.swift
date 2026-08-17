#if DEBUG
import Foundation
import Testing
@testable import notmeyet

@Suite("Mock service outcomes")
struct MockServiceStateTests {
    @Test("Authentication, backend lifecycle, and entitlement remain independent")
    @MainActor
    func independentLifecycleState() async throws {
        let fixture = makeState(arguments: ["--mock-entitled"])
        defer { fixture.defaults.removePersistentDomain(forName: fixture.name) }
        let authentication = fixture.state.authenticationClient()
        let backend = fixture.state.backendUserClient()
        let purchase = fixture.state.purchaseClient()

        #expect(authentication.currentUserID() == nil)
        #expect(try await purchase.currentAccess() == .active)
        #expect(try await backend.resolveCurrentUser() == BackendUserResolution(
            origin: .created,
            onboardingCompleted: false
        ))
        #expect(try await backend.resolveCurrentUser() == BackendUserResolution(
            origin: .existing,
            onboardingCompleted: false
        ))

        try await backend.completeOnboarding()

        #expect(try await backend.resolveCurrentUser() == BackendUserResolution(
            origin: .existing,
            onboardingCompleted: true
        ))
        #expect(authentication.currentUserID() == nil)
        #expect(try await purchase.currentAccess() == .active)
    }

    @Test("Reset clears identity and backend lifecycle without deriving either from entitlement")
    @MainActor
    func resetLifecycleState() async throws {
        let name = "MockServiceStateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.set("persisted-user", forKey: "notmeyet.mock.userID")
        defaults.set(true, forKey: "notmeyet.mock.backendUserExists")
        defaults.set(true, forKey: "notmeyet.mock.onboardingCompleted")
        defer { defaults.removePersistentDomain(forName: name) }
        let state = MockServiceState(
            defaults: defaults,
            arguments: ["--reset-onboarding", "--mock-entitled"]
        )

        #expect(state.authenticationClient().currentUserID() == nil)
        #expect(try await state.purchaseClient().currentAccess() == .active)
        #expect(try await state.backendUserClient().resolveCurrentUser() == BackendUserResolution(
            origin: .created,
            onboardingCompleted: false
        ))
    }

    @Test("Backend lifecycle selectors expose every deterministic resolution outcome")
    @MainActor
    func backendLifecycleOutcomes() async throws {
        for testCase in MockBackendLifecycleCase.allCases {
            let fixture = makeState(arguments: testCase.arguments)
            defer { fixture.defaults.removePersistentDomain(forName: fixture.name) }
            let backend = fixture.state.backendUserClient()

            if let resolution = testCase.expectedResolution {
                #expect(try await backend.resolveCurrentUser() == resolution)
            } else {
                await #expect(throws: testCase.expectedFailure) {
                    try await backend.resolveCurrentUser()
                }
            }
        }

        let completionFailure = makeState(arguments: ["--mock-completion-failure"])
        defer { completionFailure.defaults.removePersistentDomain(forName: completionFailure.name) }
        await #expect(throws: ServiceFailure.transport(
            "We couldn't finish setting up your account. Try again."
        )) {
            try await completionFailure.state.backendUserClient().completeOnboarding()
        }
    }

    @Test("Fail-once access selection recovers on the next access-only attempt")
    @MainActor
    func failOnceAccessRecovers() async throws {
        let fixture = makeState(arguments: ["--mock-access-fail-once"])
        defer { fixture.defaults.removePersistentDomain(forName: fixture.name) }
        let purchase = fixture.state.purchaseClient()

        await #expect(throws: ServiceFailure.self) {
            try await purchase.currentAccess()
        }
        #expect(try await purchase.currentAccess() == .inactive)
    }

    @Test("Purchase clients expose every deterministic identity and access outcome")
    @MainActor
    func purchaseOutcomes() async throws {
        let active = makeState(arguments: [])
        defer { active.defaults.removePersistentDomain(forName: active.name) }
        let activeClient = active.state.purchaseClient()
        try await activeClient.bindUser("bound-user")
        #expect(active.state.boundUserID == "bound-user")
        #expect(try await activeClient.currentAccess() == .inactive)
        #expect(try await activeClient.purchase() == .active)
        #expect(try await activeClient.restore() == .active)

        let inactive = makeState(arguments: ["--mock-purchase-inactive", "--mock-restore-inactive"])
        defer { inactive.defaults.removePersistentDomain(forName: inactive.name) }
        #expect(try await inactive.state.purchaseClient().purchase() == .inactive)
        #expect(try await inactive.state.purchaseClient().restore() == .inactive)

        let cancellation = makeState(arguments: ["--mock-purchase-cancel", "--mock-restore-cancel"])
        defer { cancellation.defaults.removePersistentDomain(forName: cancellation.name) }
        await #expect(throws: ServiceFailure.cancelled) {
            try await cancellation.state.purchaseClient().purchase()
        }
        await #expect(throws: ServiceFailure.cancelled) {
            try await cancellation.state.purchaseClient().restore()
        }

        let failures = makeState(arguments: [
            "--mock-binding-failure", "--mock-access-failure",
            "--mock-purchase-failure", "--mock-restore-failure"
        ])
        defer { failures.defaults.removePersistentDomain(forName: failures.name) }
        let failureClient = failures.state.purchaseClient()
        await #expect(throws: ServiceFailure.self) { try await failureClient.bindUser("user") }
        await #expect(throws: ServiceFailure.self) { try await failureClient.currentAccess() }
        await #expect(throws: ServiceFailure.self) { try await failureClient.purchase() }
        await #expect(throws: ServiceFailure.self) { try await failureClient.restore() }

        let revocation = makeState(arguments: ["--mock-entitled", "--mock-revoke-after-launch"])
        defer { revocation.defaults.removePersistentDomain(forName: revocation.name) }
        var updates = revocation.state.purchaseClient().accessUpdates().makeAsyncIterator()
        #expect(await updates.next() == .inactive)
    }

    @Test("Looks failures can be consumed once and then recover")
    @MainActor
    func recoverableLooksOutcomes() async throws {
        let fixture = makeState(arguments: [
            "--mock-analysis-fail-once", "--mock-generation-fail-once", "--mock-image-fail-once"
        ])
        defer { fixture.defaults.removePersistentDomain(forName: fixture.name) }
        let photo = PreparedPhoto(
            displayData: Data([1]),
            uploadData: Data([2]),
            pixelWidth: 10,
            pixelHeight: 12
        )
        let looks = fixture.state.looksClient()

        await #expect(throws: ServiceFailure.self) { try await looks.analyze(photo) }
        _ = try await looks.analyze(photo)
        await #expect(throws: ServiceFailure.self) { try await looks.generateLook(photo, nil) }
        await #expect(throws: ServiceFailure.self) { try await looks.generateLook(photo, nil) }
        #expect(try await looks.generateLook(photo, nil).imageData.isEmpty == false)
    }

    @MainActor
    private func makeState(arguments: [String]) -> (
        state: MockServiceState,
        defaults: UserDefaults,
        name: String
    ) {
        let name = "MockServiceStateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (MockServiceState(defaults: defaults, arguments: arguments), defaults, name)
    }
}

private enum MockBackendLifecycleCase: CaseIterable {
    case createdIncomplete
    case existingIncomplete
    case existingComplete
    case invalid
    case failure

    var arguments: [String] {
        switch self {
        case .createdIncomplete: []
        case .existingIncomplete: ["--mock-backend-existing-incomplete"]
        case .existingComplete: ["--mock-backend-existing-complete"]
        case .invalid: ["--mock-backend-invalid"]
        case .failure: ["--mock-backend-resolution-failure"]
        }
    }

    var expectedResolution: BackendUserResolution? {
        switch self {
        case .createdIncomplete:
            BackendUserResolution(origin: .created, onboardingCompleted: false)
        case .existingIncomplete:
            BackendUserResolution(origin: .existing, onboardingCompleted: false)
        case .existingComplete:
            BackendUserResolution(origin: .existing, onboardingCompleted: true)
        case .invalid, .failure:
            nil
        }
    }

    var expectedFailure: ServiceFailure {
        switch self {
        case .invalid:
            .transport("The account service returned an unusable response. Try again.")
        case .failure:
            .transport("We couldn't check your account. Try again.")
        case .createdIncomplete, .existingIncomplete, .existingComplete:
            .transport("Unexpected successful fixture")
        }
    }
}
#endif
