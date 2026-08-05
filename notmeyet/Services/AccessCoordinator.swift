import Foundation

@MainActor
final class AccessCoordinator {
    private let authentication: AuthenticationClient
    private let purchase: PurchaseClient
    private var evaluationID = UUID()
    private var identityTail: Task<Void, Never>?

    init(authentication: AuthenticationClient, purchase: PurchaseClient) {
        self.authentication = authentication
        self.purchase = purchase
    }

    func evaluateCurrentAccess() async throws -> AccessEvaluation {
        guard let userID = authentication.currentUserID() else { return .signedOut }
        return try await bindAndEvaluateAccess(for: userID)
    }

    func bindUser(_ userID: String) async throws {
        evaluationID = UUID()
        let previous = identityTail
        let operation = Task { @MainActor [purchase] in
            await previous?.value
            try Task.checkCancellation()
            try await purchase.bindUser(userID)
            try Task.checkCancellation()
        }
        identityTail = Task { _ = await operation.result }
        try await withTaskCancellationHandler {
            try await operation.value
        } onCancel: {
            operation.cancel()
        }
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

    func evaluateBoundAccess(for userID: String) async throws -> AccessEvaluation {
        await identityTail?.value
        try Task.checkCancellation()
        let status = try await purchase.currentAccess()
        return status == .active ? .active(userID: userID) : .inactive(userID: userID)
    }
}
