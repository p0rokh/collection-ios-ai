import XCTest
import CoreGraphics
@testable import CellExplosionKit

final class ParticlePhysicsTests: XCTestCase {

    private func makeParticle(vx: CGFloat = 0, vy: CGFloat = 0, alpha: CGFloat = 1, alphaDecay: CGFloat = 0) -> Particle {
        Particle(
            x: 0, y: 0, vx: vx, vy: vy,
            color: UIColor.red.cgColor, size: 1,
            alpha: alpha, alphaDecay: alphaDecay,
            wAmpX: 0, wAmpY: 0, wFreqX: 0, wFreqY: 0, wPhaseX: 0, wPhaseY: 0
        )
    }

    func test_step_appliesGravityToVy() {
        var p = makeParticle(vy: 0)
        let config = ExplosionConfiguration.default  // gravity = -50
        ParticlePhysics.step(&p, dt: 1.0, configuration: config)
        // vy += (0 + gravity) * dt = -50, потом damping: -50 * 0.985 = -49.25
        XCTAssertEqual(p.vy, -49.25, accuracy: 0.01)
    }

    func test_step_appliesDampingToVelocities() {
        var p = makeParticle(vx: 100, vy: 100)
        var config = ExplosionConfiguration.default
        config.gravity = 0   // изолируем демпинг
        ParticlePhysics.step(&p, dt: 0.001, configuration: config)
        // vx ≈ 100 * 0.985 = 98.5
        XCTAssertEqual(p.vx, 98.5, accuracy: 0.01)
        XCTAssertEqual(p.vy, 98.5, accuracy: 0.01)
    }

    func test_step_advancesPosition() {
        var p = makeParticle(vx: 10, vy: 20)
        var config = ExplosionConfiguration.default
        config.gravity = 0
        config.damping = 1.0  // отключаем демпинг
        ParticlePhysics.step(&p, dt: 0.5, configuration: config)
        // x += vx * dt = 5; y += vy * dt = 10
        XCTAssertEqual(p.x, 5.0, accuracy: 0.01)
        XCTAssertEqual(p.y, 10.0, accuracy: 0.01)
    }

    func test_step_decreasesAlpha() {
        var p = makeParticle(alpha: 1.0, alphaDecay: 0.5)
        let config = ExplosionConfiguration.default
        ParticlePhysics.step(&p, dt: 1.0, configuration: config)
        // alpha = max(0, 1.0 - 0.5 * 1.0) = 0.5
        XCTAssertEqual(p.alpha, 0.5, accuracy: 0.01)
    }

    func test_step_alphaClampedAtZero() {
        var p = makeParticle(alpha: 0.1, alphaDecay: 10)
        let config = ExplosionConfiguration.default
        ParticlePhysics.step(&p, dt: 1.0, configuration: config)
        XCTAssertEqual(p.alpha, 0)
    }

    func test_step_advancesAge() {
        var p = makeParticle()
        let config = ExplosionConfiguration.default
        ParticlePhysics.step(&p, dt: 0.25, configuration: config)
        XCTAssertEqual(p.age, 0.25, accuracy: 0.001)
    }
}
