import XCTest
import UIKit
@testable import CellExplosionKit

private final class TestUpdateItem: UICollectionViewUpdateItem {
    private let _action: UICollectionViewUpdateItem.Action
    private let _indexPathBeforeUpdate: IndexPath?

    init(action: UICollectionViewUpdateItem.Action, indexPathBeforeUpdate: IndexPath?) {
        self._action = action
        self._indexPathBeforeUpdate = indexPathBeforeUpdate
        super.init()
    }

    override var updateAction: UICollectionViewUpdateItem.Action { _action }
    override var indexPathBeforeUpdate: IndexPath? { _indexPathBeforeUpdate }
}

private final class CapturingDelegate: CellCollapseLayoutControllerDelegate {
    var captured: [IndexPath] = []
    func cellCollapseLayoutController(
        _ controller: CellCollapseLayoutController,
        willProcessDeletionsAt indexPaths: [IndexPath]
    ) {
        captured = indexPaths
    }
}

final class CellCollapseLayoutControllerTests: XCTestCase {

    func test_prepare_notifiesDelegateOnlyAboutDeletes() {
        let controller = CellCollapseLayoutController()
        let delegate = CapturingDelegate()
        controller.delegate = delegate

        let items: [UICollectionViewUpdateItem] = [
            TestUpdateItem(action: .delete, indexPathBeforeUpdate: IndexPath(item: 0, section: 0)),
            TestUpdateItem(action: .insert, indexPathBeforeUpdate: IndexPath(item: 5, section: 0)),
            TestUpdateItem(action: .delete, indexPathBeforeUpdate: IndexPath(item: 2, section: 0)),
        ]

        controller.prepare(updateItems: items)

        XCTAssertEqual(delegate.captured, [
            IndexPath(item: 0, section: 0),
            IndexPath(item: 2, section: 0),
        ])
    }

    func test_prepare_withNoDeletes_doesNotNotify() {
        let controller = CellCollapseLayoutController()
        let delegate = CapturingDelegate()
        controller.delegate = delegate

        let items: [UICollectionViewUpdateItem] = [
            TestUpdateItem(action: .insert, indexPathBeforeUpdate: nil),
        ]
        controller.prepare(updateItems: items)

        XCTAssertTrue(delegate.captured.isEmpty)
    }

    func test_finalAttributes_returnsBase_whenNotMarked() {
        let controller = CellCollapseLayoutController()
        let base = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: 0, section: 0))
        base.frame = CGRect(x: 0, y: 0, width: 100, height: 60)

        let result = controller.finalAttributes(for: IndexPath(item: 0, section: 0), base: base)

        XCTAssertNotNil(result)
        XCTAssertFalse(result is CollapsibleLayoutAttributes)
        XCTAssertEqual(result?.frame, base.frame)
    }

    func test_finalAttributes_returnsCollapsible_whenMarked() {
        let controller = CellCollapseLayoutController()
        let base = CollapsibleLayoutAttributes(forCellWith: IndexPath(item: 0, section: 0))
        base.frame = CGRect(x: 0, y: 0, width: 100, height: 60)

        controller.markCollapsing(at: [IndexPath(item: 0, section: 0)])
        let result = controller.finalAttributes(for: IndexPath(item: 0, section: 0), base: base) as? CollapsibleLayoutAttributes

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.frame.height, 0, "height collapsed to 0")
        XCTAssertEqual(result?.frame.origin, base.frame.origin)
        XCTAssertEqual(result?.lockedHeight, 60)
        XCTAssertEqual(result?.collapseProgress, 0)
    }

    func test_finalize_clearsMarkedSet() {
        let controller = CellCollapseLayoutController()
        let base = CollapsibleLayoutAttributes(forCellWith: IndexPath(item: 0, section: 0))
        base.frame = CGRect(x: 0, y: 0, width: 100, height: 60)
        controller.markCollapsing(at: [IndexPath(item: 0, section: 0)])
        controller.finalize()

        let result = controller.finalAttributes(for: IndexPath(item: 0, section: 0), base: base)
        // after finalize, marked set is cleared — base is returned untouched (height not collapsed)
        XCTAssertEqual(result?.frame.height, 60)
    }
}
