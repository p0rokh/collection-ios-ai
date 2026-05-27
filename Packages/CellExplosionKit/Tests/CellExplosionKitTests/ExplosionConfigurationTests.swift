import XCTest
@testable import CellExplosionKit

final class ExplosionConfigurationTests: XCTestCase {

    func test_default_hasExpectedValues() {
        let config = ExplosionConfiguration.default
        XCTAssertEqual(config.chunkSize, 1)
        XCTAssertEqual(config.speed, 60)
        XCTAssertEqual(config.gravity, -50)
        XCTAssertEqual(config.damping, 0.985)
        XCTAssertEqual(config.upBias, 50)
        XCTAssertEqual(config.wobbleAmplitude, 300)
        XCTAssertEqual(config.wobbleFrequency, 0.85)
        XCTAssertEqual(config.lifetimeRange, 0.1...0.8)
        XCTAssertEqual(config.collapseDuration, 0.33 * 0.45, accuracy: 0.001)
        XCTAssertEqual(config.burstThreshold, 30)
        XCTAssertEqual(config.totalAnimationDuration, 0.33, accuracy: 0.001)
        XCTAssertEqual(config.collapseTimingFraction, 0.45, accuracy: 0.001)
    }

    func test_isValueType_mutationDoesNotAffectOriginal() {
        let original = ExplosionConfiguration.default
        var copy = original
        copy.speed = 999
        XCTAssertEqual(original.speed, 60)
        XCTAssertEqual(copy.speed, 999)
    }
}
