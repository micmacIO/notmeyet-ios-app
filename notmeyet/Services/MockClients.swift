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
    private(set) var boundUserID: String?
    var accessStatus: AccessStatus

    init(defaults: UserDefaults = .standard, arguments: [String] = ProcessInfo.processInfo.arguments) {
        self.defaults = defaults
        self.arguments = Set(arguments)
        self.remainingAnalysisFailures = arguments.contains("--mock-analysis-fail-once") ? 1 : 0
        self.remainingGenerationFailures = arguments.contains("--mock-generation-fail-once") ? 1 : 0
        self.remainingImageFailures = arguments.contains("--mock-image-fail-once") ? 1 : 0
        self.accessStatus = arguments.contains("--mock-entitled") ? .active : .inactive
        if arguments.contains("--reset-onboarding") {
            defaults.removeObject(forKey: "notmeyet.mock.userID")
        }
        if arguments.contains("--mock-authenticated") {
            defaults.set("mock-user", forKey: "notmeyet.mock.userID")
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
                if arguments.contains("--mock-access-failure") {
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
                return .mock
            }
        )
    }

    func generatedImageClient() -> GeneratedImageClient {
        GeneratedImageClient { [self] _ in
            try await Task.sleep(for: .milliseconds(250))
            try Task.checkCancellation()
            if arguments.contains("--mock-image-failure") || remainingImageFailures > 0 {
                remainingImageFailures = max(remainingImageFailures - 1, 0)
                throw ServiceFailure.transport("The generated image couldn't be loaded. Try again.")
            }
            guard let data = UIImage(named: "GeneratedLook")?.jpegData(compressionQuality: 0.9) else {
                throw ServiceFailure.transport("The generated fixture is unavailable.")
            }
            return data
        }
    }
}

extension HarmonyResult {
    static let mock = HarmonyResult(
        faceShapeTitle: "Oval",
        faceShapeDescription: "Balanced proportions with slightly more length than width.",
        harmonyTitle: "Naturally balanced",
        harmonyDescription: "Small left-to-right differences are normal.",
        guides: [
            HarmonyGuide(id: "eyes", points: [.init(x: 0.23, y: 0.41), .init(x: 0.77, y: 0.41)]),
            HarmonyGuide(id: "mid", points: [.init(x: 0.19, y: 0.58), .init(x: 0.81, y: 0.58)]),
            HarmonyGuide(id: "outline", points: [
                .init(x: 0.31, y: 0.19), .init(x: 0.18, y: 0.48),
                .init(x: 0.30, y: 0.82), .init(x: 0.50, y: 0.91),
                .init(x: 0.70, y: 0.82), .init(x: 0.82, y: 0.48),
                .init(x: 0.69, y: 0.19), .init(x: 0.31, y: 0.19)
            ])
        ]
    )
}

extension GeneratedLook {
    static let mock = GeneratedLook(
        imageURL: URL(string: "https://mock.notmeyet.invalid/generated-look.jpg")!,
        styleName: "Textured crop",
        explanation: "The added texture creates width around the upper face, while shorter sides keep the overall shape balanced."
    )
}
#endif
