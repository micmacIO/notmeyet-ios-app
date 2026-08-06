import Foundation
import Observation

@Observable
@MainActor
final class OnboardingFlowModel {
    var phase: AppAccessPhase = .bootstrapping {
        didSet {
            if case .configurationUnavailable(let message) = phase {
                announce(message)
            }
        }
    }
    var draft = OnboardingDraft()
    var analysisPhase: OperationPhase<HarmonyResult> = .idle {
        didSet {
            switch analysisPhase {
            case .loading:
                announce("Analyzing your photo.")
            case .failed(let message):
                announce(message)
            case .idle, .loaded:
                break
            }
        }
    }
    var generationPhase: OperationPhase<GeneratedLook> = .idle {
        didSet {
            switch generationPhase {
            case .loading:
                announce("Creating your look.")
            case .failed(let message):
                announce(message)
            case .loaded:
                announce("Your look is ready.")
            case .idle:
                break
            }
        }
    }
    var analysisCanRetry = true
    var generationCanRetry = true
    var authenticationError: String? {
        didSet { announce(authenticationError) }
    }
    var purchaseError: String? {
        didSet { announce(purchaseError) }
    }
    var photoError: String? {
        didSet { announce(photoError) }
    }
    var accessibilityAnnouncement: NMYAccessibilityAnnouncement?
    var isAuthenticating = false {
        didSet {
            if isAuthenticating {
                announce("Connecting your account.")
            }
        }
    }
    var isPurchasing = false {
        didSet {
            if isPurchasing {
                announce("Verifying your access.")
            }
        }
    }
    var comparisonSplit = 0.46

    #if DEBUG
    var debugUsesProductionPaywallShell = false
    var debugUsesStaticWelcomeMedia = false
    #endif

    let dependencies: AppDependencies
    private let accessCoordinator: AccessCoordinator
    private var currentUserID: String?
    private var pendingUserID: String?
    private var pendingAuthenticationProvider: AuthenticationProvider?
    private var pendingAuthenticationIsReturning = false
    private var authenticationRequestID = UUID()
    private var analysisTask: Task<Void, Never>?
    private var generationTask: Task<Void, Never>?
    private var accessUpdatesTask: Task<Void, Never>?
    private var analysisRequestID = UUID()
    private var generationRequestID = UUID()
    private var photoPreparationRequestID = UUID()

    var step: OnboardingStep? {
        guard case .onboarding(let step) = phase else { return nil }
        return step
    }

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        self.accessCoordinator = AccessCoordinator(
            authentication: dependencies.authentication,
            purchase: dependencies.purchase
        )
    }

    func bootstrap() async {
        if case .invalid(let message) = dependencies.configuration.mode {
            phase = .configurationUnavailable(message)
            return
        }

        phase = .bootstrapping
        do {
            let evaluation = try await accessCoordinator.evaluateCurrentAccess()
            applyBootstrapEvaluation(evaluation)
            startMonitoringAccessUpdates()
        } catch is CancellationError {
            return
        } catch {
            phase = .configurationUnavailable(safeMessage(from: error, fallback: "We couldn't verify your access. Try again."))
        }
    }

    func retryBootstrap() async {
        await bootstrap()
    }

    func showPrimaryGoal() { phase = .onboarding(.primaryGoal) }
    func showReturningSignIn() { phase = .onboarding(.returningSignIn) }
    func continueFromPrimaryGoal() { phase = .onboarding(.painPoints) }
    func continueFromPainPoints() { phase = .onboarding(.direction) }
    func continueFromDirection() { phase = .onboarding(.account) }

    func goBack() {
        switch step {
        case .primaryGoal: phase = .onboarding(.welcome)
        case .painPoints: phase = .onboarding(.primaryGoal)
        case .direction: phase = .onboarding(.painPoints)
        case .account:
            invalidateAuthentication()
            phase = .onboarding(.direction)
        case .photoReview: retakePhoto()
        case .returningSignIn:
            invalidateAuthentication()
            phase = .onboarding(.welcome)
        default: break
        }
    }

    func togglePrimaryGoal(_ goal: PrimaryGoal) {
        draft.primaryGoal = draft.primaryGoal == goal ? nil : goal
    }

    func togglePainPoint(_ painPoint: PainPoint) {
        if draft.painPoints.contains(painPoint) {
            draft.painPoints.remove(painPoint)
        } else {
            draft.painPoints.insert(painPoint)
        }
    }

    func toggleDirection(_ direction: StyleDirection) {
        draft.direction = draft.direction == direction ? nil : direction
    }

    func authenticate(with provider: AuthenticationProvider, returning: Bool) async {
        let requestID = UUID()
        authenticationRequestID = requestID
        authenticationError = nil
        pendingUserID = nil
        pendingAuthenticationProvider = provider
        pendingAuthenticationIsReturning = returning
        isAuthenticating = true
        defer {
            if authenticationRequestID == requestID {
                isAuthenticating = false
            }
        }
        do {
            let userID = try await dependencies.authentication.signIn(provider)
            try Task.checkCancellation()
            try requireCurrentAuthentication(requestID, returning: returning)
            pendingUserID = userID
            try await finishIdentityBinding(
                userID: userID,
                returning: returning,
                requestID: requestID
            )
        } catch ServiceFailure.cancelled, is CancellationError {
            guard authenticationRequestID == requestID else { return }
            clearPendingAuthentication()
            return
        } catch {
            guard isCurrentAuthentication(requestID, returning: returning) else { return }
            authenticationError = safeMessage(from: error, fallback: "We couldn't sign you in. Try again.")
        }
    }

    func retryAuthentication() async {
        if pendingUserID != nil {
            await retryIdentityBinding()
            return
        }
        guard let pendingAuthenticationProvider else { return }
        await authenticate(
            with: pendingAuthenticationProvider,
            returning: pendingAuthenticationIsReturning
        )
    }

    func retryIdentityBinding() async {
        guard let pendingUserID else { return }
        let requestID = UUID()
        authenticationRequestID = requestID
        authenticationError = nil
        isAuthenticating = true
        defer {
            if authenticationRequestID == requestID {
                isAuthenticating = false
            }
        }
        do {
            try await finishIdentityBinding(
                userID: pendingUserID,
                returning: pendingAuthenticationIsReturning,
                requestID: requestID
            )
        } catch ServiceFailure.cancelled, is CancellationError {
            return
        } catch {
            guard isCurrentAuthentication(
                requestID,
                returning: pendingAuthenticationIsReturning
            ) else { return }
            authenticationError = safeMessage(from: error, fallback: "We couldn't connect your account to purchases. Try again.")
        }
    }

    func preparePhoto(data: Data) async {
        let requestID = UUID()
        photoPreparationRequestID = requestID
        photoError = nil
        do {
            let photo = try await dependencies.photoProcessing.prepare(data, .current)
            try Task.checkCancellation()
            guard photoPreparationRequestID == requestID, step == .photoPreparation else { return }
            clearPhotoDerivedState()
            draft.preparedPhoto = photo
            phase = .onboarding(.photoReview)
        } catch is CancellationError {
            return
        } catch {
            guard photoPreparationRequestID == requestID, step == .photoPreparation else { return }
            photoError = safeMessage(from: error, fallback: "This photo couldn't be prepared. Choose another one.")
        }
    }

    func requestCamera() async -> Bool {
        photoError = nil
        guard dependencies.cameraAccess.isAvailable() else {
            photoError = "A camera isn't available here. Choose a photo from your library instead."
            return false
        }

        switch dependencies.cameraAccess.authorizationState() {
        case .authorized:
            return true
        case .notDetermined:
            guard await dependencies.cameraAccess.requestAccess() else {
                photoError = "Camera access is off. Allow it in Settings or choose a library photo."
                return false
            }
            return true
        case .denied:
            photoError = "Camera access is off. Allow it in Settings or choose a library photo."
            return false
        case .restricted:
            photoError = "Camera access is restricted. Choose a photo from your library instead."
            return false
        case .unknown:
            photoError = "The camera can't be opened right now. Choose a library photo instead."
            return false
        }
    }

    var shouldOfferCameraSettings: Bool {
        photoError != nil && dependencies.cameraAccess.authorizationState() == .denied
    }

    func loadLibraryPhoto(
        using loadData: @MainActor () async throws -> Data?
    ) async {
        photoError = nil
        do {
            guard let data = try await loadData() else {
                guard step == .photoPreparation else { return }
                photoError = "This photo couldn't be opened. Choose another one."
                return
            }
            guard step == .photoPreparation else { return }
            await preparePhoto(data: data)
        } catch is CancellationError {
            return
        } catch {
            guard step == .photoPreparation else { return }
            photoError = "This photo couldn't be opened. Choose another one."
        }
    }

    func usePhoto() {
        guard draft.preparedPhoto != nil else { return }
        phase = .onboarding(.analysisProcessing)
        startAnalysis()
    }

    func retakePhoto() {
        clearPhotoDerivedState()
        phase = .onboarding(.photoPreparation)
    }

    func skipHarmonyCheck() {
        enterPaywall()
    }

    func retryAnalysis() {
        guard analysisCanRetry else { return }
        startAnalysis()
    }

    func showMatchingStyle() {
        guard draft.preparedPhoto != nil else { return }
        phase = .onboarding(.generationProcessing)
        startGeneration()
    }

    func skipLook() { enterPaywall() }
    func retryGeneration() {
        guard generationCanRetry else { return }
        startGeneration()
    }
    func tryMore() { enterPaywall() }

    func purchase() async {
        await performPurchaseOperation(
            dependencies.purchase.purchase,
            inactiveMessage: "Your purchase completed, but access is not active yet. Try Restore purchases.",
            failureFallback: "The purchase couldn't be completed. Try again."
        )
    }

    func restore() async {
        await performPurchaseOperation(
            dependencies.purchase.restore,
            inactiveMessage: "No active purchases were found for this account.",
            failureFallback: "Purchases couldn't be restored. Try again."
        )
    }

    func refreshAccessAfterPurchase() async {
        await refreshPaywallAccess(
            inactiveMessage: "Your purchase completed, but access is not active yet. Try Restore purchases.",
            failureFallback: "We couldn't verify access after the purchase. Try Restore purchases."
        )
    }

    func refreshAccessAfterRestore() async {
        await refreshPaywallAccess(
            inactiveMessage: "No active purchases were found for this account.",
            failureFallback: "We couldn't verify restored access. Try again."
        )
    }

    func handlePurchaseFailure() {
        purchaseError = "The purchase couldn't be completed. Try again."
    }

    func handleRestoreFailure() {
        purchaseError = "Purchases couldn't be restored. Try again."
    }

    func handlePurchaseCancellation() {
        purchaseError = nil
    }

    func handleOpenURL(_ url: URL) {
        _ = dependencies.authentication.handleOpenURL(url)
    }

    func handleMemoryWarning() {
        guard let step, (OnboardingStep.photoReview.rawValue...OnboardingStep.firstResult.rawValue).contains(step.rawValue) else {
            return
        }
        clearPhotoDerivedState()
        photoError = "Your photo was cleared to free memory. Please choose it again."
        phase = .onboarding(.photoPreparation)
    }

    func setComparisonSplit(_ value: Double) {
        comparisonSplit = min(max(value, 0.12), 0.88)
    }

    private func finishIdentityBinding(
        userID: String,
        returning: Bool,
        requestID: UUID
    ) async throws {
        authenticationError = nil
        if returning {
            let evaluation = try await accessCoordinator.bindAndEvaluateAccess(for: userID)
            try requireCurrentAuthentication(requestID, returning: true)
            currentUserID = userID
            switch evaluation {
            case .active:
                clearPendingAuthentication()
                grantMainAccess()
            case .inactive:
                clearPendingAuthentication()
                enterPaywall()
            case .signedOut:
                phase = .onboarding(.returningSignIn)
            }
        } else {
            try await accessCoordinator.bindUser(userID)
            try requireCurrentAuthentication(requestID, returning: false)
            currentUserID = userID
            clearPendingAuthentication()
            dependencies.routingGate.setGate(.photo, userID)
            phase = .onboarding(.photoPreparation)
        }
    }

    private func startAnalysis() {
        guard let photo = draft.preparedPhoto else { return }
        analysisTask?.cancel()
        let requestID = UUID()
        analysisRequestID = requestID
        analysisCanRetry = true
        analysisPhase = .loading
        analysisTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.dependencies.looks.analyze(photo)
                try Task.checkCancellation()
                guard self.analysisRequestID == requestID else { return }
                self.draft.harmonyResult = result
                self.analysisPhase = .loaded(result)
                self.phase = .onboarding(.harmonySnapshot)
            } catch is CancellationError {
                return
            } catch {
                guard self.analysisRequestID == requestID else { return }
                self.analysisCanRetry = (error as? ServiceFailure)?.isRetryable ?? true
                self.analysisPhase = .failed(self.safeMessage(from: error, fallback: "We couldn't finish your harmony check. Try again."))
            }
        }
    }

    private func startGeneration() {
        guard let photo = draft.preparedPhoto else { return }
        generationTask?.cancel()
        let requestID = UUID()
        generationRequestID = requestID
        generationCanRetry = true
        generationPhase = .loading
        generationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let look = try await self.dependencies.looks.generateLook(photo, self.draft.harmonyResult)
                try Task.checkCancellation()
                guard self.generationRequestID == requestID else { return }
                self.draft.generatedLook = look
                self.generationPhase = .loaded(look)
                self.phase = .onboarding(.firstResult)
            } catch is CancellationError {
                return
            } catch {
                guard self.generationRequestID == requestID else { return }
                self.generationCanRetry = (error as? ServiceFailure)?.isRetryable ?? true
                self.generationPhase = .failed(self.safeMessage(from: error, fallback: "We couldn't create your look. Try again."))
            }
        }
    }

    private func enterPaywall() {
        if let currentUserID { dependencies.routingGate.setGate(.paywall, currentUserID) }
        clearPhotoDerivedState()
        phase = .onboarding(.paywall)
    }

    private func performPurchaseOperation(
        _ operation: () async throws -> AccessStatus,
        inactiveMessage: String,
        failureFallback: String
    ) async {
        guard phase == .onboarding(.paywall), currentUserID != nil else { return }
        purchaseError = nil
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            applyPaywallAccess(try await operation(), inactiveMessage: inactiveMessage)
        } catch ServiceFailure.cancelled, is CancellationError {
            return
        } catch {
            guard phase == .onboarding(.paywall) else { return }
            purchaseError = safeMessage(from: error, fallback: failureFallback)
        }
    }

    private func refreshPaywallAccess(inactiveMessage: String, failureFallback: String) async {
        await performPurchaseOperation(
            dependencies.purchase.currentAccess,
            inactiveMessage: inactiveMessage,
            failureFallback: failureFallback
        )
    }

    private func applyPaywallAccess(_ status: AccessStatus, inactiveMessage: String) {
        guard phase == .onboarding(.paywall), currentUserID != nil else { return }
        if status == .active {
            purchaseError = nil
            grantMainAccess()
        } else {
            purchaseError = inactiveMessage
        }
    }

    private func grantMainAccess() {
        purchaseError = nil
        clearPhotoDerivedState()
        phase = .main
    }

    private func clearPhotoDerivedState() {
        clearRemoteSession(for: draft.preparedPhoto?.id)
        cancelPhotoDerivedOperations()
        draft.clearPhotoDerivedContent()
        analysisPhase = .idle
        generationPhase = .idle
        analysisCanRetry = true
        generationCanRetry = true
        comparisonSplit = 0.46
    }

    private func applyBootstrapEvaluation(_ evaluation: AccessEvaluation) {
        clearPhotoDerivedState()
        switch evaluation {
        case .signedOut:
            currentUserID = nil
            phase = .onboarding(.welcome)
        case .active(let userID):
            currentUserID = userID
            grantMainAccess()
        case .inactive(let userID):
            currentUserID = userID
            switch dependencies.routingGate.gate(userID) {
            case .start: phase = .onboarding(.welcome)
            case .photo: phase = .onboarding(.photoPreparation)
            case .paywall: phase = .onboarding(.paywall)
            }
        }
    }

    private func startMonitoringAccessUpdates() {
        accessUpdatesTask?.cancel()
        let updates = dependencies.purchase.accessUpdates()
        accessUpdatesTask = Task { [weak self] in
            for await status in updates {
                guard let self else { return }
                if status == .inactive, self.phase == .main {
                    self.enterPaywall()
                } else if status == .active, self.phase == .onboarding(.paywall) {
                    self.grantMainAccess()
                }
            }
        }
    }

    private func cancelPhotoDerivedOperations() {
        analysisTask?.cancel()
        generationTask?.cancel()
        photoPreparationRequestID = UUID()
        analysisRequestID = UUID()
        generationRequestID = UUID()
    }

    private func clearRemoteSession(for photoID: UUID?) {
        guard let photoID else { return }
        let looks = dependencies.looks
        Task { await looks.clearSession(photoID) }
    }

    private func clearPendingAuthentication() {
        pendingUserID = nil
        pendingAuthenticationProvider = nil
        pendingAuthenticationIsReturning = false
    }

    private func announce(_ message: String?) {
        guard let message, !message.isEmpty else { return }
        accessibilityAnnouncement = NMYAccessibilityAnnouncement(message: message)
    }

    private func invalidateAuthentication() {
        authenticationRequestID = UUID()
        authenticationError = nil
        isAuthenticating = false
        clearPendingAuthentication()
    }

    private func requireCurrentAuthentication(
        _ requestID: UUID,
        returning: Bool
    ) throws {
        guard isCurrentAuthentication(requestID, returning: returning) else {
            throw CancellationError()
        }
    }

    private func isCurrentAuthentication(
        _ requestID: UUID,
        returning: Bool
    ) -> Bool {
        let expectedStep: OnboardingStep = returning ? .returningSignIn : .account
        return authenticationRequestID == requestID && phase == .onboarding(expectedStep)
    }

    private func safeMessage(from error: Error, fallback: String) -> String {
        if let failure = error as? ServiceFailure, let description = failure.errorDescription {
            return description
        }
        return fallback
    }
}
