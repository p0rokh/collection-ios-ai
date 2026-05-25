import XCTest
import CoreGraphics
import UIKit
@testable import CellExplosionKit

final class ParticleFactoryTests: XCTestCase {

    private func makeOpaqueRedImage(size: CGSize) -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let img = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return img.cgImage!
    }

    private func makeFullyTransparentImage(size: CGSize) -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let img = renderer.image { _ in
            // ничего не рисуем — прозрачно
        }
        return img.cgImage!
    }

    func test_makeParticles_fromTransparentImage_returnsEmpty() {
        let cg = makeFullyTransparentImage(size: CGSize(width: 10, height: 10))
        let parts = ParticleFactory.makeParticles(
            from: cg, scale: 1, origin: .zero, configuration: .default
        )
        XCTAssertEqual(parts.count, 0)
    }

    func test_makeParticles_fromOpaqueRed_returnsExpectedCount() {
        // 10×10 image, chunkSize=1 (= chunkPixels=1 при scale=1)
        // → 10*10 = 100 частиц
        let cg = makeOpaqueRedImage(size: CGSize(width: 10, height: 10))
        let parts = ParticleFactory.makeParticles(
            from: cg, scale: 1, origin: .zero, configuration: .default
        )
        XCTAssertEqual(parts.count, 100)
    }

    func test_makeParticles_offsetByOrigin() {
        let cg = makeOpaqueRedImage(size: CGSize(width: 2, height: 2))
        let origin = CGPoint(x: 100, y: 200)
        let parts = ParticleFactory.makeParticles(
            from: cg, scale: 1, origin: origin, configuration: .default
        )
        XCTAssertFalse(parts.isEmpty)
        // все x >= 100, y >= 200
        XCTAssertTrue(parts.allSatisfy { $0.x >= 100 && $0.y >= 200 })
    }

    func test_makeParticles_alphaDecayMatchesLifetime() {
        let cg = makeOpaqueRedImage(size: CGSize(width: 1, height: 1))
        var config = ExplosionConfiguration.default
        config.lifetimeRange = 1.0...1.0  // фиксированный lifetime = 1
        let parts = ParticleFactory.makeParticles(
            from: cg, scale: 1, origin: .zero, configuration: config
        )
        XCTAssertEqual(parts.count, 1)
        XCTAssertEqual(parts[0].alphaDecay, 1.0, accuracy: 0.01)
    }
}
