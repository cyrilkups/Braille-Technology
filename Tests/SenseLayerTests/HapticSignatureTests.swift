import XCTest
@testable import SenseLayer

final class HapticSignatureTests: XCTestCase {

    func testUrgentIsFasterThanCalm() {
        XCTAssertLessThan(
            HapticSignature.urgent.baselineTickIntervalMs,
            HapticSignature.calm.baselineTickIntervalMs
        )
    }

    func testUrgentIsSharperThanCalm() {
        XCTAssertGreaterThan(
            HapticSignature.urgent.baselineSharpness,
            HapticSignature.calm.baselineSharpness
        )
    }

    func testEmpathyOscillatesBaseline() {
        let first = HapticSignature.empathy.baselineFrame(tickIndex: 0, elapsed: 0.0)
        let second = HapticSignature.empathy.baselineFrame(tickIndex: 1, elapsed: 0.35)

        XCTAssertGreaterThan(
            abs(first.tickIntensityScale - second.tickIntensityScale),
            0.05,
            "Empathy should oscillate over time"
        )
    }

    func testAngerUsesSegmentedTicks() {
        let active = (0..<6).map {
            HapticSignature.anger.baselineFrame(tickIndex: $0, elapsed: 0).tickIsActive
        }
        XCTAssertEqual(active, [true, true, false, true, false, false])
    }

    func testCategoryDerivation() {
        XCTAssertEqual(HapticSignature.from(category: .urgent), .urgent)
        XCTAssertEqual(HapticSignature.from(category: .personal), .empathy)
        XCTAssertEqual(HapticSignature.from(category: .other), .calm)
        XCTAssertEqual(HapticSignature.from(category: .work, urgency: 0.9), .anger)
        XCTAssertEqual(HapticSignature.from(category: .work, urgency: 0.2), .neutral)
    }
}
