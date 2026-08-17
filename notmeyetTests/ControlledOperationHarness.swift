import Foundation
@testable import notmeyet

@MainActor
final class ControlledOperationLog {
    private(set) var events: [String] = []

    func record(_ event: String) {
        events.append(event)
    }
}

@MainActor
final class ControlledBackendUserHarness {
    private(set) var resolutionRequestCount = 0
    private(set) var completionRequestCount = 0
    private(set) var cancelledResolutionRequests: Set<Int> = []
    private(set) var cancelledCompletionRequests: Set<Int> = []

    private let log: ControlledOperationLog
    private var resolutionContinuations: [Int: CheckedContinuation<BackendUserResolution, Error>] = [:]
    private var completionContinuations: [Int: CheckedContinuation<Void, Error>] = [:]
    private var resolutionWaiters: [Int: [CheckedContinuation<Void, Never>]] = [:]
    private var completionWaiters: [Int: [CheckedContinuation<Void, Never>]] = [:]

    init(log: ControlledOperationLog? = nil) {
        self.log = log ?? ControlledOperationLog()
    }

    func client() -> BackendUserClient {
        BackendUserClient(
            resolveCurrentUser: { [self] in try await beginResolution() },
            completeOnboarding: { [self] in try await beginCompletion() }
        )
    }

    func waitForResolutionRequests(_ count: Int) async {
        guard resolutionRequestCount < count else { return }
        await withCheckedContinuation { resolutionWaiters[count, default: []].append($0) }
    }

    func waitForCompletionRequests(_ count: Int) async {
        guard completionRequestCount < count else { return }
        await withCheckedContinuation { completionWaiters[count, default: []].append($0) }
    }

    func succeedResolutionRequest(_ index: Int, with resolution: BackendUserResolution) {
        resolutionContinuations.removeValue(forKey: index)?.resume(returning: resolution)
    }

    func failResolutionRequest(_ index: Int, with error: Error) {
        resolutionContinuations.removeValue(forKey: index)?.resume(throwing: error)
    }

    func succeedCompletionRequest(_ index: Int) {
        completionContinuations.removeValue(forKey: index)?.resume()
    }

    func failCompletionRequest(_ index: Int, with error: Error) {
        completionContinuations.removeValue(forKey: index)?.resume(throwing: error)
    }

    func cancelOutstandingRequests() {
        resolutionContinuations.values.forEach { $0.resume(throwing: CancellationError()) }
        completionContinuations.values.forEach { $0.resume(throwing: CancellationError()) }
        resolutionContinuations.removeAll()
        completionContinuations.removeAll()
    }

    private func beginResolution() async throws -> BackendUserResolution {
        let index = resolutionRequestCount
        resolutionRequestCount += 1
        log.record("resolveCurrentUser")
        resumeWaiters(&resolutionWaiters, completedCount: resolutionRequestCount)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { resolutionContinuations[index] = $0 }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancelledResolutionRequests.insert(index)
            }
        }
    }

    private func beginCompletion() async throws {
        let index = completionRequestCount
        completionRequestCount += 1
        log.record("completeOnboarding")
        resumeWaiters(&completionWaiters, completedCount: completionRequestCount)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { completionContinuations[index] = $0 }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancelledCompletionRequests.insert(index)
            }
        }
    }

    private func resumeWaiters(
        _ waiters: inout [Int: [CheckedContinuation<Void, Never>]],
        completedCount: Int
    ) {
        for count in waiters.keys.filter({ $0 <= completedCount }) {
            waiters.removeValue(forKey: count)?.forEach { $0.resume() }
        }
    }
}

@MainActor
final class ControlledPurchaseHarness {
    var accessStatus: AccessStatus = .inactive
    var purchaseStatus: AccessStatus = .active
    var restoreStatus: AccessStatus = .active
    private(set) var bindingRequests: [String] = []
    private(set) var accessRequestCount = 0
    private(set) var purchaseRequestCount = 0
    private(set) var restoreRequestCount = 0
    private(set) var accessMonitoringRequestCount = 0
    private(set) var cancelledBindingRequests: Set<Int> = []
    private(set) var cancelledAccessRequests: Set<Int> = []

    private let log: ControlledOperationLog
    private var bindingContinuations: [Int: CheckedContinuation<Void, Error>] = [:]
    private var accessContinuations: [Int: CheckedContinuation<AccessStatus, Error>] = [:]
    private var bindingWaiters: [Int: [CheckedContinuation<Void, Never>]] = [:]
    private var accessWaiters: [Int: [CheckedContinuation<Void, Never>]] = [:]
    private var accessContinuation: AsyncStream<AccessStatus>.Continuation?

    init(log: ControlledOperationLog? = nil) {
        self.log = log ?? ControlledOperationLog()
    }

    func client() -> PurchaseClient {
        PurchaseClient(
            bindUser: { [self] userID in try await beginBinding(userID) },
            currentAccess: { [self] in try await beginAccessEvaluation() },
            purchase: { [self] in
                purchaseRequestCount += 1
                log.record("purchase")
                accessStatus = purchaseStatus
                accessContinuation?.yield(purchaseStatus)
                return purchaseStatus
            },
            restore: { [self] in
                restoreRequestCount += 1
                log.record("restore")
                accessStatus = restoreStatus
                accessContinuation?.yield(restoreStatus)
                return restoreStatus
            },
            accessUpdates: { [self] in
                accessMonitoringRequestCount += 1
                log.record("accessUpdates")
                return AsyncStream { accessContinuation = $0 }
            }
        )
    }

    func waitForBindingRequests(_ count: Int) async {
        guard bindingRequests.count < count else { return }
        await withCheckedContinuation { bindingWaiters[count, default: []].append($0) }
    }

    func waitForAccessRequests(_ count: Int) async {
        guard accessRequestCount < count else { return }
        await withCheckedContinuation { accessWaiters[count, default: []].append($0) }
    }

    func succeedBindingRequest(_ index: Int) {
        bindingContinuations.removeValue(forKey: index)?.resume()
    }

    func failBindingRequest(_ index: Int, with error: Error) {
        bindingContinuations.removeValue(forKey: index)?.resume(throwing: error)
    }

    func succeedAccessRequest(_ index: Int, with status: AccessStatus? = nil) {
        let status = status ?? accessStatus
        accessStatus = status
        accessContinuations.removeValue(forKey: index)?.resume(returning: status)
    }

    func failAccessRequest(_ index: Int, with error: Error) {
        accessContinuations.removeValue(forKey: index)?.resume(throwing: error)
    }

    func sendAccessUpdate(_ status: AccessStatus) {
        accessStatus = status
        accessContinuation?.yield(status)
    }

    func cancelOutstandingRequests() {
        bindingContinuations.values.forEach { $0.resume(throwing: CancellationError()) }
        accessContinuations.values.forEach { $0.resume(throwing: CancellationError()) }
        bindingContinuations.removeAll()
        accessContinuations.removeAll()
    }

    private func beginBinding(_ userID: String) async throws {
        let index = bindingRequests.count
        bindingRequests.append(userID)
        log.record("bind:\(userID)")
        resumeWaiters(&bindingWaiters, completedCount: bindingRequests.count)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { bindingContinuations[index] = $0 }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancelledBindingRequests.insert(index)
            }
        }
    }

    private func beginAccessEvaluation() async throws -> AccessStatus {
        let index = accessRequestCount
        accessRequestCount += 1
        log.record("currentAccess")
        resumeWaiters(&accessWaiters, completedCount: accessRequestCount)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { accessContinuations[index] = $0 }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancelledAccessRequests.insert(index)
            }
        }
    }

    private func resumeWaiters(
        _ waiters: inout [Int: [CheckedContinuation<Void, Never>]],
        completedCount: Int
    ) {
        for count in waiters.keys.filter({ $0 <= completedCount }) {
            waiters.removeValue(forKey: count)?.forEach { $0.resume() }
        }
    }
}

@MainActor
final class ControlledLooksHarness {
    private(set) var analysisInputs: [PreparedPhoto] = []
    private(set) var generationInputs: [(PreparedPhoto, HarmonyResult?)] = []
    private(set) var cancelledAnalysisRequests: Set<Int> = []
    private(set) var cancelledGenerationRequests: Set<Int> = []
    private(set) var clearedPhotoIDs: [UUID] = []

    private var analysisContinuations: [Int: CheckedContinuation<HarmonyResult, Error>] = [:]
    private var generationContinuations: [Int: CheckedContinuation<GeneratedLook, Error>] = [:]
    private var analysisWaiters: [Int: [CheckedContinuation<Void, Never>]] = [:]
    private var generationWaiters: [Int: [CheckedContinuation<Void, Never>]] = [:]

    func client() -> LooksClient {
        LooksClient(
            analyze: { [self] photo in try await beginAnalysis(photo) },
            generateLook: { [self] photo, harmony in try await beginGeneration(photo, harmony) },
            clearSession: { [weak self] photoID in await self?.recordClear(photoID) }
        )
    }

    func waitForAnalysisRequests(_ count: Int) async {
        guard analysisInputs.count < count else { return }
        await withCheckedContinuation { analysisWaiters[count, default: []].append($0) }
    }

    func waitForGenerationRequests(_ count: Int) async {
        guard generationInputs.count < count else { return }
        await withCheckedContinuation { generationWaiters[count, default: []].append($0) }
    }

    func succeedAnalysisRequest(_ index: Int, with result: HarmonyResult) {
        analysisContinuations.removeValue(forKey: index)?.resume(returning: result)
    }

    func failAnalysisRequest(_ index: Int, with error: Error) {
        analysisContinuations.removeValue(forKey: index)?.resume(throwing: error)
    }

    func succeedGenerationRequest(_ index: Int, with result: GeneratedLook) {
        generationContinuations.removeValue(forKey: index)?.resume(returning: result)
    }

    func failGenerationRequest(_ index: Int, with error: Error) {
        generationContinuations.removeValue(forKey: index)?.resume(throwing: error)
    }

    func cancelOutstandingRequests() {
        analysisContinuations.values.forEach { $0.resume(throwing: CancellationError()) }
        generationContinuations.values.forEach { $0.resume(throwing: CancellationError()) }
        analysisContinuations.removeAll()
        generationContinuations.removeAll()
    }

    private func recordClear(_ photoID: UUID) {
        clearedPhotoIDs.append(photoID)
    }

    private func beginAnalysis(_ photo: PreparedPhoto) async throws -> HarmonyResult {
        let index = analysisInputs.count
        analysisInputs.append(photo)
        resumeWaiters(&analysisWaiters, completedCount: analysisInputs.count)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { analysisContinuations[index] = $0 }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancelledAnalysisRequests.insert(index)
            }
        }
    }

    private func beginGeneration(
        _ photo: PreparedPhoto,
        _ harmony: HarmonyResult?
    ) async throws -> GeneratedLook {
        let index = generationInputs.count
        generationInputs.append((photo, harmony))
        resumeWaiters(&generationWaiters, completedCount: generationInputs.count)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { generationContinuations[index] = $0 }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancelledGenerationRequests.insert(index)
            }
        }
    }

    private func resumeWaiters(
        _ waiters: inout [Int: [CheckedContinuation<Void, Never>]],
        completedCount: Int
    ) {
        for count in waiters.keys.filter({ $0 <= completedCount }) {
            waiters.removeValue(forKey: count)?.forEach { $0.resume() }
        }
    }
}
