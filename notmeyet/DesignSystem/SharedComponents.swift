import SwiftUI
import UIKit

struct OnboardingPage<Content: View, Actions: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let step: OnboardingStep
    let showsBack: Bool
    let back: () -> Void
    let navigationTitle: String?
    let trailingNavigationTitle: String?
    let trailingNavigationIdentifier: String?
    let trailingNavigationDisabled: Bool
    let trailingNavigationAction: () -> Void
    let pinsActions: Bool
    let content: Content
    let actions: Actions

    init(
        step: OnboardingStep,
        showsBack: Bool = false,
        back: @escaping () -> Void = {},
        navigationTitle: String? = nil,
        trailingNavigationTitle: String? = nil,
        trailingNavigationIdentifier: String? = nil,
        trailingNavigationDisabled: Bool = false,
        trailingNavigationAction: @escaping () -> Void = {},
        pinsActions: Bool = true,
        @ViewBuilder content: () -> Content,
        @ViewBuilder actions: () -> Actions
    ) {
        self.step = step
        self.showsBack = showsBack
        self.back = back
        self.navigationTitle = navigationTitle
        self.trailingNavigationTitle = trailingNavigationTitle
        self.trailingNavigationIdentifier = trailingNavigationIdentifier
        self.trailingNavigationDisabled = trailingNavigationDisabled
        self.trailingNavigationAction = trailingNavigationAction
        self.pinsActions = pinsActions
        self.content = content()
        self.actions = actions()
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize || !pinsActions {
                ScrollView {
                    VStack(spacing: 0) {
                        pageContent
                        actionFooter
                    }
                }
                .scrollIndicators(.hidden)
            } else {
                ScrollView {
                    pageContent
                }
                .scrollIndicators(.hidden)
                .safeAreaInset(edge: .bottom) {
                    actionFooter
                }
            }
        }
        .background(NMYDesign.background)
        .foregroundStyle(NMYDesign.foreground)
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsNavigation { navigation }
            if step.progress != nil { OnboardingProgressView(step: step) }
            content
                .padding(.bottom, pinsActions ? NMYDesign.Spacing.xxLarge : NMYDesign.Spacing.small)
        }
        .padding(.horizontal, NMYDesign.horizontalInset)
        .frame(maxWidth: 500)
        .frame(maxWidth: .infinity)
    }

    private var actionFooter: some View {
        actions
            .padding(.horizontal, NMYDesign.horizontalInset)
            .padding(.top, pinsActions ? NMYDesign.Spacing.medium : 0)
            .padding(.bottom, NMYDesign.Spacing.small)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
            .background(NMYDesign.background)
    }

    @ViewBuilder
    private var navigation: some View {
        ZStack {
            HStack(spacing: 0) {
                if showsBack {
                    Button(action: back) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .frame(width: NMYDesign.minimumTarget, height: NMYDesign.minimumTarget)
                            .contentShape(.circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                    .accessibilityIdentifier("navigation.back")
                } else {
                    Color.clear.frame(width: NMYDesign.minimumTarget, height: NMYDesign.minimumTarget)
                }
                Spacer()
                if let trailingNavigationTitle {
                    Button(action: trailingNavigationAction) {
                        Text(trailingNavigationTitle)
                            .font(NMYDesign.Typography.detail)
                            .foregroundStyle(NMYDesign.muted)
                            .frame(minHeight: NMYDesign.minimumTarget)
                            .contentShape(.rect)
                    }
                    .disabled(trailingNavigationDisabled)
                    .accessibilityIdentifier(trailingNavigationIdentifier ?? "navigation.trailing")
                } else {
                    Color.clear.frame(width: NMYDesign.minimumTarget, height: NMYDesign.minimumTarget)
                }
            }

            if let navigationTitle {
                Text(navigationTitle)
                    .font(NMYDesign.Typography.supporting.bold())
            }
        }
        .padding(.top, 2)
    }

    private var showsNavigation: Bool {
        showsBack || navigationTitle != nil || trailingNavigationTitle != nil
    }
}

struct OnboardingProgressView: View {
    @Environment(\.colorSchemeContrast) private var contrast
    let step: OnboardingStep

    var body: some View {
        if let progress = step.progress {
            ProgressView(value: progress)
                .tint(NMYDesign.accent)
                .background(NMYDesign.Accessibility.borderColor(for: contrast))
                .clipShape(.capsule)
                .frame(height: NMYDesign.progressHeight)
                .padding(.top, 2)
                .padding(.bottom, 24)
                .accessibilityLabel("Onboarding progress")
                .accessibilityValue("\(Int(progress * 100)) percent")
                .accessibilityIdentifier("onboarding.progress")
        }
    }
}

struct ScreenHeading: View {
    @Environment(\.colorSchemeContrast) private var contrast
    let eyebrow: String?
    let title: String
    let subtitle: String?

    init(eyebrow: String? = nil, title: String, subtitle: String? = nil) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NMYDesign.Spacing.small) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(NMYDesign.Typography.eyebrow)
                    .tracking(1.2)
                    .foregroundStyle(contrast == .increased ? NMYDesign.foreground : NMYDesign.accentText)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(NMYDesign.Typography.screenTitle)
                .tracking(-0.5)
                .accessibilityValue(eyebrow ?? "")
                .nmyRouteHeading(id: title)
            if let subtitle {
                Text(subtitle)
                    .font(NMYDesign.Typography.supporting)
                    .foregroundStyle(NMYDesign.Accessibility.mutedColor(for: contrast))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct ChoiceButton: View {
    @Environment(\.colorSchemeContrast) private var contrast
    let title: String
    let detail: String?
    let isSelected: Bool
    let isMultiple: Bool
    let identifier: String
    let minimumHeight: CGFloat
    let action: () -> Void

    init(
        title: String,
        detail: String?,
        isSelected: Bool,
        isMultiple: Bool,
        identifier: String,
        minimumHeight: CGFloat = 54,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.detail = detail
        self.isSelected = isSelected
        self.isMultiple = isMultiple
        self.identifier = identifier
        self.minimumHeight = minimumHeight
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: NMYDesign.Spacing.medium) {
                selectionIndicator
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(NMYDesign.Typography.choice)
                        .multilineTextAlignment(.leading)
                    if let detail {
                        Text(detail)
                            .font(NMYDesign.Typography.detail)
                            .foregroundStyle(NMYDesign.Accessibility.mutedColor(for: contrast))
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .leading)
            .background(
                isSelected
                    ? NMYDesign.accent.opacity(contrast == .increased ? 0.14 : 0.07)
                    : NMYDesign.surface
            )
            .overlay {
                RoundedRectangle(cornerRadius: NMYDesign.largeRadius)
                    .stroke(
                        isSelected ? NMYDesign.accent : NMYDesign.Accessibility.borderColor(for: contrast),
                        lineWidth: NMYDesign.Accessibility.strokeWidth(
                            for: contrast,
                            standard: isSelected ? 1.5 : 1,
                            increased: isSelected ? 3 : 2
                        )
                    )
            }
            .clipShape(.rect(cornerRadius: NMYDesign.largeRadius))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityInputLabels([title])
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private var selectionIndicator: some View {
        if isMultiple {
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? NMYDesign.accent : .clear)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            isSelected ? NMYDesign.accent : NMYDesign.Accessibility.mutedColor(for: contrast),
                            lineWidth: NMYDesign.Accessibility.strokeWidth(
                                for: contrast,
                                standard: 1.5,
                                increased: 2.5
                            )
                        )
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(NMYDesign.Typography.detail.bold())
                            .foregroundStyle(NMYDesign.accentForeground)
                    }
                }
                .frame(width: 20, height: 20)
        } else {
            Circle()
                .fill(isSelected ? NMYDesign.accent : .clear)
                .overlay {
                    Circle().stroke(
                        isSelected ? NMYDesign.accent : NMYDesign.Accessibility.mutedColor(for: contrast),
                        lineWidth: NMYDesign.Accessibility.strokeWidth(
                            for: contrast,
                            standard: 1.5,
                            increased: 2.5
                        )
                    )
                    if isSelected {
                        Circle()
                            .fill(NMYDesign.accentForeground)
                            .frame(width: NMYDesign.Spacing.small, height: NMYDesign.Spacing.small)
                    }
                }
                .frame(width: 20, height: 20)
        }
    }
}

struct NMYErrorPanel: View {
    @Environment(\.colorSchemeContrast) private var contrast
    let message: String
    let retryTitle: String?
    let retry: (() -> Void)?

    init(message: String, retryTitle: String? = nil, retry: (() -> Void)? = nil) {
        self.message = message
        self.retryTitle = retryTitle
        self.retry = retry
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: NMYDesign.Spacing.xSmall) {
                Label("Something went wrong", systemImage: "exclamationmark.triangle.fill")
                    .font(NMYDesign.Typography.supporting.bold())
                Text(message).font(NMYDesign.Typography.detail)
            }
            .accessibilityElement(children: .combine)
            if let retryTitle, let retry {
                Button(retryTitle, action: retry)
                    .buttonStyle(.nmySecondary)
                    .accessibilityIdentifier("error.retry")
            }
        }
        .foregroundStyle(contrast == .increased ? NMYDesign.foreground : NMYDesign.dangerText)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(contrast == .increased ? NMYDesign.surface : NMYDesign.danger.opacity(0.07))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    NMYDesign.danger.opacity(contrast == .increased ? 1 : 0.4),
                    lineWidth: NMYDesign.Accessibility.strokeWidth(for: contrast)
                )
        }
        .clipShape(.rect(cornerRadius: 14))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("error.panel")
    }
}

struct LegalLinksView: View {
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let termsURL: URL?
    let privacyURL: URL?
    @State private var unavailable = false

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 0))
            : AnyLayout(HStackLayout(spacing: 6))

        layout {
            legalAction("Terms of Use", url: termsURL)
            Text("and").foregroundStyle(NMYDesign.Accessibility.mutedColor(for: contrast))
            legalAction("Privacy Policy", url: privacyURL)
        }
        .font(NMYDesign.Typography.detail)
        .frame(maxWidth: .infinity)
        .alert("Unavailable in this build", isPresented: $unavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The final legal document will be available when production configuration is supplied.")
        }
    }

    @ViewBuilder
    private func legalAction(_ title: String, url: URL?) -> some View {
        if let url {
            Link(destination: url) {
                Text(title)
                    .foregroundStyle(NMYDesign.foreground)
                    .frame(minHeight: NMYDesign.minimumTarget)
                    .contentShape(.rect)
            }
            .accessibilityIdentifier(title == "Terms of Use" ? "legal.terms" : "legal.privacy")
        } else {
            Button { unavailable = true } label: {
                Text(title)
                    .foregroundStyle(NMYDesign.foreground)
                    .underline()
                    .frame(minHeight: NMYDesign.minimumTarget)
                    .contentShape(.rect)
            }
            .accessibilityIdentifier(title == "Terms of Use" ? "legal.terms" : "legal.privacy")
        }
    }
}

extension View {
    func nmyCard(padding: CGFloat = NMYDesign.Spacing.large) -> some View {
        modifier(NMYCardModifier(padding: padding))
    }

    func nmyAdaptiveSurface(_ color: Color, opacity: Double) -> some View {
        modifier(NMYAdaptiveSurfaceModifier(color: color, opacity: opacity))
    }

    func nmyAccessibilityAnnouncement(_ announcement: NMYAccessibilityAnnouncement?) -> some View {
        modifier(NMYAccessibilityAnnouncementModifier(announcement: announcement))
    }

    func nmyRouteHeading(id: String) -> some View {
        modifier(NMYRouteHeadingModifier(id: id))
    }
}

private struct NMYCardModifier: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(NMYDesign.surface)
            .overlay {
                RoundedRectangle(cornerRadius: NMYDesign.largeRadius)
                    .stroke(
                        NMYDesign.Accessibility.borderColor(for: contrast),
                        lineWidth: NMYDesign.Accessibility.strokeWidth(for: contrast)
                    )
            }
            .clipShape(.rect(cornerRadius: NMYDesign.largeRadius))
    }
}

private struct NMYAdaptiveSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let color: Color
    let opacity: Double

    func body(content: Content) -> some View {
        content.background(reduceTransparency ? color : color.opacity(opacity))
    }
}

private struct NMYAccessibilityAnnouncementModifier: ViewModifier {
    let announcement: NMYAccessibilityAnnouncement?

    func body(content: Content) -> some View {
        content.task(id: announcement?.id) {
            guard let announcement else { return }
            await Task.yield()
            guard !Task.isCancelled else { return }
            let queuedMessage = NSAttributedString(
                string: announcement.message,
                attributes: [
                    NSAttributedString.Key.accessibilitySpeechAnnouncementPriority: UIAccessibilityPriority.low
                ]
            )
            UIAccessibility.post(notification: .announcement, argument: queuedMessage)
        }
    }
}

private struct NMYRouteHeadingModifier: ViewModifier {
    let id: String
    @AccessibilityFocusState(for: .voiceOver) private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .accessibilityAddTraits(.isHeader)
            .accessibilityFocused($isFocused)
            .accessibilityIdentifier("screen.heading")
            .task(id: id) {
                isFocused = false
                await Task.yield()
                guard !Task.isCancelled else { return }
                isFocused = true
            }
    }
}
