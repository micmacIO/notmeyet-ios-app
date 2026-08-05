#if DEBUG
import Foundation
import Testing
@testable import notmeyet

@Suite("Mock service outcomes")
struct MockServiceStateTests {
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
        let generated = try await looks.generateLook(photo, nil)
        let image = fixture.state.generatedImageClient()
        await #expect(throws: ServiceFailure.self) { try await image.load(generated.imageURL) }
        #expect(try await image.load(generated.imageURL).isEmpty == false)
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
#endif
