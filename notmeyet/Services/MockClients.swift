import Foundation
import UIKit

#if DEBUG
@MainActor
final class MockServiceState {
    private let defaults: UserDefaults
    private let arguments: Set<String>
    private var accessContinuation: AsyncStream<AccessStatus>.Continuation?
    private var remainingAnalysisFailures: Int
    private var remainingGenerationFailures: Int
    private var remainingImageFailures: Int
    private var remainingCompletionFailures: Int
    private var remainingAccessFailures: Int
    private(set) var boundUserID: String?
    var accessStatus: AccessStatus

    init(defaults: UserDefaults = .standard, arguments: [String] = ProcessInfo.processInfo.arguments) {
        self.defaults = defaults
        self.arguments = Set(arguments)
        self.remainingAnalysisFailures = arguments.contains("--mock-analysis-fail-once") ? 1 : 0
        self.remainingGenerationFailures = arguments.contains("--mock-generation-fail-once") ? 1 : 0
        self.remainingImageFailures = arguments.contains("--mock-image-fail-once") ? 1 : 0
        self.remainingCompletionFailures = arguments.contains("--mock-completion-fail-once") ? 1 : 0
        self.remainingAccessFailures = arguments.contains("--mock-access-fail-once") ? 1 : 0
        self.accessStatus = arguments.contains("--mock-entitled") ? .active : .inactive
        if arguments.contains("--reset-onboarding") {
            defaults.removeObject(forKey: "notmeyet.mock.userID")
            defaults.removeObject(forKey: "notmeyet.mock.backendUserExists")
            defaults.removeObject(forKey: "notmeyet.mock.onboardingCompleted")
        }
        if arguments.contains("--mock-authenticated") {
            defaults.set("mock-user", forKey: "notmeyet.mock.userID")
        }
        if arguments.contains("--mock-backend-existing-incomplete") {
            defaults.set(true, forKey: "notmeyet.mock.backendUserExists")
            defaults.set(false, forKey: "notmeyet.mock.onboardingCompleted")
        }
        if arguments.contains("--mock-backend-existing-complete") {
            defaults.set(true, forKey: "notmeyet.mock.backendUserExists")
            defaults.set(true, forKey: "notmeyet.mock.onboardingCompleted")
        }
    }

    var userID: String? {
        defaults.string(forKey: "notmeyet.mock.userID")
    }

    func authenticationClient() -> AuthenticationClient {
        AuthenticationClient(
            currentUserID: { [self] in userID },
            signIn: { [self] _ in
                if arguments.contains("--mock-auth-cancel") { throw ServiceFailure.cancelled }
                if arguments.contains("--mock-auth-failure") {
                    throw ServiceFailure.authentication("We couldn't sign you in. Try again.")
                }
                defaults.set("mock-user", forKey: "notmeyet.mock.userID")
                return "mock-user"
            },
            handleOpenURL: { _ in true }
        )
    }

    func purchaseClient() -> PurchaseClient {
        PurchaseClient(
            bindUser: { [self] userID in
                if arguments.contains("--mock-binding-failure") {
                    throw ServiceFailure.identityBinding("We couldn't connect your account to purchases. Try again.")
                }
                boundUserID = userID
            },
            currentAccess: { [self] in
                if arguments.contains("--mock-access-failure") || remainingAccessFailures > 0 {
                    remainingAccessFailures = max(remainingAccessFailures - 1, 0)
                    throw ServiceFailure.access("We couldn't verify access. Try again.")
                }
                return accessStatus
            },
            purchase: { [self] in
                if arguments.contains("--mock-purchase-cancel") { throw ServiceFailure.cancelled }
                if arguments.contains("--mock-purchase-failure") {
                    throw ServiceFailure.access("The purchase couldn't be completed. Try again.")
                }
                accessStatus = arguments.contains("--mock-purchase-inactive") ? .inactive : .active
                accessContinuation?.yield(accessStatus)
                return accessStatus
            },
            restore: { [self] in
                if arguments.contains("--mock-restore-cancel") { throw ServiceFailure.cancelled }
                if arguments.contains("--mock-restore-failure") {
                    throw ServiceFailure.access("Purchases couldn't be restored. Try again.")
                }
                accessStatus = arguments.contains("--mock-restore-inactive") ? .inactive : .active
                accessContinuation?.yield(accessStatus)
                return accessStatus
            },
            accessUpdates: { [self] in
                AsyncStream { continuation in
                    accessContinuation = continuation
                    if arguments.contains("--mock-revoke-after-launch") {
                        continuation.yield(.inactive)
                    }
                }
            }
        )
    }

    func backendUserClient() -> BackendUserClient {
        BackendUserClient(
            resolveCurrentUser: { [self] in
                if arguments.contains("--mock-backend-resolution-failure") {
                    throw ServiceFailure.transport("We couldn't check your account. Try again.")
                }
                if arguments.contains("--mock-backend-invalid") {
                    throw ServiceFailure.transport("The account service returned an unusable response. Try again.")
                }
                let existed = defaults.bool(forKey: "notmeyet.mock.backendUserExists")
                let completed = defaults.bool(forKey: "notmeyet.mock.onboardingCompleted")
                defaults.set(true, forKey: "notmeyet.mock.backendUserExists")
                return BackendUserResolution(
                    origin: existed ? .existing : .created,
                    onboardingCompleted: completed
                )
            },
            completeOnboarding: { [self] in
                if arguments.contains("--mock-completion-failure") || remainingCompletionFailures > 0 {
                    remainingCompletionFailures = max(remainingCompletionFailures - 1, 0)
                    throw ServiceFailure.transport("We couldn't finish setting up your account. Try again.")
                }
                defaults.set(true, forKey: "notmeyet.mock.backendUserExists")
                defaults.set(true, forKey: "notmeyet.mock.onboardingCompleted")
            }
        )
    }

    func looksClient() -> LooksClient {
        LooksClient(
            analyze: { [self] _ in
                try await Task.sleep(for: .milliseconds(450))
                try Task.checkCancellation()
                if arguments.contains("--mock-analysis-failure") || remainingAnalysisFailures > 0 {
                    remainingAnalysisFailures = max(remainingAnalysisFailures - 1, 0)
                    throw ServiceFailure.transport("We couldn't finish your harmony check. Try again.")
                }
                return .mock
            },
            generateLook: { [self] _, _ in
                try await Task.sleep(for: .milliseconds(550))
                try Task.checkCancellation()
                if arguments.contains("--mock-generation-failure") || remainingGenerationFailures > 0 {
                    remainingGenerationFailures = max(remainingGenerationFailures - 1, 0)
                    throw ServiceFailure.transport("We couldn't create your look. Try again.")
                }
                if arguments.contains("--mock-image-failure") || remainingImageFailures > 0 {
                    remainingImageFailures = max(remainingImageFailures - 1, 0)
                    throw ServiceFailure.transport("The generated image couldn't be loaded. Try again.")
                }
                return .mock
            },
            clearSession: { _ in }
        )
    }
}

extension HarmonyResult {
    @MainActor
    static var mock: HarmonyResult {
        HarmonyResult(
            annotatedImageData: UIImage(named: "SamplePortrait")?.jpegData(compressionQuality: 0.9) ?? Data(),
            faceShape: "Oval",
            harmonyScore: 88.6
        )
    }
}

extension GeneratedLook {
    @MainActor
    static var mock: GeneratedLook {
        GeneratedLook(
            imageData: UIImage(named: "GeneratedLook")?.jpegData(compressionQuality: 0.9) ?? Data(),
            styleName: "Textured crop",
            styleDescription: "A short, textured style with clean sides and natural movement on top."
        )
    }
}
#endif
