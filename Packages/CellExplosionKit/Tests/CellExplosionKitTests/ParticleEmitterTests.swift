import XCTest
import UIKit
@testable import CellExplosionKit

private final class MockRendererForEmitter: ParticleRenderer {
    let view = UIView()
    var receivedBatches: [[Particle]] = []
    func addParticles(_ particles: [Particle]) { receivedBatches.append(particles) }
}

private final class MockSnapshotForEmitter: CellSnapshotProvider {
    var croppedImage: UIImage?
    func snapshot(of cell: UICollectionViewCell) -> UIImage? { nil }
    func cropBottom(of image: UIImage, toPoints points: CGFloat) -> UIImage? { croppedImage }
}

final class ParticleEmitterTests: XCTestCase {

    private func makeImage(size: CGSize = CGSize(width: 4, height: 4)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    func test_tick_aboveThreshold_doesNotBurst() {
        let container = UIView()
        let renderer = MockRendererForEmitter()
        let snapshot = MockSnapshotForEmitter()
        let emitter = ParticleEmitter(renderer: renderer, snapshotProvider: snapshot, container: container)

        let image = makeImage()
        emitter.addExplosion(ParticleEmitter.PendingExplosion(
            image: image,
            originalFrame: CGRect(x: 0, y: 0, width: 100, height: 60),
            initialHeight: 60,
            tracker: CollapseTracker(container: container)
        ))

        // fraction=0.7 → currentHeight = 42 > burstThreshold(30)
        emitter.tickForTesting(fractionOverride: 0.7, configuration: .default)

        XCTAssertEqual(renderer.receivedBatches.count, 0)
        XCTAssertEqual(emitter.pendingCountForTesting, 1)
    }

    func test_tick_belowThreshold_burstsAndClears() {
        let container = UIView()
        let renderer = MockRendererForEmitter()
        let snapshot = MockSnapshotForEmitter()
        snapshot.croppedImage = makeImage(size: CGSize(width: 4, height: 1))
        let emitter = ParticleEmitter(renderer: renderer, snapshotProvider: snapshot, container: container)

        let image = makeImage()
        emitter.addExplosion(ParticleEmitter.PendingExplosion(
            image: image,
            originalFrame: CGRect(x: 0, y: 0, width: 100, height: 60),
            initialHeight: 60,
            tracker: CollapseTracker(container: container)
        ))

        // fraction=0.1 → currentHeight = 6 < burstThreshold(30)
        emitter.tickForTesting(fractionOverride: 0.1, configuration: .default)

        XCTAssertEqual(renderer.receivedBatches.count, 1)
        XCTAssertFalse(renderer.receivedBatches[0].isEmpty)
        XCTAssertEqual(emitter.pendingCountForTesting, 0)
    }
}
