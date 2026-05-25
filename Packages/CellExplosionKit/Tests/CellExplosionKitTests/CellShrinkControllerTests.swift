import XCTest
import UIKit
@testable import CellExplosionKit

final class CellShrinkControllerTests: XCTestCase {

    func test_apply_layoutSubviews_noLockedHeight_doesNothing() {
        let controller = CellShrinkController()
        let contentView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 60))
        let cellBounds = CGRect(x: 0, y: 0, width: 100, height: 60)
        controller.apply(toContentView: contentView, cellBounds: cellBounds)
        XCTAssertEqual(contentView.frame, CGRect(x: 0, y: 0, width: 100, height: 60))
    }

    func test_apply_whenCellShorterThanLocked_pinsContentToBottom() {
        let controller = CellShrinkController()
        let attr = CollapsibleLayoutAttributes(forCellWith: IndexPath(item: 0, section: 0))
        attr.lockedHeight = 60
        controller.apply(layoutAttributes: attr)

        let contentView = UIView(frame: .zero)
        let cellBounds = CGRect(x: 0, y: 0, width: 100, height: 20)  // schлопнулась до 20
        controller.apply(toContentView: contentView, cellBounds: cellBounds)

        XCTAssertEqual(contentView.bounds.size, CGSize(width: 100, height: 60))
        XCTAssertEqual(contentView.center, CGPoint(x: 50, y: 20 + 60/2))
    }

    func test_apply_whenCellTallerThanLocked_doesNothing() {
        let controller = CellShrinkController()
        let attr = CollapsibleLayoutAttributes(forCellWith: IndexPath(item: 0, section: 0))
        attr.lockedHeight = 60
        controller.apply(layoutAttributes: attr)

        let contentView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 60))
        let cellBounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        let originalFrame = contentView.frame
        controller.apply(toContentView: contentView, cellBounds: cellBounds)

        XCTAssertEqual(contentView.frame, originalFrame)
    }

    func test_reset_clearsLockedHeight() {
        let controller = CellShrinkController()
        let attr = CollapsibleLayoutAttributes(forCellWith: IndexPath(item: 0, section: 0))
        attr.lockedHeight = 60
        controller.apply(layoutAttributes: attr)
        controller.reset()

        let contentView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 60))
        let cellBounds = CGRect(x: 0, y: 0, width: 100, height: 20)
        let originalFrame = contentView.frame
        controller.apply(toContentView: contentView, cellBounds: cellBounds)

        XCTAssertEqual(contentView.frame, originalFrame, "after reset, behaves as no-op")
    }

    func test_apply_nonCollapsibleAttributes_doesNotAffect() {
        let controller = CellShrinkController()
        let attr = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: 0, section: 0))
        controller.apply(layoutAttributes: attr)

        let contentView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 60))
        let cellBounds = CGRect(x: 0, y: 0, width: 100, height: 20)
        let originalFrame = contentView.frame
        controller.apply(toContentView: contentView, cellBounds: cellBounds)

        XCTAssertEqual(contentView.frame, originalFrame)
    }
}
