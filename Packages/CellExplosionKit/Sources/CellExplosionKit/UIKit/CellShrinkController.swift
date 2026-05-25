import UIKit

public final class CellShrinkController {

    private var lockedHeight: CGFloat?

    public init() {}

    public func apply(layoutAttributes: UICollectionViewLayoutAttributes) {
        guard let collapsible = layoutAttributes as? CollapsibleLayoutAttributes else { return }
        if let locked = collapsible.lockedHeight {
            self.lockedHeight = locked
        }
    }

    public func apply(toContentView contentView: UIView, cellBounds: CGRect) {
        guard let lockedHeight, cellBounds.height < lockedHeight else { return }
        contentView.bounds = CGRect(x: 0, y: 0, width: cellBounds.width, height: lockedHeight)
        contentView.center = CGPoint(x: cellBounds.width / 2, y: cellBounds.height + lockedHeight / 2)
    }

    public func reset() {
        lockedHeight = nil
    }
}
