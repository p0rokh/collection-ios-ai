import XCTest
import UIKit
@testable import CellExplosionKit

private final class MockRenderer: ParticleRenderer {
    let view = UIView()
    var receivedBatches: [[Particle]] = []
    func addParticles(_ particles: [Particle]) {
        receivedBatches.append(particles)
    }
}

private final class MockSnapshotProvider: CellSnapshotProvider {
    var snapshotImage: UIImage?
    var croppedImage: UIImage?
    var snapshotCalls = 0
    var cropCalls = 0
    func snapshot(of cell: UICollectionViewCell) -> UIImage? {
        snapshotCalls += 1
        return snapshotImage
    }
    func cropBottom(of image: UIImage, toPoints points: CGFloat) -> UIImage? {
        cropCalls += 1
        return croppedImage
    }
}

final class CellExplosionCoordinatorTests: XCTestCase {

    private func makeImage(size: CGSize = CGSize(width: 4, height: 4)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func makeCollectionView() -> UICollectionView {
        UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), collectionViewLayout: UICollectionViewFlowLayout())
    }

    func test_willProcessDeletions_shouldExplodeFalse_doesNotMark() {
        let container = UIView()
        let layoutController = CellCollapseLayoutController()
        let renderer = MockRenderer()
        let snapshot = MockSnapshotProvider()
        snapshot.snapshotImage = makeImage()

        let coordinator = CellExplosionCoordinator(
            collectionView: makeCollectionView(),
            container: container,
            renderer: renderer,
            layoutController: layoutController,
            snapshotProvider: snapshot
        )
        coordinator.shouldExplode = { _ in false }
        coordinator.cellProvider = { _ in UICollectionViewCell(frame: CGRect(x: 0, y: 0, width: 100, height: 60)) }

        layoutController.prepare(updateItems: [
            TestUpdate(action: .delete, indexPath: IndexPath(item: 0, section: 0))
        ])

        XCTAssertEqual(snapshot.snapshotCalls, 0)
        XCTAssertTrue(coordinator.pendingExplosionsForTesting.isEmpty)
    }

    func test_willProcessDeletions_isEnabledFalse_doesNotMark() {
        let container = UIView()
        let layoutController = CellCollapseLayoutController()
        let renderer = MockRenderer()
        let snapshot = MockSnapshotProvider()
        snapshot.snapshotImage = makeImage()

        let coordinator = CellExplosionCoordinator(
            collectionView: makeCollectionView(),
            container: container,
            renderer: renderer,
            layoutController: layoutController,
            snapshotProvider: snapshot
        )
        coordinator.isEnabled = false
        coordinator.cellProvider = { _ in UICollectionViewCell(frame: CGRect(x: 0, y: 0, width: 100, height: 60)) }

        layoutController.prepare(updateItems: [
            TestUpdate(action: .delete, indexPath: IndexPath(item: 0, section: 0))
        ])

        XCTAssertEqual(snapshot.snapshotCalls, 0)
        XCTAssertTrue(coordinator.pendingExplosionsForTesting.isEmpty)
    }

    func test_willProcessDeletions_cellNotFound_skipsPath() {
        let container = UIView()
        let layoutController = CellCollapseLayoutController()
        let renderer = MockRenderer()
        let snapshot = MockSnapshotProvider()
        snapshot.snapshotImage = makeImage()

        let coordinator = CellExplosionCoordinator(
            collectionView: makeCollectionView(),
            container: container,
            renderer: renderer,
            layoutController: layoutController,
            snapshotProvider: snapshot
        )
        coordinator.cellProvider = { _ in nil }

        layoutController.prepare(updateItems: [
            TestUpdate(action: .delete, indexPath: IndexPath(item: 0, section: 0))
        ])

        XCTAssertEqual(snapshot.snapshotCalls, 0)
        XCTAssertTrue(coordinator.pendingExplosionsForTesting.isEmpty)
    }

    func test_willProcessDeletions_happyPath_snapshotAndMark() {
        let container = UIView()
        let layoutController = CellCollapseLayoutController()
        let renderer = MockRenderer()
        let snapshot = MockSnapshotProvider()
        snapshot.snapshotImage = makeImage()

        let cv = makeCollectionView()
        let coordinator = CellExplosionCoordinator(
            collectionView: cv,
            container: container,
            renderer: renderer,
            layoutController: layoutController,
            snapshotProvider: snapshot
        )
        let cell = UICollectionViewCell(frame: CGRect(x: 10, y: 20, width: 100, height: 60))
        cv.addSubview(cell)
        coordinator.cellProvider = { _ in cell }

        layoutController.prepare(updateItems: [
            TestUpdate(action: .delete, indexPath: IndexPath(item: 0, section: 0))
        ])

        XCTAssertEqual(snapshot.snapshotCalls, 1)
        XCTAssertEqual(coordinator.pendingExplosionsForTesting.count, 1)
        // markCollapsing был вызван:
        let base = CollapsibleLayoutAttributes(forCellWith: IndexPath(item: 0, section: 0))
        base.frame = CGRect(x: 0, y: 0, width: 100, height: 60)
        let attrs = layoutController.finalAttributes(for: IndexPath(item: 0, section: 0), base: base)
        XCTAssertTrue(attrs is CollapsibleLayoutAttributes)
    }

    func test_tick_belowThreshold_burstsAndClearsPending() {
        let container = UIView()
        let layoutController = CellCollapseLayoutController()
        let renderer = MockRenderer()
        let snapshot = MockSnapshotProvider()
        snapshot.snapshotImage = makeImage()
        snapshot.croppedImage = makeImage(size: CGSize(width: 4, height: 1))

        let cv = makeCollectionView()
        let coordinator = CellExplosionCoordinator(
            collectionView: cv,
            container: container,
            renderer: renderer,
            layoutController: layoutController,
            snapshotProvider: snapshot
        )
        let cell = UICollectionViewCell(frame: CGRect(x: 0, y: 0, width: 100, height: 60))
        cv.addSubview(cell)
        coordinator.cellProvider = { _ in cell }

        layoutController.prepare(updateItems: [
            TestUpdate(action: .delete, indexPath: IndexPath(item: 0, section: 0))
        ])
        XCTAssertEqual(coordinator.pendingExplosionsForTesting.count, 1)

        // эмулируем тик с fraction=0.1 → currentHeight = 60*0.1 = 6 < threshold(30)
        coordinator.tickForTesting(fractionOverride: 0.1)

        XCTAssertEqual(snapshot.cropCalls, 1)
        XCTAssertEqual(renderer.receivedBatches.count, 1)
        XCTAssertFalse(renderer.receivedBatches[0].isEmpty)
        XCTAssertTrue(coordinator.pendingExplosionsForTesting.isEmpty)
    }

    func test_tick_aboveThreshold_doesNotBurst() {
        let container = UIView()
        let layoutController = CellCollapseLayoutController()
        let renderer = MockRenderer()
        let snapshot = MockSnapshotProvider()
        snapshot.snapshotImage = makeImage()

        let cv = makeCollectionView()
        let coordinator = CellExplosionCoordinator(
            collectionView: cv,
            container: container,
            renderer: renderer,
            layoutController: layoutController,
            snapshotProvider: snapshot
        )
        let cell = UICollectionViewCell(frame: CGRect(x: 0, y: 0, width: 100, height: 60))
        cv.addSubview(cell)
        coordinator.cellProvider = { _ in cell }

        layoutController.prepare(updateItems: [
            TestUpdate(action: .delete, indexPath: IndexPath(item: 0, section: 0))
        ])

        // fraction=0.6 → currentHeight = 36 > threshold(30)
        coordinator.tickForTesting(fractionOverride: 0.6)

        XCTAssertEqual(snapshot.cropCalls, 0)
        XCTAssertEqual(renderer.receivedBatches.count, 0)
        XCTAssertEqual(coordinator.pendingExplosionsForTesting.count, 1)
    }
}

// Helper из CellCollapseLayoutControllerTests (повтор для изоляции теста)
private final class TestUpdate: UICollectionViewUpdateItem {
    private let _action: UICollectionViewUpdateItem.Action
    private let _path: IndexPath?
    init(action: UICollectionViewUpdateItem.Action, indexPath: IndexPath?) {
        self._action = action; self._path = indexPath
        super.init()
    }
    override var updateAction: UICollectionViewUpdateItem.Action { _action }
    override var indexPathBeforeUpdate: IndexPath? { _path }
}
