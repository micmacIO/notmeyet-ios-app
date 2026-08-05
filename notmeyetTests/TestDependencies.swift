import Foundation
@testable import notmeyet

@MainActor
final class TestDependencyHarness {
    var userID: String?
    var authenticatedUserID = "test-user"
    var accessStatus: AccessStatus = .inactive
    var purchaseStatus: AccessStatus = .active
    var restoreStatus: AccessStatus = .active
    var authenticationFailure: ServiceFailure?
    var bindingFailure: ServiceFailure?
    var accessFailure: ServiceFailure?
    var purchaseFailure: ServiceFailure?
    var restoreFailure: ServiceFailure?
    var gates: [String: RoutingGate] = [:]
    var events: [String] = []
    var handledURLs: [URL] = []
    var isMonitoringAccess = false
    private var accessContinuation: AsyncStream<AccessStatus>.Continuation?

    func makeDependencies(
        authentication: AuthenticationClient? = nil,
        purchase: PurchaseClient? = nil,
        routingGate: RoutingGateClient? = nil,
        looks: LooksClient? = nil,
        generatedImage: GeneratedImageClient? = nil,
        photoProcessing: PhotoProcessingClient? = nil,
        cameraAccess: CameraAccessClient? = nil
    ) -> AppDependencies {
        let preparedPhoto = PreparedPhoto(
            displayData: Data([0x01]),
            uploadData: Data([0x02]),
            pixelWidth: 100,
            pixelHeight: 120
        )
        let harmonyResult = HarmonyResult(
            faceShapeTitle: "Oval",
            faceShapeDescription: "Balanced proportions.",
            harmonyTitle: "Balanced",
            harmonyDescription: "Small differences are normal.",
            guides: []
        )
        let generatedLook = GeneratedLook(
            imageURL: URL(string: "https://example.com/generated.jpg")!,
            styleName: "Textured crop",
            explanation: "A balanced option."
        )

        return AppDependencies(
            configuration: .testMock,
            authentication: authentication ?? AuthenticationClient(
                currentUserID: { [self] in userID },
                signIn: { [self] provider in
                    events.append("signIn:\(provider.rawValue)")
                    if let authenticationFailure { throw authenticationFailure }
                    userID = authenticatedUserID
                    return authenticatedUserID
                },
                handleOpenURL: { [self] url in
                    handledURLs.append(url)
                    return true
                }
            ),
            purchase: purchase ?? PurchaseClient(
                bindUser: { [self] userID in
                    events.append("bind:\(userID)")
                    if let bindingFailure { throw bindingFailure }
                },
                currentAccess: { [self] in
                    events.append("currentAccess")
                    if let accessFailure { throw accessFailure }
                    return accessStatus
                },
                purchase: { [self] in
                    events.append("purchase")
                    if let purchaseFailure { throw purchaseFailure }
                    accessStatus = purchaseStatus
                    accessContinuation?.yield(purchaseStatus)
                    return purchaseStatus
                },
                restore: { [self] in
                    events.append("restore")
                    if let restoreFailure { throw restoreFailure }
                    accessStatus = restoreStatus
                    accessContinuation?.yield(restoreStatus)
                    return restoreStatus
                },
                accessUpdates: { [self] in
                    isMonitoringAccess = true
                    return AsyncStream { continuation in
                        accessContinuation = continuation
                    }
                }
            ),
            routingGate: routingGate ?? RoutingGateClient(
                gate: { [self] userID in
                    events.append("gate:\(userID)")
                    return gates[userID] ?? .start
                },
                setGate: { [self] gate, userID in
                    events.append("setGate:\(gate.rawValue):\(userID)")
                    gates[userID] = gate
                },
                clearAll: { [self] in gates.removeAll() }
            ),
            looks: looks ?? LooksClient(
                analyze: { _ in harmonyResult },
                generateLook: { _, _ in generatedLook }
            ),
            generatedImage: generatedImage ?? GeneratedImageClient { _ in Data([0x03]) },
            photoProcessing: photoProcessing ?? PhotoProcessingClient { _, _ in preparedPhoto },
            cameraAccess: cameraAccess ?? CameraAccessClient(
                isAvailable: { true },
                authorizationState: { .authorized },
                requestAccess: { true }
            )
        )
    }

    func sendAccessUpdate(_ status: AccessStatus) {
        accessStatus = status
        accessContinuation?.yield(status)
    }
}

extension AppConfiguration {
    static let testMock = AppConfiguration(
        mode: .mock,
        googleClientID: "",
        revenueCatAPIKey: "",
        revenueCatEntitlementID: "pro",
        looksAPIBaseURL: nil,
        looksAuthToken: "",
        termsURL: nil,
        privacyURL: nil,
        facialDataDisclosuresApproved: false
    )
}

@MainActor
func eventually(
    attempts: Int = 100,
    _ predicate: @MainActor () -> Bool
) async -> Bool {
    for _ in 0..<attempts {
        if predicate() { return true }
        await Task.yield()
    }
    return predicate()
}
