import SwiftUI

nonisolated enum NMYDesign {
    static let background = Color(red: 250 / 255, green: 250 / 255, blue: 250 / 255)
    static let surface = Color.white
    static let foreground = Color(red: 17 / 255, green: 17 / 255, blue: 17 / 255)
    static let muted = Color(red: 107 / 255, green: 107 / 255, blue: 107 / 255)
    static let border = Color(red: 229 / 255, green: 229 / 255, blue: 229 / 255)
    static let accent = Color(red: 47 / 255, green: 111 / 255, blue: 235 / 255)
    static let success = Color(red: 23 / 255, green: 163 / 255, blue: 74 / 255)
    static let warning = Color(red: 234 / 255, green: 179 / 255, blue: 8 / 255)
    static let danger = Color(red: 220 / 255, green: 38 / 255, blue: 38 / 255)
    static let accentForeground = Color.white

    static let horizontalInset: CGFloat = 20
    static let smallRadius: CGFloat = 8
    static let mediumRadius: CGFloat = 12
    static let largeRadius: CGFloat = 16
    static let controlHeight: CGFloat = 52
    static let minimumTarget: CGFloat = 44
    static let progressHeight: CGFloat = 4

    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 20
        static let xxLarge: CGFloat = 24
        static let xxxLarge: CGFloat = 32
        static let section: CGFloat = 48
        static let hero: CGFloat = 80
    }

    enum Typography {
        static let micro = Font.caption2
        static let eyebrow = Font.caption2.weight(.bold)
        static let detail = Font.caption
        static let supporting = Font.subheadline
        static let choice = Font.footnote.weight(.semibold)
        static let body = Font.body
        static let control = Font.headline
        static let cardTitle = Font.headline.weight(.bold)
        static let screenTitle = Font.title.weight(.bold)
    }

    enum Motion {
        static let fastDuration = 0.15
        static let baseDuration = 0.2
        static let fast = Animation.timingCurve(0.2, 0, 0, 1, duration: fastDuration)
        static let standard = Animation.timingCurve(0.2, 0, 0, 1, duration: baseDuration)
    }

    enum Elevation {
        static let raisedColor = NMYDesign.foreground.opacity(0.08)
        static let raisedRadius: CGFloat = 8
        static let raisedY: CGFloat = 2
        static let focusRingWidth: CGFloat = 3
    }

    enum Accessibility {
        static func borderColor(for contrast: ColorSchemeContrast) -> Color {
            contrast == .increased ? NMYDesign.muted : NMYDesign.border
        }

        static func mutedColor(for contrast: ColorSchemeContrast) -> Color {
            contrast == .increased ? NMYDesign.foreground : NMYDesign.muted
        }

        static func successColor(for contrast: ColorSchemeContrast) -> Color {
            contrast == .increased ? NMYDesign.foreground : NMYDesign.success
        }

        static func strokeWidth(
            for contrast: ColorSchemeContrast,
            standard: CGFloat = 1,
            increased: CGFloat = 2
        ) -> CGFloat {
            contrast == .increased ? increased : standard
        }
    }
}

struct NMYPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NMYDesign.Typography.control)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(
                isEnabled ? NMYDesign.accentForeground : NMYDesign.Accessibility.mutedColor(for: contrast)
            )
            .padding(.horizontal, NMYDesign.Spacing.large)
            .padding(.vertical, NMYDesign.Spacing.small)
            .frame(maxWidth: .infinity, minHeight: NMYDesign.controlHeight)
            .background(
                isEnabled
                    ? NMYDesign.accent
                    : (contrast == .increased ? NMYDesign.surface : NMYDesign.border)
            )
            .overlay {
                if !isEnabled, contrast == .increased {
                    RoundedRectangle(cornerRadius: NMYDesign.largeRadius)
                        .stroke(
                            NMYDesign.Accessibility.borderColor(for: contrast),
                            lineWidth: NMYDesign.Accessibility.strokeWidth(for: contrast)
                        )
                }
            }
            .clipShape(.rect(cornerRadius: NMYDesign.largeRadius))
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.985 : 1))
            .animation(reduceMotion ? nil : NMYDesign.Motion.fast, value: configuration.isPressed)
    }
}

struct NMYSecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NMYDesign.Typography.control)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(NMYDesign.foreground)
            .padding(.horizontal, NMYDesign.Spacing.large)
            .padding(.vertical, NMYDesign.Spacing.small)
            .frame(maxWidth: .infinity, minHeight: NMYDesign.controlHeight)
            .background(NMYDesign.surface)
            .overlay {
                RoundedRectangle(cornerRadius: NMYDesign.largeRadius)
                    .stroke(
                        NMYDesign.Accessibility.borderColor(for: contrast),
                        lineWidth: NMYDesign.Accessibility.strokeWidth(for: contrast)
                    )
            }
            .clipShape(.rect(cornerRadius: NMYDesign.largeRadius))
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.985 : 1))
            .animation(reduceMotion ? nil : NMYDesign.Motion.fast, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == NMYPrimaryButtonStyle {
    static var nmyPrimary: NMYPrimaryButtonStyle { NMYPrimaryButtonStyle() }
}

extension ButtonStyle where Self == NMYSecondaryButtonStyle {
    static var nmySecondary: NMYSecondaryButtonStyle { NMYSecondaryButtonStyle() }
}
