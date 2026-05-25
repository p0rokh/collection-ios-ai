import XCTest
import UIKit
@testable import CellExplosionKit

final class CollapsibleLayoutAttributesTests: XCTestCase {

    func test_defaultValues() {
        let attr = CollapsibleLayoutAttributes(forCellWith: IndexPath(item: 0, section: 0))
        XCTAssertEqual(attr.collapseProgress, 1)
        XCTAssertNil(attr.lockedHeight)
    }

    func test_copy_preservesCustomFields() {
        let attr = CollapsibleLayoutAttributes(forCellWith: IndexPath(item: 5, section: 0))
        attr.collapseProgress = 0.42
        attr.lockedHeight = 120

        let copy = attr.copy() as! CollapsibleLayoutAttributes
        XCTAssertEqual(copy.collapseProgress, 0.42)
        XCTAssertEqual(copy.lockedHeight, 120)
        XCTAssertEqual(copy.indexPath, IndexPath(item: 5, section: 0))
    }

    func test_equality_consideringCustomFields() {
        let a = CollapsibleLayoutAttributes(forCellWith: IndexPath(item: 0, section: 0))
        let b = CollapsibleLayoutAttributes(forCellWith: IndexPath(item: 0, section: 0))
        a.collapseProgress = 0.5
        b.collapseProgress = 0.5
        XCTAssertEqual(a, b)
        b.collapseProgress = 0.6
        XCTAssertNotEqual(a, b)
    }
}
