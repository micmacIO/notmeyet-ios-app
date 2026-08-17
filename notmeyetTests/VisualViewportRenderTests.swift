#if DEBUG
import SwiftUI
import UIKit
import XCTest
@testable import notmeyet

@MainActor
final class VisualViewportRenderTests: XCTestCase {
    private let presentations: [(name: String, value: DebugUITestPresentation)] = [
        ("screen-01", .screen01),
        ("screen-02", .screen02),
        ("screen-03", .screen03),
        ("screen-04", .screen04),
        ("screen-05", .screen05),
        ("screen-05-backend-resolving", .screen05BackendResolving),
        ("screen-06", .screen06),
        ("screen-06-completion-progress", .screen06CompletionProgress),
        ("screen-07", .screen07),
        ("screen-08-loading", .screen08Loading),
        ("screen-08-error", .screen08Error),
        ("screen-09", .screen09),
        ("screen-09-completion-progress", .screen09CompletionProgress),
        ("screen-10-loading", .screen10Loading),
        ("screen-10-error", .screen10Error),
        ("screen-11-success", .screen11Success),
        ("screen-11-completion-progress", .screen11CompletionProgress),
        ("screen-12-mock", .screen12Mock),
        ("screen-13", .screen13),
        ("screen-13-created-incomplete", .screen13CreatedIncomplete),
        ("access-pending-progress", .accessPendingProgress),
        ("access-failure", .accessFailure),
        ("main-skeleton", .main)
    ]

    func testRenderAtExact360x800Viewport() {
        renderPresentations(
            presentations,
            viewport: CGSize(width: 360, height: 800),
            dynamicTypeSize: nil,
            namePrefix: "synthetic"
        )
    }

    func testLifecycleActionsRemainReachableAtAccessibilityTextSize() {
        let lifecyclePresentations = presentations.filter {
            [
                "screen-05", "screen-05-backend-resolving", "screen-06",
                "screen-06-completion-progress", "screen-09",
                "screen-09-completion-progress", "screen-11-success",
                "screen-11-completion-progress", "screen-13",
                "screen-13-created-incomplete", "access-pending-progress", "access-failure"
            ].contains($0.name)
        }

        for viewport in [CGSize(width: 390, height: 844), CGSize(width: 430, height: 932)] {
            renderPresentations(
                lifecyclePresentations,
                viewport: viewport,
                dynamicTypeSize: .accessibility5,
                namePrefix: "dynamic-type-ax5"
            )
        }
    }

    func testPostOnboardingAccessAdaptivePreferences() {
        let accessPresentations = presentations.filter {
            ["access-pending-progress", "access-failure"].contains($0.name)
        }
        let viewport = CGSize(width: 390, height: 844)

        renderPresentations(
            accessPresentations,
            viewport: viewport,
            dynamicTypeSize: nil,
            colorSchemeContrast: .increased,
            namePrefix: "increased-contrast"
        )
        renderPresentations(
            accessPresentations,
            viewport: viewport,
            dynamicTypeSize: nil,
            reduceTransparency: true,
            namePrefix: "reduce-transparency"
        )
    }

    private func renderPresentations(
        _ presentations: [(name: String, value: DebugUITestPresentation)],
        viewport: CGSize,
        dynamicTypeSize: DynamicTypeSize?,
        colorSchemeContrast: ColorSchemeContrast? = nil,
        reduceTransparency: Bool? = nil,
        namePrefix: String
    ) {
        let syntheticSafeArea = UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)

        for presentation in presentations {
            let dependencies = TestDependencyHarness().makeDependencies()
            var rootView = AnyView(AppRootView(
                dependencies: dependencies,
                debugPresentation: presentation.value
            ))
            if let dynamicTypeSize {
                rootView = AnyView(rootView.environment(\.dynamicTypeSize, dynamicTypeSize))
            }
            if let colorSchemeContrast {
                rootView = AnyView(rootView.environment(\._colorSchemeContrast, colorSchemeContrast))
            }
            if let reduceTransparency {
                rootView = AnyView(
                    rootView.environment(\._accessibilityReduceTransparency, reduceTransparency)
                )
            }
            let controller = UIHostingController(rootView: rootView)
            let window = UIWindow(frame: CGRect(origin: .zero, size: viewport))
            window.rootViewController = controller
            if dynamicTypeSize != nil {
                window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
            }
            window.isHidden = false
            controller.view.frame = window.bounds
            controller.view.backgroundColor = .white
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()

            let baseInsets = controller.view.safeAreaInsets
            controller.additionalSafeAreaInsets = UIEdgeInsets(
                top: max(syntheticSafeArea.top - baseInsets.top, 0),
                left: 0,
                bottom: max(syntheticSafeArea.bottom - baseInsets.bottom, 0),
                right: 0
            )
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()

            let format = UIGraphicsImageRendererFormat()
            format.scale = 3
            format.opaque = true
            let renderer = UIGraphicsImageRenderer(size: viewport, format: format)
            var rendered = false
            let image = renderer.image { _ in
                rendered = controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
            }

            XCTAssertTrue(rendered, "Failed to render \(presentation.name)")
            XCTAssertEqual(image.size.width, viewport.width)
            XCTAssertEqual(image.size.height, viewport.height)
            XCTAssertEqual(image.scale, 3)

            let attachment = XCTAttachment(image: image)
            attachment.name = "\(namePrefix)__\(presentation.name)__\(Int(viewport.width))x\(Int(viewport.height))__safe-59-34__ios-26.2"
            attachment.lifetime = .keepAlways
            add(attachment)

            window.isHidden = true
        }
    }
}
#endif
