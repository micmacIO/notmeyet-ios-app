import AuthenticationServices
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit

@MainActor
final class LiveAuthenticationService {
    private let googleClientID: String
    private var appleSession: AppleAuthorizationSession?

    init(googleClientID: String) {
        self.googleClientID = googleClientID
    }

    func configureFirebase() throws {
        guard FirebaseApp.app() == nil else { return }
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            throw ServiceFailure.configuration("Firebase configuration is unavailable in this build.")
        }
        FirebaseApp.configure()
    }

    func client() -> AuthenticationClient {
        AuthenticationClient(
            currentUserID: { Auth.auth().currentUser?.uid },
            signIn: { [self] provider in
                switch provider {
                case .apple:
                    return try await signInWithApple()
                case .google:
                    return try await signInWithGoogle()
                }
            },
            handleOpenURL: { url in GIDSignIn.sharedInstance.handle(url) }
        )
    }

    func firebaseIDToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw ServiceFailure.authentication("Sign in again before creating your preview.")
        }
        do {
            return try await user.getIDToken()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw ServiceFailure.authentication("We couldn't authenticate the preview request. Try again.")
        }
    }

    private func signInWithApple() async throws -> String {
        let nonce = try AuthenticationNonce.make()
        let session = AppleAuthorizationSession(rawNonce: nonce)
        appleSession = session
        defer { appleSession = nil }

        let credential = try await session.authorize()
        guard
            let tokenData = credential.identityToken,
            let token = String(data: tokenData, encoding: .utf8)
        else {
            throw ServiceFailure.authentication("Apple did not return a usable identity token.")
        }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: token,
            rawNonce: nonce,
            fullName: credential.fullName
        )
        do {
            return try await Auth.auth().signIn(with: firebaseCredential).user.uid
        } catch {
            throw ServiceFailure.authentication("Sign in with Apple could not be completed.")
        }
    }

    private func signInWithGoogle() async throws -> String {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: googleClientID)
        guard let presenter = UIApplication.shared.foregroundViewController else {
            throw ServiceFailure.authentication("Google Sign-In cannot be presented right now.")
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                throw ServiceFailure.authentication("Google did not return a usable identity token.")
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            return try await Auth.auth().signIn(with: credential).user.uid
        } catch let error as GIDSignInError where error.code == .canceled {
            throw ServiceFailure.cancelled
        } catch let error as ServiceFailure {
            throw error
        } catch {
            throw ServiceFailure.authentication("Google Sign-In could not be completed.")
        }
    }
}

@MainActor
private final class AppleAuthorizationSession: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {
    private let rawNonce: String
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    init(rawNonce: String) {
        self.rawNonce = rawNonce
    }

    func authorize() async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = AuthenticationNonce.sha256(rawNonce)
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.foregroundWindow ?? ASPresentationAnchor()
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: ServiceFailure.authentication("Apple returned an unsupported credential."))
            continuation = nil
            return
        }
        continuation?.resume(returning: credential)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authorizationError = error as? ASAuthorizationError, authorizationError.code == .canceled {
            continuation?.resume(throwing: ServiceFailure.cancelled)
        } else {
            continuation?.resume(throwing: ServiceFailure.authentication("Sign in with Apple could not be completed."))
        }
        continuation = nil
    }
}

@MainActor
private extension UIApplication {
    var foregroundWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .windows
            .first(where: \.isKeyWindow)
    }

    var foregroundViewController: UIViewController? {
        var current = foregroundWindow?.rootViewController
        while let presented = current?.presentedViewController { current = presented }
        if let navigation = current as? UINavigationController { return navigation.visibleViewController }
        if let tab = current as? UITabBarController { return tab.selectedViewController }
        return current
    }
}
