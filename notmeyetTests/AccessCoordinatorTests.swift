import Testing
@testable import notmeyet

@Suite("Access coordination")
struct AccessCoordinatorTests {
    @Test("Firebase UID binding precedes active entitlement evaluation")
    @MainActor
    func activeAccessOrdering() async throws {
        let harness = TestDependencyHarness()
        harness.accessStatus = .active
        let dependencies = harness.makeDependencies()
        let coordinator = AccessCoordinator(
            purchase: dependencies.purchase
        )

        #expect(try await coordinator.bindAndEvaluateAccess(for: "active-user") == .active(userID: "active-user"))
        #expect(harness.events == ["bind:active-user", "currentAccess"])
    }

    @Test("Inactive entitlement remains unauthorized")
    @MainActor
    func inactiveAccess() async throws {
        let harness = TestDependencyHarness()
        harness.accessStatus = .inactive
        let dependencies = harness.makeDependencies()
        let coordinator = AccessCoordinator(
            purchase: dependencies.purchase
        )

        #expect(try await coordinator.bindAndEvaluateAccess(for: "inactive-user") == .inactive(userID: "inactive-user"))
        #expect(harness.events == ["bind:inactive-user", "currentAccess"])
    }

    @Test("Binding failure prevents entitlement refresh")
    @MainActor
    func bindingFailureStopsEvaluation() async {
        let harness = TestDependencyHarness()
        harness.bindingFailure = .identityBinding("Binding failed")
        let dependencies = harness.makeDependencies()
        let coordinator = AccessCoordinator(
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
        let harness = ControlledPurchaseHarness()
        defer { harness.cancelOutstandingRequests() }
        let coordinator = AccessCoordinator(
            purchase: harness.client()
        )

        let cancelled = Task { try await coordinator.bindAndEvaluateAccess(for: "cancelled-user") }
        await harness.waitForBindingRequests(1)
        cancelled.cancel()
        #expect(await eventually { harness.cancelledBindingRequests == [0] })
        harness.succeedBindingRequest(0)

        await #expect(throws: CancellationError.self) { try await cancelled.value }
        #expect(harness.accessRequestCount == 0)

        let recovery = Task { try await coordinator.bindAndEvaluateAccess(for: "recovery-user") }
        await harness.waitForBindingRequests(2)
        harness.succeedBindingRequest(1)
        await harness.waitForAccessRequests(1)
        harness.succeedAccessRequest(0, with: .active)
        #expect(try await recovery.value == .active(userID: "recovery-user"))
    }

    @Test("Caller cancellation during access refresh is propagated")
    @MainActor
    func cancellationDuringAccessRefresh() async {
        let harness = ControlledPurchaseHarness()
        defer { harness.cancelOutstandingRequests() }
        let coordinator = AccessCoordinator(purchase: harness.client())

        let evaluation = Task { try await coordinator.bindAndEvaluateAccess(for: "test-user") }
        await harness.waitForBindingRequests(1)
        harness.succeedBindingRequest(0)
        await harness.waitForAccessRequests(1)

        evaluation.cancel()
        #expect(await eventually { harness.cancelledAccessRequests == [0] })
        harness.succeedAccessRequest(0, with: .active)

        await #expect(throws: CancellationError.self) { try await evaluation.value }
    }

    @Test("Overlapping UID evaluations serialize binding and discard the stale result")
    @MainActor
    func overlappingEvaluationsAreSerialized() async throws {
        let log = ControlledOperationLog()
        let harness = ControlledPurchaseHarness(log: log)
        defer { harness.cancelOutstandingRequests() }
        let coordinator = AccessCoordinator(
            purchase: harness.client()
        )

        let first = Task { try await coordinator.bindAndEvaluateAccess(for: "first-user") }
        await harness.waitForBindingRequests(1)
        harness.succeedBindingRequest(0)
        await harness.waitForAccessRequests(1)

        var secondStarted = false
        let second = Task {
            secondStarted = true
            return try await coordinator.bindAndEvaluateAccess(for: "second-user")
        }
        #expect(await eventually { secondStarted })
        #expect(harness.bindingRequests == ["first-user"])

        harness.succeedAccessRequest(0, with: .active)
        await harness.waitForBindingRequests(2)
        harness.succeedBindingRequest(1)
        await harness.waitForAccessRequests(2)
        harness.succeedAccessRequest(1, with: .active)

        #expect(try await second.value == .active(userID: "second-user"))
        await #expect(throws: CancellationError.self) { try await first.value }
        #expect(log.events == [
            "bind:first-user", "currentAccess",
            "bind:second-user", "currentAccess"
        ])
    }
}
