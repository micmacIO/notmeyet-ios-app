import Foundation
@testable import notmeyet

@MainActor
final class ControlledPurchaseHarness {
    var accessStatus: AccessStatus = .inactive
    private(set) var bindingRequests: [String] = []

    private var bindingContinuations: [Int: CheckedContinuation<Void, Error>] = [:]
    private var bindingWaiters: [Int: [CheckedContinuation<Void, Never>]] = [:]

    func client() -> PurchaseClient {
        PurchaseClient(
            bindUser: { [self] userID in try await beginBinding(userID) },
            currentAccess: { [self] in accessStatus },
            purchase: { [self] in accessStatus },
            restore: { [self] in accessStatus },
            accessUpdates: { AsyncStream { $0.finish() } }
        )
    }

    func waitForBindingRequests(_ count: Int) async {
        guard bindingRequests.count < count else { return }
        await withCheckedContinuation { bindingWaiters[count, default: []].append($0) }
    }

    func succeedBindingRequest(_ index: Int) {
        bindingContinuations.removeValue(forKey: index)?.resume()
    }

    func failBindingRequest(_ index: Int, with error: Error) {
        bindingContinuations.removeValue(forKey: index)?.resume(throwing: error)
    }

    func cancelOutstandingRequests() {
        bindingContinuations.values.forEach { $0.resume(throwing: CancellationError()) }
        bindingContinuations.removeAll()
    }

    private func beginBinding(_ userID: String) async throws {
        let index = bindingRequests.count
        bindingRequests.append(userID)
        for count in bindingWaiters.keys.filter({ $0 <= bindingRequests.count }) {
            bindingWaiters.removeValue(forKey: count)?.forEach { $0.resume() }
        }
        try await withCheckedThrowingContinuation { bindingContinuations[index] = $0 }
    }
}

@MainActor
final class ControlledLooksHarness {
    private(set) var analysisInputs: [PreparedPhoto] = []
    private(set) var generationInputs: [(PreparedPhoto, HarmonyResult?)] = []
    private(set) var cancelledAnalysisRequests: Set<Int> = []
    private(set) var cancelledGenerationRequests: Set<Int> = []

    private var analysisContinuations: [Int: CheckedContinuation<HarmonyResult, Error>] = [:]
    private var generationContinuations: [Int: CheckedContinuation<GeneratedLook, Error>] = [:]
    private var analysisWaiters: [Int: [CheckedContinuation<Void, Never>]] = [:]
    private var generationWaiters: [Int: [CheckedContinuation<Void, Never>]] = [:]

    func client() -> LooksClient {
        LooksClient(
            analyze: { [self] photo in try await beginAnalysis(photo) },
            generateLook: { [self] photo, harmony in try await beginGeneration(photo, harmony) }
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

@MainActor
final class ControlledGeneratedImageHarness {
    private(set) var requestedURLs: [URL] = []
    private(set) var cancelledRequests: Set<Int> = []

    private var continuations: [Int: CheckedContinuation<Data, Error>] = [:]
    private var waiters: [Int: [CheckedContinuation<Void, Never>]] = [:]

    func client() -> GeneratedImageClient {
        GeneratedImageClient { [self] url in try await beginLoad(url) }
    }

    func waitForRequests(_ count: Int) async {
        guard requestedURLs.count < count else { return }
        await withCheckedContinuation { waiters[count, default: []].append($0) }
    }

    func succeedRequest(_ index: Int, with data: Data) {
        continuations.removeValue(forKey: index)?.resume(returning: data)
    }

    func failRequest(_ index: Int, with error: Error) {
        continuations.removeValue(forKey: index)?.resume(throwing: error)
    }

    func cancelOutstandingRequests() {
        continuations.values.forEach { $0.resume(throwing: CancellationError()) }
        continuations.removeAll()
    }

    private func beginLoad(_ url: URL) async throws -> Data {
        let index = requestedURLs.count
        requestedURLs.append(url)
        for count in waiters.keys.filter({ $0 <= requestedURLs.count }) {
            waiters.removeValue(forKey: count)?.forEach { $0.resume() }
        }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuations[index] = $0 }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancelledRequests.insert(index)
            }
        }
    }
}
