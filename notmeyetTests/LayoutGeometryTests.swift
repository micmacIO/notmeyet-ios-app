import CoreGraphics
import Testing
@testable import notmeyet

@Suite("Layout geometry")
struct LayoutGeometryTests {
    @Test("Aspect-fit geometry centers portrait and landscape content")
    func aspectFitGeometry() {
        let bounds = CGRect(x: 10, y: 20, width: 300, height: 300)

        #expect(
            aspectFitRect(for: CGSize(width: 100, height: 200), in: bounds)
                == CGRect(x: 85, y: 20, width: 150, height: 300)
        )
        #expect(
            aspectFitRect(for: CGSize(width: 200, height: 100), in: bounds)
                == CGRect(x: 10, y: 95, width: 300, height: 150)
        )
        #expect(aspectFitRect(for: .zero, in: bounds) == .zero)
    }
}
