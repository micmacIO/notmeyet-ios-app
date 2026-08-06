import Foundation

nonisolated struct RemoteID: RawRepresentable, Hashable, Sendable {
    let rawValue: String

    init?(rawValue: String) {
        let bytes = rawValue.utf8
        guard
            bytes.isEmpty == false,
            bytes.allSatisfy({ (48...57).contains($0) }),
            bytes.contains(where: { $0 != 48 })
        else {
            return nil
        }
        self.rawValue = rawValue
    }

    var positiveInt64: Int64? {
        guard let value = Int64(rawValue), value > 0 else { return nil }
        return value
    }
}

nonisolated struct SelfieResponse: Decodable, Sendable {
    let id: String?
    let deepface: DeepfaceAnalysis?
    let symmetry: SymmetryAnalysis?
    let shape: ShapeAnalysis?
    let mesh: MeshAnalysis?
    let ratio: RatioAnalysis?
}

nonisolated struct DeepfaceAnalysis: Decodable, Sendable {}

nonisolated struct SymmetryAnalysis: Decodable, Sendable {
    let overallScore: Double?
}

nonisolated struct ShapeAnalysis: Decodable, Sendable {
    let primaryShape: String?
}

nonisolated struct MeshAnalysis: Decodable, Sendable {
    let imageUrl: String?
}

nonisolated struct RatioAnalysis: Decodable, Sendable {}

nonisolated struct AnalyzeSelfieResponse: Decodable, Sendable {
    let selfieId: String?
}

nonisolated struct TransformationResponse: Decodable, Sendable {
    let id: String?
    let creditPrice: Int?
    let category: String?
    let displayName: String?
    let description: String?
    let personalizedReason: String?
}

nonisolated struct GenerationRequest: Encodable, Sendable {
    let selfieId: Int64
    let transformationIds: [Int64]
}

nonisolated struct GenerationResponse: Decodable, Sendable {
    let id: String?
    let selfieId: String?
    let status: GenerationStatus?
    let items: [ItemResponse]?
}

nonisolated struct ItemResponse: Decodable, Sendable {
    let transformationId: String?
    let status: GenerationStatus?
    let resultImageUrl: String?
    let errorMessage: String?
}

nonisolated enum GenerationStatus: Equatable, Sendable {
    case pending
    case submitting
    case awaitingResult
    case processing
    case completed
    case partiallyCompleted
    case failed
    case unknown
}

extension GenerationStatus: Decodable {
    init(from decoder: any Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        switch rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "_")
            .uppercased() {
        case "PENDING": self = .pending
        case "SUBMITTING": self = .submitting
        case "AWAITING_RESULT": self = .awaitingResult
        case "PROCESSING": self = .processing
        case "COMPLETED": self = .completed
        case "PARTIALLY_COMPLETED": self = .partiallyCompleted
        case "FAILED": self = .failed
        default: self = .unknown
        }
    }
}

nonisolated struct ProblemDetail: Decodable, Sendable {
    let type: String?
    let title: String?
    let status: Int?
    let detail: String?
    let instance: String?
}
