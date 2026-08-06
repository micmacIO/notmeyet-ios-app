import SwiftUI

struct WelcomeScreen: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let model: OnboardingFlowModel

    var body: some View {
        ZStack {
            Group {
                #if DEBUG
                LoopingVideoBackground(forcePoster: model.debugUsesStaticWelcomeMedia)
                #else
                LoopingVideoBackground()
                #endif
            }
                .ignoresSafeArea()
            LinearGradient(
                colors: reduceTransparency
                    ? [.black.opacity(0.55), .black.opacity(0.7), .black]
                    : [.black.opacity(0.5), .black.opacity(0.55), .black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        welcomeContent
                    } else {
                        welcomeContent
                            .containerRelativeFrame(.vertical, alignment: .bottomLeading)
                    }
                }
                .containerRelativeFrame(.horizontal)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var welcomeContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: NMYDesign.Spacing.xxLarge)
            Text("NOTMEYET")
                .font(NMYDesign.Typography.eyebrow)
                .tracking(1.4)
                .padding(.bottom, NMYDesign.Spacing.small)
            Text("See who you could be.")
                .font(NMYDesign.Typography.screenTitle)
                .tracking(-0.6)
                .nmyRouteHeading(id: "welcome")
            Text("See how your features work together and preview a hairstyle chosen for your face.")
                .font(NMYDesign.Typography.supporting)
                .foregroundStyle(contrast == .increased ? .white : .white.opacity(0.88))
                .padding(.top, 9)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                Button("Discover my next look") { model.showPrimaryGoal() }
                    .buttonStyle(.nmyPrimary)
                    .accessibilityIdentifier("welcome.discover")
                Button("Already have an account? Sign in") { model.showReturningSignIn() }
                    .buttonStyle(.nmySecondary)
                    .accessibilityIdentifier("welcome.signIn")
            }
            .padding(.top, NMYDesign.Spacing.xxLarge)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, NMYDesign.horizontalInset)
        .padding(.bottom, NMYDesign.Spacing.small)
    }
}

struct PrimaryGoalScreen: View {
    let model: OnboardingFlowModel

    var body: some View {
        OnboardingPage(step: .primaryGoal, showsBack: true, back: model.goBack) {
            ScreenHeading(
                title: "What brought you here today?",
                subtitle: "Choose the answer that feels closest. You can explore everything later."
            )
            .padding(.bottom, 22)

            VStack(spacing: 9) {
                ForEach(PrimaryGoal.allCases) { goal in
                    ChoiceButton(
                        title: goal.title,
                        detail: goal.detail,
                        isSelected: model.draft.primaryGoal == goal,
                        isMultiple: PrimaryGoal.cardinality.allowsMultipleSelections,
                        identifier: "goal.\(goal.rawValue)"
                    ) { model.togglePrimaryGoal(goal) }
                }
            }
        } actions: {
            Button("Build my preview") { model.continueFromPrimaryGoal() }
                .buttonStyle(.nmyPrimary)
                .accessibilityIdentifier("goal.continue")
        }
    }
}

struct PainPointsScreen: View {
    let model: OnboardingFlowModel

    var body: some View {
        OnboardingPage(step: .painPoints, showsBack: true, back: model.goBack) {
            ScreenHeading(
                title: "What makes changing your look difficult?",
                subtitle: "Pick as many as you want."
            )
            .padding(.bottom, 22)

            VStack(spacing: 9) {
                ForEach(PainPoint.allCases) { point in
                    ChoiceButton(
                        title: point.title,
                        detail: point.detail,
                        isSelected: model.draft.painPoints.contains(point),
                        isMultiple: PainPoint.cardinality.allowsMultipleSelections,
                        identifier: "pain.\(point.rawValue)"
                    ) { model.togglePainPoint(point) }
                }
            }
        } actions: {
            Button("That sounds like me") { model.continueFromPainPoints() }
                .buttonStyle(.nmyPrimary)
                .accessibilityIdentifier("pain.continue")
        }
    }
}

struct DirectionScreen: View {
    let model: OnboardingFlowModel

    var body: some View {
        OnboardingPage(step: .direction, showsBack: true, back: model.goBack) {
            ScreenHeading(title: "How different should your next look feel?")
                .padding(.bottom, 28)

            VStack(spacing: 11) {
                ForEach(StyleDirection.allCases) { direction in
                    ChoiceButton(
                        title: direction.title,
                        detail: direction.detail,
                        isSelected: model.draft.direction == direction,
                        isMultiple: StyleDirection.cardinality.allowsMultipleSelections,
                        identifier: "direction.\(direction.rawValue)",
                        minimumHeight: 82
                    ) { model.toggleDirection(direction) }
                }
            }
        } actions: {
            Button("Choose my direction") { model.continueFromDirection() }
                .buttonStyle(.nmyPrimary)
                .accessibilityIdentifier("direction.continue")
        }
    }
}
