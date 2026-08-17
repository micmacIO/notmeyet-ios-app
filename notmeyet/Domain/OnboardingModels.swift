import Foundation

enum OnboardingStep: Int, CaseIterable, Sendable {
    case welcome = 1
    case primaryGoal
    case painPoints
    case direction
    case account
    case photoPreparation
    case photoReview
    case analysisProcessing
    case harmonySnapshot
    case generationProcessing
    case firstResult
    case paywall
    case returningSignIn

    var progress: Double? {
        guard rawValue >= 2, rawValue <= 11 else { return nil }
        return Double(rawValue - 1) / 10
    }

    var screenNumber: String {
        String(format: "%02d", rawValue)
    }
}

enum AppAccessPhase: Equatable, Sendable {
    case bootstrapping
    case onboarding(OnboardingStep)
    case postOnboardingAccess
    case main
    case configurationUnavailable(String)
}

enum AuthenticationProvider: String, CaseIterable, Sendable {
    case apple
    case google
}

enum AccessStatus: Equatable, Sendable {
    case active
    case inactive
}

enum AccessEvaluation: Equatable, Sendable {
    case signedOut
    case active(userID: String)
    case inactive(userID: String)
}

enum OperationPhase<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(String)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

struct NMYAccessibilityAnnouncement: Equatable, Identifiable, Sendable {
    let id: UUID
    let message: String

    nonisolated init(id: UUID = UUID(), message: String) {
        self.id = id
        self.message = message
    }
}

enum ChoiceCardinality: Equatable, Sendable {
    case zeroOrOne
    case zeroOrMore

    var allowsMultipleSelections: Bool {
        self == .zeroOrMore
    }
}

enum PrimaryGoal: String, CaseIterable, Identifiable, Sendable {
    case suitableHaircut
    case sharperLook
    case newStyle
    case confidence
    case avoidRegret
    case explore

    var id: Self { self }

    static let cardinality = ChoiceCardinality.zeroOrOne

    var detail: String? { nil }

    var title: String {
        switch self {
        case .suitableHaircut: "Find a haircut that actually suits me"
        case .sharperLook: "Look sharper and more put-together"
        case .newStyle: "Break out of my current style"
        case .confidence: "Feel more confident about my appearance"
        case .avoidRegret: "Avoid regretting my next haircut"
        case .explore: "Just see what else could work"
        }
    }
}

enum PainPoint: String, CaseIterable, Identifiable, Sendable {
    case unknownFit
    case modelMismatch
    case cannotVisualize
    case barberLanguage
    case previousRegret
    case safeStyle

    var id: Self { self }

    static let cardinality = ChoiceCardinality.zeroOrMore

    var detail: String? { nil }

    var title: String {
        switch self {
        case .unknownFit: "I don't know what suits my face"
        case .modelMismatch: "Haircuts look different on me than on the model"
        case .cannotVisualize: "I can't picture a new style before committing"
        case .barberLanguage: "I don't know what to ask my barber for"
        case .previousRegret: "I've regretted a haircut before"
        case .safeStyle: "I keep choosing the same safe style"
        }
    }
}

enum StyleDirection: String, CaseIterable, Identifiable, Sendable {
    case subtle
    case noticeable
    case bold

    var id: Self { self }

    static let cardinality = ChoiceCardinality.zeroOrOne

    var title: String {
        switch self {
        case .subtle: "Subtle"
        case .noticeable: "Noticeable"
        case .bold: "Bold"
        }
    }

    var detail: String {
        switch self {
        case .subtle: "A cleaner version of my current look"
        case .noticeable: "Clearly different, but still easy to wear"
        case .bold: "Show me something I wouldn't normally try"
        }
    }
}

struct PreparedPhoto: Identifiable, Equatable, Sendable {
    let id: UUID
    let displayData: Data
    let uploadData: Data
    let pixelWidth: Int
    let pixelHeight: Int

    nonisolated init(
        id: UUID = UUID(),
        displayData: Data,
        uploadData: Data,
        pixelWidth: Int,
        pixelHeight: Int
    ) {
        self.id = id
        self.displayData = displayData
        self.uploadData = uploadData
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}

struct HarmonyResult: Equatable, Sendable {
    let annotatedImageData: Data
    let faceShape: String
    let harmonyScore: Double
}

struct GeneratedLook: Equatable, Sendable {
    let imageData: Data
    let styleName: String
    let styleDescription: String
}

struct OnboardingDraft {
    var primaryGoal: PrimaryGoal?
    var painPoints: Set<PainPoint> = []
    var direction: StyleDirection?
    var preparedPhoto: PreparedPhoto?
    var harmonyResult: HarmonyResult?
    var generatedLook: GeneratedLook?

    mutating func clearPhotoDerivedContent() {
        preparedPhoto = nil
        harmonyResult = nil
        generatedLook = nil
    }
}

enum ServiceFailure: Error, Equatable, LocalizedError, Sendable {
    case cancelled
    case configuration(String)
    case authentication(String)
    case identityBinding(String)
    case access(String)
    case transport(String)
    case nonRetryable(String)
    case invalidImage(String)

    var isRetryable: Bool {
        if case .nonRetryable = self { return false }
        return true
    }

    var errorDescription: String? {
        switch self {
        case .cancelled:
            nil
        case .configuration(let message),
             .authentication(let message),
             .identityBinding(let message),
             .access(let message),
             .transport(let message),
             .nonRetryable(let message),
             .invalidImage(let message):
            message
        }
    }
}
