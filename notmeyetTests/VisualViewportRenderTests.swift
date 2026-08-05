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
        ("screen-06", .screen06),
        ("screen-07", .screen07),
        ("screen-08-loading", .screen08Loading),
        ("screen-08-error", .screen08Error),
        ("screen-09", .screen09),
        ("screen-10-loading", .screen10Loading),
        ("screen-10-error", .screen10Error),
        ("screen-11-loading", .screen11Loading),
        ("screen-11-error", .screen11Error),
        ("screen-11-success", .screen11Success),
        ("screen-12-mock", .screen12Mock),
        ("screen-13", .screen13),
        ("main-skeleton", .main)
    ]

    func testRenderAtExact360x800Viewport() {
        let viewport = CGSize(width: 360, height: 800)
        let syntheticSafeArea = UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)

        for presentation in presentations {
            let dependencies = TestDependencyHarness().makeDependencies()
            let rootView = AppRootView(
                dependencies: dependencies,
                debugPresentation: presentation.value
            )
            let controller = UIHostingController(rootView: rootView)
            let window = UIWindow(frame: CGRect(origin: .zero, size: viewport))
            window.rootViewController = controller
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
            XCTAssertEqual(image.size.width, 360)
            XCTAssertEqual(image.size.height, 800)
            XCTAssertEqual(image.scale, 3)

            let attachment = XCTAttachment(image: image)
            attachment.name = "synthetic__\(presentation.name)__360x800__safe-59-34__ios-26.2"
            attachment.lifetime = .keepAlways
            add(attachment)

            window.isHidden = true
        }
    }
}
#endif
