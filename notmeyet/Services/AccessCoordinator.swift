import Foundation

@MainActor
final class AccessCoordinator {
    private let purchase: PurchaseClient
    private var evaluationID = UUID()
    private var identityTail: Task<Void, Never>?

    init(purchase: PurchaseClient) {
        self.purchase = purchase
    }

    func bindAndEvaluateAccess(for userID: String) async throws -> AccessEvaluation {
        let currentEvaluationID = UUID()
        evaluationID = currentEvaluationID
        let previous = identityTail
        let operation = Task { @MainActor [purchase] in
            await previous?.value
            try Task.checkCancellation()
            guard evaluationID == currentEvaluationID else { throw CancellationError() }
            try await purchase.bindUser(userID)
            try Task.checkCancellation()
            guard evaluationID == currentEvaluationID else { throw CancellationError() }
            let status = try await purchase.currentAccess()
            try Task.checkCancellation()
            guard evaluationID == currentEvaluationID else { throw CancellationError() }
            return status == .active ? AccessEvaluation.active(userID: userID) : .inactive(userID: userID)
        }
        identityTail = Task { _ = await operation.result }
        return try await withTaskCancellationHandler {
            try await operation.value
        } onCancel: {
            operation.cancel()
        }
    }
}
