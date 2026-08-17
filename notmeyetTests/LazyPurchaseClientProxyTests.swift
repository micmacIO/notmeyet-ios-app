import Testing
@testable import notmeyet

@Suite("Lazy purchase client proxy")
@MainActor
struct LazyPurchaseClientProxyTests {
    @Test(
        "Live purchase configuration rejects empty and placeholder values before SDK use",
        arguments: [
            (apiKey: "", entitlementID: "pro"),
            (apiKey: "  PLACEHOLDER_REVENUECAT  ", entitlementID: "pro"),
            (apiKey: "revenuecat-key", entitlementID: "  "),
            (apiKey: "revenuecat-key", entitlementID: "placeholder_entitlement")
        ]
    )
    func invalidConfigurationFailsBeforeSDKUse(
        apiKey: String,
        entitlementID: String
    ) {
        #expect(throws: ServiceFailure.self) {
            _ = try LazyPurchaseClientProxy(apiKey: apiKey, entitlementID: entitlementID)
        }
    }

    @Test("Repeated operations create once, reuse one client, and forward every operation")
    func repeatedOperationsReuseClientAndForward() async throws {
        let cache = LazyPurchaseClientProxy.Cache()
        let service = PurchaseClientHarness()
        var configuredStateChecks = 0
        var actions: [LazyPurchaseClientProxy.ConfigurationAction] = []
        var entitlementIDs: [String] = []
        let proxy = LazyPurchaseClientProxy(
            apiKey: "fixture-api-key",
            entitlementID: "fixture-entitlement",
            cache: cache,
            isSDKConfigured: {
                configuredStateChecks += 1
                return false
            },
            factory: { action, entitlementID in
                actions.append(action)
                entitlementIDs.append(entitlementID)
                return .init(client: service.client(), serviceOwner: service)
            }
        )

        let client = proxy.client()
        #expect(actions.isEmpty)

        try await client.bindUser("fixture-user")
        #expect(try await client.currentAccess() == .active)
        #expect(try await client.purchase() == .inactive)
        #expect(try await client.restore() == .active)
        #expect(try await client.currentAccess() == .active)

        let updates = client.accessUpdates()
        service.sendAccessUpdate(.inactive)
        var iterator = updates.makeAsyncIterator()
        #expect(await iterator.next() == .inactive)

        #expect(actions == [.configure(apiKey: "fixture-api-key")])
        #expect(configuredStateChecks == 1)
        #expect(entitlementIDs == ["fixture-entitlement"])
        #expect(service.events == [
            "bind:fixture-user",
            "currentAccess",
            "purchase",
            "restore",
            "currentAccess",
            "accessUpdates"
        ])
    }

    @Test("Two proxies sharing a cache configure only the first")
    func proxiesShareCachedClient() async throws {
        let cache = LazyPurchaseClientProxy.Cache()
        let firstService = PurchaseClientHarness()
        let secondService = PurchaseClientHarness()
        var firstConfiguredStateChecks = 0
        var secondConfiguredStateChecks = 0
        var firstActions: [LazyPurchaseClientProxy.ConfigurationAction] = []
        var secondFactoryCalls = 0
        let firstProxy = LazyPurchaseClientProxy(
            apiKey: "first-api-key",
            entitlementID: "first-entitlement",
            cache: cache,
            isSDKConfigured: {
                firstConfiguredStateChecks += 1
                return false
            },
            factory: { action, _ in
                firstActions.append(action)
                return .init(client: firstService.client(), serviceOwner: firstService)
            }
        )
        let secondProxy = LazyPurchaseClientProxy(
            apiKey: "second-api-key",
            entitlementID: "second-entitlement",
            cache: cache,
            isSDKConfigured: {
                secondConfiguredStateChecks += 1
                return false
            },
            factory: { _, _ in
                secondFactoryCalls += 1
                return .init(client: secondService.client(), serviceOwner: secondService)
            }
        )

        #expect(try await firstProxy.client().currentAccess() == .active)
        #expect(try await secondProxy.client().purchase() == .inactive)

        #expect(firstActions == [.configure(apiKey: "first-api-key")])
        #expect(firstConfiguredStateChecks == 1)
        #expect(secondConfiguredStateChecks == 0)
        #expect(secondFactoryCalls == 0)
        #expect(firstService.events == ["currentAccess", "purchase"])
        #expect(secondService.events.isEmpty)
    }

    @Test("Configured SDK state chooses the no-configure factory path")
    func configuredSDKUsesSharedPath() async throws {
        let cache = LazyPurchaseClientProxy.Cache()
        let service = PurchaseClientHarness()
        var configuredStateChecks = 0
        var actions: [LazyPurchaseClientProxy.ConfigurationAction] = []
        let proxy = LazyPurchaseClientProxy(
            apiKey: "unused-api-key",
            entitlementID: "fixture-entitlement",
            cache: cache,
            isSDKConfigured: {
                configuredStateChecks += 1
                return true
            },
            factory: { action, _ in
                actions.append(action)
                return .init(client: service.client(), serviceOwner: service)
            }
        )

        #expect(try await proxy.client().restore() == .active)

        #expect(configuredStateChecks == 1)
        #expect(actions == [.useConfiguredSDK])
        #expect(service.events == ["restore"])
    }

    @Test("Client retains its delegate service owner while access updates are active")
    func clientRetainsServiceOwner() {
        var cache: LazyPurchaseClientProxy.Cache? = .init()
        var weakOwner: WeakReference<FakeDelegateServiceOwner>?
        let operations = PurchaseClientHarness()
        var proxy: LazyPurchaseClientProxy? = LazyPurchaseClientProxy(
            apiKey: "fixture-api-key",
            entitlementID: "fixture-entitlement",
            cache: cache!,
            isSDKConfigured: { false },
            factory: { _, _ in
                let owner = FakeDelegateServiceOwner()
                weakOwner = WeakReference(owner)
                return .init(client: operations.client(), serviceOwner: owner)
            }
        )
        var client: PurchaseClient? = proxy?.client()
        cache = nil
        proxy = nil

        var updates = client?.accessUpdates()
        #expect(weakOwner?.value != nil)
        #expect(operations.events == ["accessUpdates"])
        withExtendedLifetime(updates) {
            #expect(weakOwner?.value != nil)
        }

        updates = nil
        #expect(weakOwner?.value != nil)
        client = nil
        #expect(weakOwner?.value == nil)
    }
}

@MainActor
private final class PurchaseClientHarness {
    var events: [String] = []
    private var accessContinuation: AsyncStream<AccessStatus>.Continuation?

    func client() -> PurchaseClient {
        PurchaseClient(
            bindUser: { [self] userID in
                events.append("bind:\(userID)")
            },
            currentAccess: { [self] in
                events.append("currentAccess")
                return .active
            },
            purchase: { [self] in
                events.append("purchase")
                return .inactive
            },
            restore: { [self] in
                events.append("restore")
                return .active
            },
            accessUpdates: { [self] in
                events.append("accessUpdates")
                return AsyncStream { continuation in
                    accessContinuation = continuation
                }
            }
        )
    }

    func sendAccessUpdate(_ status: AccessStatus) {
        accessContinuation?.yield(status)
    }
}

@MainActor
private final class FakeDelegateServiceOwner {}

@MainActor
private final class WeakReference<Value: AnyObject> {
    weak var value: Value?

    init(_ value: Value?) {
        self.value = value
    }
}
