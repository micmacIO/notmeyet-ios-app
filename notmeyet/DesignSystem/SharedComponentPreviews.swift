#if DEBUG
import SwiftUI

#Preview("Default") {
    SharedPreviewCanvas {
        ScreenHeading(
            eyebrow: "Preview",
            title: "Choose what fits",
            subtitle: "Shared controls use native text styles and full-width targets."
        )
        ChoiceButton(
            title: "A subtle change",
            detail: "A cleaner version of the current look",
            isSelected: false,
            isMultiple: false,
            identifier: "preview.choice.default",
            action: {}
        )
        Button("Continue") {}
            .buttonStyle(.nmyPrimary)
    }
}

#Preview("Selected") {
    SharedPreviewCanvas {
        ChoiceButton(
            title: "Noticeable",
            detail: "Clearly different, but still easy to wear",
            isSelected: true,
            isMultiple: false,
            identifier: "preview.choice.single",
            action: {}
        )
        ChoiceButton(
            title: "I can't picture a new style",
            detail: nil,
            isSelected: true,
            isMultiple: true,
            identifier: "preview.choice.multiple",
            action: {}
        )
    }
}

#Preview("Loading") {
    SharedPreviewCanvas {
        VStack(spacing: 12) {
            ProgressView()
            Text("Creating your first look...")
                .font(NMYDesign.Typography.choice)
        }
        .frame(maxWidth: .infinity)
        .nmyCard()
        Button("Please wait") {}
            .buttonStyle(.nmyPrimary)
            .disabled(true)
    }
}

#Preview("Error") {
    SharedPreviewCanvas {
        NMYErrorPanel(
            message: "We couldn't create your look. Try again.",
            retryTitle: "Try again",
            retry: {}
        )
    }
}

#Preview("Success") {
    SharedPreviewCanvas {
        Label("Your look is ready", systemImage: "checkmark.circle.fill")
            .font(NMYDesign.Typography.control)
            .foregroundStyle(NMYDesign.success)
            .frame(maxWidth: .infinity, alignment: .leading)
            .nmyCard()
    }
}

#Preview("Accessibility Size") {
    ScrollView {
        SharedPreviewCanvas {
            ScreenHeading(
                title: "Controls reflow at larger sizes",
                subtitle: "Long descriptions wrap instead of shrinking or clipping."
            )
            ChoiceButton(
                title: "Feel more confident about my appearance",
                detail: "A longer description remains readable at accessibility sizes.",
                isSelected: true,
                isMultiple: false,
                identifier: "preview.choice.accessibility",
                action: {}
            )
            NMYErrorPanel(
                message: "The action could not be completed. You can safely try again.",
                retryTitle: "Try again",
                retry: {}
            )
            Button("Continue") {}
                .buttonStyle(.nmyPrimary)
        }
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

private struct SharedPreviewCanvas<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(NMYDesign.horizontalInset)
        .frame(maxWidth: 430, alignment: .leading)
        .background(NMYDesign.background)
        .foregroundStyle(NMYDesign.foreground)
    }
}
#endif
