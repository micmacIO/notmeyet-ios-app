import AVFoundation
import Foundation
import UIKit

@MainActor
extension AppDependencies {
    static func make() -> AppDependencies {
        make(configuration: .load())
    }

    static func make(configuration: AppConfiguration) -> AppDependencies {
        let gateStore = OnboardingGateStore()
        let photoProcessor = PhotoProcessor()
        let cameraAccess = systemCameraAccessClient()

        #if DEBUG
        if configuration.mode == .mock {
            let state = MockServiceState()
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--reset-onboarding") {
                gateStore.clearAll()
            }
            if let userID = state.userID, let gate = mockRoutingGate(in: arguments) {
                gateStore.setGate(gate, for: userID)
            }
            return AppDependencies(
                configuration: configuration,
                authentication: state.authenticationClient(),
                purchase: state.purchaseClient(),
                routingGate: gateStore.client(),
                looks: state.looksClient(),
                photoProcessing: photoProcessor.client(),
                cameraAccess: cameraAccess
            )
        }
        #endif

        guard configuration.mode == .live else {
            return unavailable(
                configuration: configuration,
                gateStore: gateStore,
                photoProcessor: photoProcessor,
                cameraAccess: cameraAccess
            )
        }

        do {
            let authenticationService = LiveAuthenticationService(googleClientID: configuration.googleClientID)
            try authenticationService.configureFirebase()
            let purchaseService = LivePurchaseService(
                apiKey: configuration.revenueCatAPIKey,
                entitlementID: configuration.revenueCatEntitlementID
            )
            let looksService = LiveLooksService(
                configuration: configuration,
                idTokenProvider: { try await authenticationService.firebaseIDToken() }
            )
            return AppDependencies(
                configuration: configuration,
                authentication: authenticationService.client(),
                purchase: purchaseService.client(),
                routingGate: gateStore.client(),
                looks: looksService.client(),
                photoProcessing: photoProcessor.client(),
                cameraAccess: cameraAccess
            )
        } catch {
            let invalid = AppConfiguration(
                mode: .invalid(error.localizedDescription),
                googleClientID: configuration.googleClientID,
                revenueCatAPIKey: configuration.revenueCatAPIKey,
                revenueCatEntitlementID: configuration.revenueCatEntitlementID,
                looksAPIBaseURL: configuration.looksAPIBaseURL,
                termsURL: configuration.termsURL,
                privacyURL: configuration.privacyURL,
                facialDataDisclosuresApproved: configuration.facialDataDisclosuresApproved
            )
            return unavailable(
                configuration: invalid,
                gateStore: gateStore,
                photoProcessor: photoProcessor,
                cameraAccess: cameraAccess
            )
        }
    }

    private static func unavailable(
        configuration: AppConfiguration,
        gateStore: OnboardingGateStore,
        photoProcessor: PhotoProcessor,
        cameraAccess: CameraAccessClient
    ) -> AppDependencies {
        let message: String
        if case .invalid(let reason) = configuration.mode {
            message = reason
        } else {
            message = "Service configuration is unavailable."
        }
        return AppDependencies(
            configuration: configuration,
            authentication: AuthenticationClient(
                currentUserID: { nil },
                signIn: { _ in throw ServiceFailure.configuration(message) },
                handleOpenURL: { _ in false }
            ),
            purchase: PurchaseClient(
                bindUser: { _ in throw ServiceFailure.configuration(message) },
                currentAccess: { throw ServiceFailure.configuration(message) },
                purchase: { throw ServiceFailure.configuration(message) },
                restore: { throw ServiceFailure.configuration(message) },
                accessUpdates: { AsyncStream { $0.finish() } }
            ),
            routingGate: gateStore.client(),
            looks: LooksClient(
                analyze: { _ in throw ServiceFailure.configuration(message) },
                generateLook: { _, _ in throw ServiceFailure.configuration(message) },
                clearSession: { _ in }
            ),
            photoProcessing: photoProcessor.client(),
            cameraAccess: cameraAccess
        )
    }

    private static func systemCameraAccessClient() -> CameraAccessClient {
        CameraAccessClient(
            isAvailable: {
                UIImagePickerController.isSourceTypeAvailable(.camera)
            },
            authorizationState: {
                switch AVCaptureDevice.authorizationStatus(for: .video) {
                case .authorized: .authorized
                case .notDetermined: .notDetermined
                case .denied: .denied
                case .restricted: .restricted
                @unknown default: .unknown
                }
            },
            requestAccess: {
                await AVCaptureDevice.requestAccess(for: .video)
            }
        )
    }

    #if DEBUG
    private static func mockRoutingGate(in arguments: [String]) -> RoutingGate? {
        guard let selector = arguments.first(where: { $0.hasPrefix("--mock-gate=") }) else {
            return nil
        }
        return RoutingGate(rawValue: String(selector.dropFirst("--mock-gate=".count)))
    }
    #endif
}
