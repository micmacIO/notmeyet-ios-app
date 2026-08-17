enum BackendUserOrigin: Equatable, Sendable {
    case created
    case existing
}

struct BackendUserResolution: Equatable, Sendable {
    let origin: BackendUserOrigin
    let onboardingCompleted: Bool
}

nonisolated struct BackendUserClient {
    var resolveCurrentUser: () async throws -> BackendUserResolution
    var completeOnboarding: () async throws -> Void
}
