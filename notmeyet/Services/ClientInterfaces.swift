import Foundation

struct AuthenticationClient {
    var currentUserID: () -> String?
    var signIn: (AuthenticationProvider) async throws -> String
    var handleOpenURL: (URL) -> Bool
}

struct PurchaseClient {
    var bindUser: (String) async throws -> Void
    var currentAccess: () async throws -> AccessStatus
    var purchase: () async throws -> AccessStatus
    var restore: () async throws -> AccessStatus
    var accessUpdates: () -> AsyncStream<AccessStatus>
}

nonisolated struct LooksClient {
    var analyze: (PreparedPhoto) async throws -> HarmonyResult
    var generateLook: (PreparedPhoto, HarmonyResult?) async throws -> GeneratedLook
    var clearSession: @Sendable (UUID) async -> Void
}

struct ImagePreparationPolicy: Equatable, Sendable {
    let maximumLongEdge: Int
    let jpegQuality: Double

    static let current = ImagePreparationPolicy(maximumLongEdge: 2_048, jpegQuality: 0.85)
}

nonisolated struct PhotoProcessingClient {
    var prepare: (Data, ImagePreparationPolicy) async throws -> PreparedPhoto
}

enum CameraAuthorizationState: Equatable, Sendable {
    case authorized
    case notDetermined
    case denied
    case restricted
    case unknown
}

@MainActor
struct CameraAccessClient {
    var isAvailable: @MainActor () -> Bool
    var authorizationState: @MainActor () -> CameraAuthorizationState
    var requestAccess: @MainActor () async -> Bool
}

struct AppDependencies {
    let configuration: AppConfiguration
    let authentication: AuthenticationClient
    let backendUser: BackendUserClient
    let purchase: PurchaseClient
    let looks: LooksClient
    let photoProcessing: PhotoProcessingClient
    let cameraAccess: CameraAccessClient
}
