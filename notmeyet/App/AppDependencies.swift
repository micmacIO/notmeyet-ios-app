import AVFoundation
import Foundation
import UIKit

@MainActor
extension AppDependencies {
    static func make() -> AppDependencies {
        make(configuration: .load())
    }

    static func make(configuration: AppConfiguration) -> AppDependencies {
        let photoProcessor = PhotoProcessor()
        let cameraAccess = systemCameraAccessClient()

        #if DEBUG
        if configuration.mode == .mock {
            let state = MockServiceState()
            return AppDependencies(
                configuration: configuration,
                authentication: state.authenticationClient(),
                backendUser: state.backendUserClient(),
                purchase: state.purchaseClient(),
                looks: state.looksClient(),
                photoProcessing: photoProcessor.client(),
                cameraAccess: cameraAccess
            )
        }
        #endif

        guard configuration.mode == .live else {
            return unavailable(
                configuration: configuration,
                photoProcessor: photoProcessor,
                cameraAccess: cameraAccess
            )
        }

        guard configuration.hasConfirmedBackendUserLifecycleConfiguration else {
            return unavailable(
                configuration: invalidConfiguration(
                    from: configuration,
                    reason: "Backend user lifecycle configuration is incomplete."
                ),
                photoProcessor: photoProcessor,
                cameraAccess: cameraAccess
            )
        }

        do {
            let purchaseClient = try LazyPurchaseClientProxy(
                apiKey: configuration.revenueCatAPIKey,
                entitlementID: configuration.revenueCatEntitlementID
            ).client()
            let authenticationService = LiveAuthenticationService(googleClientID: configuration.googleClientID)
            try authenticationService.configureFirebase()
            let backendUserService = LiveBackendUserService(
                configuration: configuration,
                idTokenProvider: { try await authenticationService.firebaseIDToken() }
            )
            let looksService = LiveLooksService(
                configuration: configuration,
                idTokenProvider: { try await authenticationService.firebaseIDToken() }
            )
            return AppDependencies(
                configuration: configuration,
                authentication: authenticationService.client(),
                backendUser: backendUserService.client(),
                purchase: purchaseClient,
                looks: looksService.client(),
                photoProcessing: photoProcessor.client(),
                cameraAccess: cameraAccess
            )
        } catch {
            return unavailable(
                configuration: invalidConfiguration(
                    from: configuration,
                    reason: error.localizedDescription
                ),
                photoProcessor: photoProcessor,
                cameraAccess: cameraAccess
            )
        }
    }

    private static func unavailable(
        configuration: AppConfiguration,
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
            backendUser: BackendUserClient(
                resolveCurrentUser: { throw ServiceFailure.configuration(message) },
                completeOnboarding: { throw ServiceFailure.configuration(message) }
            ),
            purchase: PurchaseClient(
                bindUser: { _ in throw ServiceFailure.configuration(message) },
                currentAccess: { throw ServiceFailure.configuration(message) },
                purchase: { throw ServiceFailure.configuration(message) },
                restore: { throw ServiceFailure.configuration(message) },
                accessUpdates: { AsyncStream { $0.finish() } }
            ),
            looks: LooksClient(
                analyze: { _ in throw ServiceFailure.configuration(message) },
                generateLook: { _, _ in throw ServiceFailure.configuration(message) },
                clearSession: { _ in }
            ),
            photoProcessing: photoProcessor.client(),
            cameraAccess: cameraAccess
        )
    }

    private static func invalidConfiguration(
        from configuration: AppConfiguration,
        reason: String
    ) -> AppConfiguration {
        AppConfiguration(
            mode: .invalid(reason),
            googleClientID: configuration.googleClientID,
            revenueCatAPIKey: configuration.revenueCatAPIKey,
            revenueCatEntitlementID: configuration.revenueCatEntitlementID,
            looksAPIBaseURL: configuration.looksAPIBaseURL,
            termsURL: configuration.termsURL,
            privacyURL: configuration.privacyURL,
            facialDataDisclosuresApproved: configuration.facialDataDisclosuresApproved,
            backendUserLifecycleContractConfirmed: configuration.backendUserLifecycleContractConfirmed
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

}
