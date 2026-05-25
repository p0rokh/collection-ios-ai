import UIKit

public final class CollapsibleLayoutAttributes: UICollectionViewLayoutAttributes {

    public var collapseProgress: CGFloat = 1.0
    public var lockedHeight: CGFloat?

    public override func copy(with zone: NSZone? = nil) -> Any {
        let copy = super.copy(with: zone) as! CollapsibleLayoutAttributes
        copy.collapseProgress = collapseProgress
        copy.lockedHeight = lockedHeight
        return copy
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? CollapsibleLayoutAttributes else { return false }
        guard super.isEqual(other) else { return false }
        return collapseProgress == other.collapseProgress && lockedHeight == other.lockedHeight
    }
}
