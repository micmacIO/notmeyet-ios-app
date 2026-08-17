import Foundation
import RevenueCat

@MainActor
final class LazyPurchaseClientProxy {
    enum ConfigurationAction: Equatable {
        case configure(apiKey: String)
        case useConfiguredSDK
    }

    struct CachedClient {
        let client: PurchaseClient
        let serviceOwner: AnyObject
    }

    @MainActor
    final class Cache {
        fileprivate var cachedClient: CachedClient?

        init() {}
    }

    typealias Factory = @MainActor (ConfigurationAction, String) -> CachedClient

    private static let sharedCache = Cache()

    private let apiKey: String
    private let entitlementID: String
    private let cache: Cache
    private let isSDKConfigured: @MainActor () -> Bool
    private let factory: Factory

    init(apiKey: String, entitlementID: String) throws {
        self.apiKey = try Self.validatedConfigurationValue(
            apiKey,
            name: "RevenueCat API key"
        )
        self.entitlementID = try Self.validatedConfigurationValue(
            entitlementID,
            name: "RevenueCat entitlement"
        )
        self.cache = Self.sharedCache
        self.isSDKConfigured = { Purchases.isConfigured }
        self.factory = { action, entitlementID in
            let purchases: Purchases
            switch action {
            case .configure(let apiKey):
                purchases = Purchases.configure(withAPIKey: apiKey)
            case .useConfiguredSDK:
                purchases = Purchases.shared
            }

            let service = LivePurchaseService(
                purchases: purchases,
                entitlementID: entitlementID
            )
            return CachedClient(client: service.client(), serviceOwner: service)
        }
    }

    init(
        apiKey: String,
        entitlementID: String,
        cache: Cache,
        isSDKConfigured: @escaping @MainActor () -> Bool,
        factory: @escaping Factory
    ) {
        self.apiKey = apiKey
        self.entitlementID = entitlementID
        self.cache = cache
        self.isSDKConfigured = isSDKConfigured
        self.factory = factory
    }

    func client() -> PurchaseClient {
        PurchaseClient(
            bindUser: { [self] userID in
                try await resolvedClient().bindUser(userID)
            },
            currentAccess: { [self] in
                try await resolvedClient().currentAccess()
            },
            purchase: { [self] in
                try await resolvedClient().purchase()
            },
            restore: { [self] in
                try await resolvedClient().restore()
            },
            accessUpdates: { [self] in
                resolvedClient().accessUpdates()
            }
        )
    }

    private func resolvedClient() -> PurchaseClient {
        if let cachedClient = cache.cachedClient {
            return cachedClient.client
        }

        let action: ConfigurationAction = isSDKConfigured()
            ? .useConfiguredSDK
            : .configure(apiKey: apiKey)
        let cachedClient = factory(action, entitlementID)
        cache.cachedClient = cachedClient
        return cachedClient.client
    }

    private static func validatedConfigurationValue(
        _ value: String,
        name: String
    ) throws -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false,
              normalized.uppercased().contains("PLACEHOLDER") == false else {
            throw ServiceFailure.configuration("Live configuration is incomplete: \(name).")
        }
        return normalized
    }
}

@MainActor
final class LivePurchaseService: NSObject, PurchasesDelegate {
    private let purchases: Purchases
    private let entitlementID: String
    private var accessContinuations: [UUID: AsyncStream<AccessStatus>.Continuation] = [:]

    init(purchases: Purchases, entitlementID: String) {
        self.purchases = purchases
        self.entitlementID = entitlementID
        super.init()
        purchases.delegate = self
    }

    func client() -> PurchaseClient {
        PurchaseClient(
            bindUser: { [purchases] userID in
                _ = try await purchases.logIn(userID)
            },
            currentAccess: { [self] in
                status(from: try await purchases.customerInfo())
            },
            purchase: { [self] in
                status(from: try await purchases.customerInfo())
            },
            restore: { [self] in
                status(from: try await purchases.restorePurchases())
            },
            accessUpdates: { [self] in updates() }
        )
    }

    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        let status = status(from: customerInfo)
        accessContinuations.values.forEach { $0.yield(status) }
    }

    private func updates() -> AsyncStream<AccessStatus> {
        let id = UUID()
        let serviceReference = WeakPurchaseServiceReference(self)
        return AsyncStream { continuation in
            accessContinuations[id] = continuation
            continuation.onTermination = { _ in
                Task { @MainActor in
                    serviceReference.value?.accessContinuations.removeValue(forKey: id)
                }
            }
        }
    }

    private func status(from customerInfo: CustomerInfo) -> AccessStatus {
        customerInfo.entitlements[entitlementID]?.isActive == true ? .active : .inactive
    }
}

private final class WeakPurchaseServiceReference: @unchecked Sendable {
    weak var value: LivePurchaseService?

    init(_ value: LivePurchaseService) {
        self.value = value
    }
}
