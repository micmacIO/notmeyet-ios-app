import Foundation
@testable import notmeyet

@MainActor
final class TestDependencyHarness {
    var userID: String?
    var authenticatedUserID = "test-user"
    var accessStatus: AccessStatus = .inactive
    var purchaseStatus: AccessStatus = .active
    var restoreStatus: AccessStatus = .active
    var backendUserOrigin: BackendUserOrigin = .existing
    var backendOnboardingCompleted = false
    var authenticationFailure: ServiceFailure?
    var backendResolutionFailure: ServiceFailure?
    var completionFailure: ServiceFailure?
    var bindingFailure: ServiceFailure?
    var accessFailure: ServiceFailure?
    var purchaseFailure: ServiceFailure?
    var restoreFailure: ServiceFailure?
    private(set) var events: [String] = []
    private(set) var handledURLs: [URL] = []
    private(set) var authenticationRequestCount = 0
    private(set) var backendResolutionRequestCount = 0
    private(set) var completionRequestCount = 0
    private(set) var bindingRequestCount = 0
    private(set) var accessRequestCount = 0
    private(set) var purchaseRequestCount = 0
    private(set) var restoreRequestCount = 0
    private(set) var accessMonitoringRequestCount = 0
    var isMonitoringAccess: Bool { accessMonitoringRequestCount > 0 }
    private var accessContinuation: AsyncStream<AccessStatus>.Continuation?

    func makeDependencies(
        configuration: AppConfiguration = .testMock,
        authentication: AuthenticationClient? = nil,
        backendUser: BackendUserClient? = nil,
        purchase: PurchaseClient? = nil,
        looks: LooksClient? = nil,
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
            annotatedImageData: Data([0x02]),
            faceShape: "Oval",
            harmonyScore: 88.6
        )
        let generatedLook = GeneratedLook(
            imageData: Data([0x03]),
            styleName: "Textured crop",
            styleDescription: "A short textured style."
        )

        return AppDependencies(
            configuration: configuration,
            authentication: authentication ?? AuthenticationClient(
                currentUserID: { [self] in userID },
                signIn: { [self] provider in
                    authenticationRequestCount += 1
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
            backendUser: backendUser ?? BackendUserClient(
                resolveCurrentUser: { [self] in
                    backendResolutionRequestCount += 1
                    events.append("resolveCurrentUser")
                    if let backendResolutionFailure { throw backendResolutionFailure }
                    return BackendUserResolution(
                        origin: backendUserOrigin,
                        onboardingCompleted: backendOnboardingCompleted
                    )
                },
                completeOnboarding: { [self] in
                    completionRequestCount += 1
                    events.append("completeOnboarding")
                    if let completionFailure { throw completionFailure }
                    backendOnboardingCompleted = true
                }
            ),
            purchase: purchase ?? PurchaseClient(
                bindUser: { [self] userID in
                    bindingRequestCount += 1
                    events.append("bind:\(userID)")
                    if let bindingFailure { throw bindingFailure }
                },
                currentAccess: { [self] in
                    accessRequestCount += 1
                    events.append("currentAccess")
                    if let accessFailure { throw accessFailure }
                    return accessStatus
                },
                purchase: { [self] in
                    purchaseRequestCount += 1
                    events.append("purchase")
                    if let purchaseFailure { throw purchaseFailure }
                    accessStatus = purchaseStatus
                    accessContinuation?.yield(purchaseStatus)
                    return purchaseStatus
                },
                restore: { [self] in
                    restoreRequestCount += 1
                    events.append("restore")
                    if let restoreFailure { throw restoreFailure }
                    accessStatus = restoreStatus
                    accessContinuation?.yield(restoreStatus)
                    return restoreStatus
                },
                accessUpdates: { [self] in
                    accessMonitoringRequestCount += 1
                    events.append("accessUpdates")
                    return AsyncStream { continuation in
                        accessContinuation = continuation
                    }
                }
            ),
            looks: looks ?? LooksClient(
                analyze: { _ in harmonyResult },
                generateLook: { _, _ in generatedLook },
                clearSession: { _ in }
            ),
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
        termsURL: nil,
        privacyURL: nil,
        facialDataDisclosuresApproved: false,
        backendUserLifecycleContractConfirmed: false
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
