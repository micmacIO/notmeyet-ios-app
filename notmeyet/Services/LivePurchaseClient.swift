import Foundation
import RevenueCat

@MainActor
final class LivePurchaseService: NSObject, PurchasesDelegate {
    private let entitlementID: String
    private var accessContinuation: AsyncStream<AccessStatus>.Continuation?

    init(apiKey: String, entitlementID: String) {
        self.entitlementID = entitlementID
        super.init()
        Purchases.configure(withAPIKey: apiKey)
        Purchases.shared.delegate = self
    }

    func client() -> PurchaseClient {
        PurchaseClient(
            bindUser: { userID in
                _ = try await Purchases.shared.logIn(userID)
            },
            currentAccess: { [self] in
                status(from: try await Purchases.shared.customerInfo())
            },
            purchase: { [self] in
                status(from: try await Purchases.shared.customerInfo())
            },
            restore: { [self] in
                status(from: try await Purchases.shared.restorePurchases())
            },
            accessUpdates: { [self] in updates() }
        )
    }

    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        accessContinuation?.yield(status(from: customerInfo))
    }

    private func updates() -> AsyncStream<AccessStatus> {
        return AsyncStream { continuation in
            accessContinuation = continuation
        }
    }

    private func status(from customerInfo: CustomerInfo) -> AccessStatus {
        customerInfo.entitlements[entitlementID]?.isActive == true ? .active : .inactive
    }
}
