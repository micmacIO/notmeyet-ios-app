import Testing
@testable import notmeyet

@Suite("Access coordination")
struct AccessCoordinatorTests {
    @Test("A signed-out launch performs no purchase work")
    @MainActor
    func signedOutLaunch() async throws {
        let harness = TestDependencyHarness()
        let dependencies = harness.makeDependencies()
        let coordinator = AccessCoordinator(
            authentication: dependencies.authentication,
            purchase: dependencies.purchase
        )

        #expect(try await coordinator.evaluateCurrentAccess() == .signedOut)
        #expect(harness.events.isEmpty)
    }

    @Test("Firebase UID binding precedes active entitlement evaluation")
    @MainActor
    func activeAccessOrdering() async throws {
        let harness = TestDependencyHarness()
        harness.userID = "active-user"
        harness.accessStatus = .active
        let dependencies = harness.makeDependencies()
        let coordinator = AccessCoordinator(
            authentication: dependencies.authentication,
            purchase: dependencies.purchase
        )

        #expect(try await coordinator.evaluateCurrentAccess() == .active(userID: "active-user"))
        #expect(harness.events == ["bind:active-user", "currentAccess"])
    }

    @Test("Inactive entitlement remains unauthorized")
    @MainActor
    func inactiveAccess() async throws {
        let harness = TestDependencyHarness()
        harness.userID = "inactive-user"
        harness.accessStatus = .inactive
        let dependencies = harness.makeDependencies()
        let coordinator = AccessCoordinator(
            authentication: dependencies.authentication,
            purchase: dependencies.purchase
        )

        #expect(try await coordinator.evaluateCurrentAccess() == .inactive(userID: "inactive-user"))
        #expect(harness.events == ["bind:inactive-user", "currentAccess"])
    }

    @Test("Binding failure prevents entitlement refresh")
    @MainActor
    func bindingFailureStopsEvaluation() async {
        let harness = TestDependencyHarness()
        harness.bindingFailure = .identityBinding("Binding failed")
        let dependencies = harness.makeDependencies()
        let coordinator = AccessCoordinator(
            authentication: dependencies.authentication,
            purchase: dependencies.purchase
        )

        await #expect(throws: ServiceFailure.identityBinding("Binding failed")) {
            try await coordinator.bindAndEvaluateAccess(for: "test-user")
        }
        #expect(harness.events == ["bind:test-user"])
    }

    @Test("Entitlement refresh failure is propagated after identity binding")
    @MainActor
    func entitlementFailureStopsEvaluation() async {
        let harness = TestDependencyHarness()
        harness.accessFailure = .access("Access failed")
        let dependencies = harness.makeDependencies()
        let coordinator = AccessCoordinator(
            authentication: dependencies.authentication,
            purchase: dependencies.purchase
        )

        await #expect(throws: ServiceFailure.access("Access failed")) {
            try await coordinator.bindAndEvaluateAccess(for: "test-user")
        }
        #expect(harness.events == ["bind:test-user", "currentAccess"])
    }

    @Test("Caller cancellation stops access evaluation and leaves the identity queue usable")
    @MainActor
    func cancellationStopsEvaluation() async throws {
        let harness = ControlledBindingHarness()
        let coordinator = AccessCoordinator(
            authentication: AuthenticationClient(
                currentUserID: { nil },
                signIn: { _ in "unused" },
                handleOpenURL: { _ in false }
            ),
            purchase: harness.client()
        )

        let cancelled = Task { try await coordinator.bindAndEvaluateAccess(for: "cancelled-user") }
        #expect(await eventually { harness.startedBindings == ["cancelled-user"] })
        cancelled.cancel()
        harness.completeBinding(for: "cancelled-user")

        await #expect(throws: CancellationError.self) { try await cancelled.value }
        #expect(harness.accessEvaluations.isEmpty)

        let recovery = Task { try await coordinator.bindAndEvaluateAccess(for: "recovery-user") }
        #expect(await eventually {
            harness.startedBindings == ["cancelled-user", "recovery-user"]
        })
        harness.completeBinding(for: "recovery-user")
        #expect(try await recovery.value == .active(userID: "recovery-user"))
    }

    @Test("Overlapping UID evaluations serialize binding and discard the stale result")
    @MainActor
    func overlappingEvaluationsAreSerialized() async throws {
        let harness = ControlledBindingHarness()
        let coordinator = AccessCoordinator(
            authentication: AuthenticationClient(
                currentUserID: { nil },
                signIn: { _ in "unused" },
                handleOpenURL: { _ in false }
            ),
            purchase: harness.client()
        )

        let first = Task { try await coordinator.bindAndEvaluateAccess(for: "first-user") }
        #expect(await eventually { harness.startedBindings == ["first-user"] })

        let second = Task { try await coordinator.bindAndEvaluateAccess(for: "second-user") }
        for _ in 0..<20 { await Task.yield() }
        #expect(harness.startedBindings == ["first-user"])

        harness.completeBinding(for: "first-user")
        #expect(await eventually { harness.startedBindings == ["first-user", "second-user"] })
        harness.completeBinding(for: "second-user")

        #expect(try await second.value == .active(userID: "second-user"))
        await #expect(throws: CancellationError.self) { try await first.value }
        #expect(harness.accessEvaluations == ["second-user"])
    }
}

@MainActor
private final class ControlledBindingHarness {
    var startedBindings: [String] = []
    var accessEvaluations: [String] = []
    private var boundUserID: String?
    private var continuations: [String: CheckedContinuation<Void, Error>] = [:]

    func client() -> PurchaseClient {
        PurchaseClient(
            bindUser: { [self] userID in
                startedBindings.append(userID)
                try await withCheckedThrowingContinuation { continuation in
                    continuations[userID] = continuation
                }
                boundUserID = userID
            },
            currentAccess: { [self] in
                accessEvaluations.append(boundUserID ?? "unbound")
                return .active
            },
            purchase: { .inactive },
            restore: { .inactive },
            accessUpdates: { AsyncStream { $0.finish() } }
        )
    }

    func completeBinding(for userID: String) {
        continuations.removeValue(forKey: userID)?.resume()
    }
}
