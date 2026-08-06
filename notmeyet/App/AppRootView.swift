//
//  ContentView.swift
//  notmeyet
//
//  Created by Michal Maczka on 04/08/2026.
//

import SwiftUI

@MainActor
struct AppRootView: View {
    @State private var model: OnboardingFlowModel
    private let shouldBootstrap: Bool

    init() {
        let dependencies = AppDependencies.make()
        #if DEBUG
        if let presentation = DebugUITestPresentation.selected(
            in: ProcessInfo.processInfo.arguments,
            configuration: dependencies.configuration
        ) {
            self.init(dependencies: dependencies, debugPresentation: presentation)
            return
        }
        #endif
        self.init(dependencies: dependencies)
    }

    init(dependencies: AppDependencies) {
        _model = State(initialValue: OnboardingFlowModel(dependencies: dependencies))
        shouldBootstrap = true
    }

    #if DEBUG
    init(dependencies: AppDependencies, debugPresentation: DebugUITestPresentation) {
        let model = OnboardingFlowModel(dependencies: dependencies)
        debugPresentation.apply(to: model)
        _model = State(initialValue: model)
        shouldBootstrap = false
    }
    #endif

    var body: some View {
        Group {
            switch model.phase {
            case .bootstrapping:
                ProgressView("Getting things ready...")
                    .accessibilityIdentifier("bootstrap.progress")
            case .onboarding(let step):
                OnboardingRouterView(step: step, model: model)
            case .main:
                MainAppSkeletonView()
            case .configurationUnavailable(let message):
                ConfigurationUnavailableView(message: message) {
                    Task { await model.retryBootstrap() }
                }
            }
        }
        .nmyAccessibilityAnnouncement(model.accessibilityAnnouncement)
        .preferredColorScheme(.light)
        .task {
            guard shouldBootstrap else { return }
            await model.bootstrap()
        }
        .onOpenURL { model.handleOpenURL($0) }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            model.handleMemoryWarning()
        }
    }
}

private struct OnboardingRouterView: View {
    let step: OnboardingStep
    let model: OnboardingFlowModel

    @ViewBuilder
    var body: some View {
        switch step {
        case .welcome:
            WelcomeScreen(model: model)
        case .primaryGoal:
            PrimaryGoalScreen(model: model)
        case .painPoints:
            PainPointsScreen(model: model)
        case .direction:
            DirectionScreen(model: model)
        case .account:
            AccountScreen(model: model)
        case .photoPreparation:
            PhotoPreparationScreen(model: model)
        case .photoReview:
            PhotoReviewScreen(model: model)
        case .analysisProcessing:
            AnalysisProcessingScreen(model: model)
        case .harmonySnapshot:
            HarmonySnapshotScreen(model: model)
        case .generationProcessing:
            GenerationProcessingScreen(model: model)
        case .firstResult:
            FirstResultScreen(model: model)
        case .paywall:
            PaywallScreen(model: model)
        case .returningSignIn:
            ReturningSignInScreen(model: model)
        }
    }
}

private struct ConfigurationUnavailableView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Configuration unavailable", systemImage: "wrench.and.screwdriver")
                .nmyRouteHeading(id: "configuration-unavailable")
        } description: {
            Text(message)
        } actions: {
            Button("Try again", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .accessibilityIdentifier("configuration.unavailable")
    }
}

struct MainAppSkeletonView: View {
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(spacing: 12) {
            Text("NotMeYet")
                .font(NMYDesign.Typography.screenTitle)
                .nmyRouteHeading(id: "main")
            Text("Main App")
                .font(NMYDesign.Typography.control)
                .foregroundStyle(NMYDesign.Accessibility.mutedColor(for: contrast))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NMYDesign.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("main.skeleton")
    }
}

#Preview("Mock onboarding") {
    #if DEBUG
    let configuration = AppConfiguration(
        mode: .mock,
        googleClientID: "",
        revenueCatAPIKey: "",
        revenueCatEntitlementID: "pro",
        looksAPIBaseURL: nil,
        termsURL: nil,
        privacyURL: nil,
        facialDataDisclosuresApproved: false
    )
    AppRootView(dependencies: .make(configuration: configuration))
    #else
    MainAppSkeletonView()
    #endif
}
