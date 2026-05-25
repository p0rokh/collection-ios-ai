import UIKit

/// Custom layout attributes that carry the collapse state of a disappearing cell.
///
/// `CollapsibleLayoutAttributes` extends `UICollectionViewLayoutAttributes` with
/// two additional fields. `CellCollapseLayoutController` produces instances of this
/// class in `finalAttributes(for:base:)`; the consumer's cell reads them inside
/// `apply(_:)` via `CellShrinkController.apply(layoutAttributes:)`.
///
/// To enable this flow the consumer's `UICollectionViewFlowLayout` subclass must
/// override `layoutAttributesClass` to return `CollapsibleLayoutAttributes.self`:
/// ```swift
/// override class var layoutAttributesClass: AnyClass {
///     CollapsibleLayoutAttributes.self
/// }
/// ```
public final class CollapsibleLayoutAttributes: UICollectionViewLayoutAttributes {

    /// A fraction in `[0, 1]` representing how much of the original cell height
    /// remains visible. `1.0` means fully expanded; `0.0` means fully collapsed.
    ///
    /// When `CellCollapseLayoutController` emits final attributes for a disappearing
    /// cell, it sets this to `0` so the layout system animates the cell to zero height.
    public var collapseProgress: CGFloat = 1.0

    /// The cell's original height before collapse began, in points.
    ///
    /// `CellShrinkController` uses this to keep the content view pinned at its
    /// full height while the cell's frame shrinks, producing the visual effect of
    /// the content sliding down as the cell collapses.
    public var lockedHeight: CGFloat?

    public override func copy(with zone: NSZone? = nil) -> Any {
        let copy = super.copy(with: zone) as! CollapsibleLayoutAttributes
        copy.collapseProgress = collapseProgress
        copy.lockedHeight = lockedHeight
        return copy
    }

    /// Compares `collapseProgress` and `lockedHeight` in addition to the standard
    /// `UICollectionViewLayoutAttributes` fields.
    ///
    /// Overriding `isEqual` is required because `UICollectionView` relies on
    /// attribute equality to decide whether a given item needs its layout refreshed.
    /// Without this override the collection view would ignore changes to the custom
    /// fields and fail to drive the collapse animation.
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? CollapsibleLayoutAttributes else { return false }
        guard super.isEqual(other) else { return false }
        return collapseProgress == other.collapseProgress && lockedHeight == other.lockedHeight
    }
}
