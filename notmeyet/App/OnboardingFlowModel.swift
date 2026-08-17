import Foundation
import Observation

enum BackendUserEntryContext: Equatable, Sendable {
    case launch
    case account
    case returningSignIn
}

enum AccountOperationStage: Equatable, Sendable {
    case idle
    case resolving(userID: String, context: BackendUserEntryContext)
    case completing(userID: String, step: OnboardingStep)
    case accessPending(userID: String)
}

@Observable
@MainActor
final class OnboardingFlowModel {
    var phase: AppAccessPhase = .bootstrapping {
        didSet {
            if case .completing(_, let initiatingStep) = accountOperationStage,
               phase != .onboarding(initiatingStep) {
                invalidateOnboardingCompletion()
            }
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
    var completionError: String? {
        didSet { announce(completionError) }
    }
    var accessError: String? {
        didSet { announce(accessError) }
    }
    var returningAccountNotice: String?
    var purchaseError: String? {
        didSet { announce(purchaseError) }
    }
    var photoError: String? {
        didSet { announce(photoError) }
    }
    var accessibilityAnnouncement: NMYAccessibilityAnnouncement?
    var isAuthenticating = false {
        didSet {
            if isAuthenticating && oldValue == false {
                announce("Connecting your account.")
            }
        }
    }
    var isResolvingAccount = false {
        didSet {
            if isResolvingAccount && oldValue == false {
                announce("Checking your account.")
            }
        }
    }
    var isCompletingOnboarding = false {
        didSet {
            if isCompletingOnboarding && oldValue == false {
                announce("Finishing your account setup.")
            }
        }
    }
    var isVerifyingAccess = false
    var isPurchasing = false {
        didSet {
            if isPurchasing && oldValue == false {
                announce("Verifying your access.")
            }
        }
    }
    var comparisonSplit = 0.46

    var isConnectingAccount: Bool {
        isAuthenticating || isResolvingAccount
    }

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
    private var completionRequestID = UUID()
    private var accessRequestID = UUID()
    private var analysisTask: Task<Void, Never>?
    private var generationTask: Task<Void, Never>?
    private var completionTask: Task<Void, Never>?
    private var accessTask: Task<Void, Never>?
    private var accessUpdatesTask: Task<Void, Never>?
    private var analysisRequestID = UUID()
    private var generationRequestID = UUID()
    private var photoAcquisitionRequestID = UUID()
    private var photoPreparationRequestID = UUID()
    private(set) var accountOperationStage: AccountOperationStage = .idle

    var step: OnboardingStep? {
        guard case .onboarding(let step) = phase else { return nil }
        return step
    }

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        self.accessCoordinator = AccessCoordinator(
            purchase: dependencies.purchase
        )
    }

    func bootstrap() async {
        if case .invalid(let message) = dependencies.configuration.mode {
            phase = .configurationUnavailable(message)
            return
        }

        phase = .bootstrapping
        guard let userID = dependencies.authentication.currentUserID() else {
            currentUserID = nil
            accountOperationStage = .idle
            phase = .onboarding(.welcome)
            return
        }
        await resolveLaunchUser(userID)
    }

    func retryBootstrap() async {
        guard case .resolving(let userID, .launch) = accountOperationStage else {
            await bootstrap()
            return
        }
        await resolveLaunchUser(userID)
    }

    private func resolveLaunchUser(_ userID: String) async {
        phase = .bootstrapping
        currentUserID = userID
        let requestID = UUID()
        authenticationRequestID = requestID
        accountOperationStage = .resolving(userID: userID, context: .launch)
        isResolvingAccount = true
        do {
            let resolution = try await dependencies.backendUser.resolveCurrentUser()
            try requireCurrentResolution(requestID, context: .launch)
            isResolvingAccount = false
            try await applyResolution(resolution, userID: userID, context: .launch)
        } catch is CancellationError {
            guard authenticationRequestID == requestID else { return }
            isResolvingAccount = false
            return
        } catch {
            guard authenticationRequestID == requestID else { return }
            isResolvingAccount = false
            accountOperationStage = .resolving(userID: userID, context: .launch)
            phase = .configurationUnavailable(safeMessage(from: error, fallback: "We couldn't verify your access. Try again."))
        }
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

    func startOnboardingFromReturningAccount() {
        returningAccountNotice = nil
        authenticationError = nil
        invalidateAuthentication()
        phase = .onboarding(.welcome)
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
        returningAccountNotice = nil
        accountOperationStage = .idle
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
            try await resolveBackendUser(
                userID: userID,
                context: returning ? .returningSignIn : .account,
                requestID: requestID
            )
        } catch ServiceFailure.cancelled, is CancellationError {
            guard authenticationRequestID == requestID else { return }
            isResolvingAccount = false
            accountOperationStage = .idle
            clearPendingAuthentication()
            return
        } catch {
            guard isCurrentAuthentication(requestID, returning: returning) else { return }
            isResolvingAccount = false
            authenticationError = safeMessage(from: error, fallback: "We couldn't sign you in. Try again.")
        }
    }

    func retryAuthentication() async {
        if case .resolving = accountOperationStage, pendingUserID != nil {
            await retryAccountResolution()
            return
        }
        guard let pendingAuthenticationProvider else { return }
        await authenticate(
            with: pendingAuthenticationProvider,
            returning: pendingAuthenticationIsReturning
        )
    }

    func retryAccountResolution() async {
        guard let pendingUserID else { return }
        let requestID = UUID()
        authenticationRequestID = requestID
        authenticationError = nil
        isResolvingAccount = true
        defer {
            if authenticationRequestID == requestID {
                isResolvingAccount = false
            }
        }
        let context: BackendUserEntryContext = pendingAuthenticationIsReturning
            ? .returningSignIn
            : .account
        accountOperationStage = .resolving(userID: pendingUserID, context: context)
        do {
            try await resolveBackendUser(
                userID: pendingUserID,
                context: context,
                requestID: requestID
            )
        } catch ServiceFailure.cancelled, is CancellationError {
            return
        } catch {
            guard isCurrentAuthentication(
                requestID,
                returning: pendingAuthenticationIsReturning
            ) else { return }
            authenticationError = safeMessage(from: error, fallback: "We couldn't check your account. Try again.")
        }
    }

    func preparePhoto(data: Data) async {
        guard step == .photoPreparation, isCompletingOnboarding == false else { return }
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
        guard step == .photoPreparation, isCompletingOnboarding == false else { return false }
        let requestID = UUID()
        photoAcquisitionRequestID = requestID
        photoError = nil
        guard dependencies.cameraAccess.isAvailable() else {
            photoError = "A camera isn't available here. Choose a photo from your library instead."
            return false
        }

        switch dependencies.cameraAccess.authorizationState() {
        case .authorized:
            return isCurrentPhotoAcquisition(requestID)
        case .notDetermined:
            let granted = await dependencies.cameraAccess.requestAccess()
            guard isCurrentPhotoAcquisition(requestID) else { return false }
            guard granted else {
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
        guard step == .photoPreparation, isCompletingOnboarding == false else { return }
        let requestID = UUID()
        photoAcquisitionRequestID = requestID
        photoError = nil
        do {
            guard let data = try await loadData() else {
                guard isCurrentPhotoAcquisition(requestID) else { return }
                photoError = "This photo couldn't be opened. Choose another one."
                return
            }
            guard isCurrentPhotoAcquisition(requestID) else { return }
            await preparePhoto(data: data)
        } catch is CancellationError {
            return
        } catch {
            guard isCurrentPhotoAcquisition(requestID) else { return }
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

    func skipHarmonyCheck() { beginOnboardingCompletion(from: .photoPreparation) }

    func retryAnalysis() {
        guard analysisCanRetry else { return }
        startAnalysis()
    }

    func showMatchingStyle() {
        guard draft.preparedPhoto != nil else { return }
        phase = .onboarding(.generationProcessing)
        startGeneration()
    }

    func skipLook() { beginOnboardingCompletion(from: .harmonySnapshot) }
    func retryGeneration() {
        guard generationCanRetry else { return }
        startGeneration()
    }
    func tryMore() { beginOnboardingCompletion(from: .firstResult) }

    func retryOnboardingCompletion() {
        guard case .completing(_, let initiatingStep) = accountOperationStage else { return }
        beginOnboardingCompletion(from: initiatingStep)
    }

    func cancelOnboardingCompletion() {
        completionTask?.cancel()
    }

    func retryAccessHandoff() {
        guard case .accessPending(let userID) = accountOperationStage else { return }
        startAccessHandoff(for: userID)
    }

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
        invalidateOnboardingCompletion()
        photoError = "Your photo was cleared to free memory. Please choose it again."
        phase = .onboarding(.photoPreparation)
    }

    func setComparisonSplit(_ value: Double) {
        comparisonSplit = min(max(value, 0.12), 0.88)
    }

    private func resolveBackendUser(
        userID: String,
        context: BackendUserEntryContext,
        requestID: UUID
    ) async throws {
        authenticationError = nil
        accountOperationStage = .resolving(userID: userID, context: context)
        isResolvingAccount = true
        let resolution = try await dependencies.backendUser.resolveCurrentUser()
        try requireCurrentResolution(requestID, context: context)
        isResolvingAccount = false
        currentUserID = userID
        try await applyResolution(resolution, userID: userID, context: context)
    }

    private func applyResolution(
        _ resolution: BackendUserResolution,
        userID: String,
        context: BackendUserEntryContext
    ) async throws {
        guard resolution.origin != .created || resolution.onboardingCompleted == false else {
            throw ServiceFailure.transport("The account service returned an unusable response. Try again.")
        }

        if resolution.onboardingCompleted {
            clearPendingAuthentication()
            enterAccessPending(for: userID)
            await performAccessHandoff(
                for: userID,
                progressAnnouncement: "Your account is ready. Verifying your access."
            )
            return
        }

        accountOperationStage = .idle
        switch context {
        case .launch, .account:
            announce("Your account is ready.")
            clearPendingAuthentication()
            phase = .onboarding(.photoPreparation)
        case .returningSignIn:
            clearPendingAuthentication()
            if resolution.origin == .created {
                let notice = "This account hasn't completed onboarding yet. Start onboarding to create your first look."
                returningAccountNotice = notice
                announce(notice)
                phase = .onboarding(.returningSignIn)
            } else {
                announce("Your account is ready.")
                phase = .onboarding(.photoPreparation)
            }
        }
    }

    private func beginOnboardingCompletion(from initiatingStep: OnboardingStep) {
        guard step == initiatingStep, let currentUserID, isCompletingOnboarding == false else { return }
        if initiatingStep == .photoPreparation {
            invalidatePhotoAcquisition()
        }
        completionTask?.cancel()
        let requestID = UUID()
        completionRequestID = requestID
        accountOperationStage = .completing(userID: currentUserID, step: initiatingStep)
        completionError = nil
        isCompletingOnboarding = true
        completionTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.dependencies.backendUser.completeOnboarding()
                try Task.checkCancellation()
                guard self.isCurrentCompletion(requestID, step: initiatingStep) else {
                    self.clearStaleCompletionState(for: requestID)
                    return
                }
                self.isCompletingOnboarding = false
                self.enterAccessPending(for: currentUserID)
                await self.performAccessHandoff(
                    for: currentUserID,
                    progressAnnouncement: "Onboarding complete. Verifying your access."
                )
            } catch is CancellationError {
                guard self.completionRequestID == requestID else { return }
                self.isCompletingOnboarding = false
            } catch {
                guard self.isCurrentCompletion(requestID, step: initiatingStep) else {
                    self.clearStaleCompletionState(for: requestID)
                    return
                }
                self.isCompletingOnboarding = false
                self.completionError = self.safeMessage(
                    from: error,
                    fallback: "We couldn't finish setting up your account. Try again."
                )
            }
        }
    }

    private func enterAccessPending(for userID: String) {
        accountOperationStage = .accessPending(userID: userID)
        accessError = nil
        clearPhotoDerivedState()
        phase = .postOnboardingAccess
    }

    private func startAccessHandoff(for userID: String) {
        accessTask?.cancel()
        accessTask = Task { [weak self] in
            await self?.performAccessHandoff(for: userID)
        }
    }

    private func performAccessHandoff(
        for userID: String,
        progressAnnouncement: String = "Verifying your access."
    ) async {
        let requestID = UUID()
        accessRequestID = requestID
        accountOperationStage = .accessPending(userID: userID)
        accessError = nil
        isVerifyingAccess = true
        announce(progressAnnouncement)
        do {
            let evaluation = try await accessCoordinator.bindAndEvaluateAccess(for: userID)
            try Task.checkCancellation()
            guard isCurrentAccess(requestID, userID: userID) else { return }
            isVerifyingAccess = false
            startMonitoringAccessUpdates()
            switch evaluation {
            case .active:
                accountOperationStage = .idle
                announce("Access verified.")
                grantMainAccess()
            case .inactive:
                accountOperationStage = .idle
                announce("Access verified. Choose a plan to continue.")
                enterPaywall()
            case .signedOut:
                accessError = "Sign in again to verify your access."
            }
        } catch is CancellationError {
            guard accessRequestID == requestID else { return }
            isVerifyingAccess = false
            accessError = "Access verification was interrupted. Try again."
        } catch {
            guard isCurrentAccess(requestID, userID: userID) else { return }
            isVerifyingAccess = false
            accessError = safeMessage(from: error, fallback: "We couldn't verify your access. Try again.")
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
        if hasPhotoDerivedState {
            clearPhotoDerivedState()
        }
        phase = .main
    }

    private var hasPhotoDerivedState: Bool {
        draft.preparedPhoto != nil
            || draft.harmonyResult != nil
            || draft.generatedLook != nil
            || analysisPhase.isLoading
            || generationPhase.isLoading
            || comparisonSplit != 0.46
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
        invalidatePhotoAcquisition()
        analysisRequestID = UUID()
        generationRequestID = UUID()
    }

    private func invalidatePhotoAcquisition() {
        photoAcquisitionRequestID = UUID()
        photoPreparationRequestID = UUID()
    }

    private func isCurrentPhotoAcquisition(_ requestID: UUID) -> Bool {
        photoAcquisitionRequestID == requestID
            && step == .photoPreparation
            && isCompletingOnboarding == false
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
        returningAccountNotice = nil
        isAuthenticating = false
        isResolvingAccount = false
        if case .resolving = accountOperationStage {
            accountOperationStage = .idle
        }
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

    private func requireCurrentResolution(
        _ requestID: UUID,
        context: BackendUserEntryContext
    ) throws {
        guard isCurrentResolution(requestID, context: context) else {
            throw CancellationError()
        }
    }

    private func isCurrentResolution(
        _ requestID: UUID,
        context: BackendUserEntryContext
    ) -> Bool {
        guard authenticationRequestID == requestID else { return false }
        switch context {
        case .launch:
            return phase == .bootstrapping
        case .account:
            return phase == .onboarding(.account)
        case .returningSignIn:
            return phase == .onboarding(.returningSignIn)
        }
    }

    private func isCurrentCompletion(_ requestID: UUID, step: OnboardingStep) -> Bool {
        completionRequestID == requestID && phase == .onboarding(step)
    }

    private func invalidateOnboardingCompletion() {
        completionTask?.cancel()
        completionRequestID = UUID()
        isCompletingOnboarding = false
        completionError = nil
        if case .completing = accountOperationStage {
            accountOperationStage = .idle
        }
    }

    private func clearStaleCompletionState(for requestID: UUID) {
        guard completionRequestID == requestID else { return }
        isCompletingOnboarding = false
        if case .completing = accountOperationStage {
            accountOperationStage = .idle
        }
    }

    private func isCurrentAccess(_ requestID: UUID, userID: String) -> Bool {
        accessRequestID == requestID
            && phase == .postOnboardingAccess
            && accountOperationStage == .accessPending(userID: userID)
    }

    private func safeMessage(from error: Error, fallback: String) -> String {
        if let failure = error as? ServiceFailure, let description = failure.errorDescription {
            return description
        }
        return fallback
    }
}
