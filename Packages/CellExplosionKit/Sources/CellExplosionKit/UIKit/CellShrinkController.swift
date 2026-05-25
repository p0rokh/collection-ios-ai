import UIKit

/// Composition helper that keeps a cell's content view pinned to the bottom edge
/// while the cell's frame shrinks during the collapse animation.
///
/// Embed `CellShrinkController` as a stored property in any `UICollectionViewCell`
/// subclass and forward two layout override points and `prepareForReuse`:
///
/// ```swift
/// private let shrinkController = CellShrinkController()
///
/// override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
///     super.apply(layoutAttributes)
///     shrinkController.apply(layoutAttributes: layoutAttributes)
/// }
///
/// override func layoutSubviews() {
///     super.layoutSubviews()
///     shrinkController.apply(toContentView: contentView, cellBounds: bounds)
/// }
///
/// override func prepareForReuse() {
///     super.prepareForReuse()
///     shrinkController.reset()
/// }
/// ```
///
/// When no `CollapsibleLayoutAttributes` are present (e.g., during normal scrolling
/// or when the layout controller is not wired up) `CellShrinkController` is a
/// complete no-op and adds no overhead.
public final class CellShrinkController {

    private var lockedHeight: CGFloat?

    public init() {}

    /// Reads `lockedHeight` from `layoutAttributes` if they are `CollapsibleLayoutAttributes`.
    ///
    /// Call this inside `apply(_:)`, after `super`. If `layoutAttributes` is not a
    /// `CollapsibleLayoutAttributes` instance the method does nothing.
    ///
    /// - Parameter layoutAttributes: The attributes delivered by the layout.
    public func apply(layoutAttributes: UICollectionViewLayoutAttributes) {
        guard let collapsible = layoutAttributes as? CollapsibleLayoutAttributes else { return }
        if let locked = collapsible.lockedHeight {
            self.lockedHeight = locked
        }
    }

    /// Repositions `contentView` so that its bottom edge stays aligned with the
    /// bottom of the original (pre-collapse) cell area while the cell's frame
    /// shrinks upward.
    ///
    /// Call this inside `layoutSubviews()`, after `super`. When the current
    /// `cellBounds.height` is less than `lockedHeight`, the content view is given
    /// its original size and shifted downward to remain "anchored" at the bottom —
    /// producing the effect of content staying put while the top of the cell
    /// collapses.
    ///
    /// The implementation sets `bounds` and `center` rather than `frame` to
    /// preserve any `transform` applied to the content view. In chat-style
    /// collections the cell has a `transform.scaleY(-1)` flip applied, and setting
    /// `frame` directly would apply in the parent's (pre-transform) space and
    /// produce incorrect layout.
    ///
    /// - Parameters:
    ///   - contentView: The cell's `contentView` to reposition.
    ///   - cellBounds: The cell's current `bounds`, which shrinks as the collapse
    ///     animation progresses.
    public func apply(toContentView contentView: UIView, cellBounds: CGRect) {
        guard let lockedHeight, cellBounds.height < lockedHeight else { return }
        contentView.bounds = CGRect(x: 0, y: 0, width: cellBounds.width, height: lockedHeight)
        contentView.center = CGPoint(x: cellBounds.width / 2, y: cellBounds.height + lockedHeight / 2)
    }

    /// Clears the stored locked height.
    ///
    /// Call this inside `prepareForReuse()` to prevent a reused cell from briefly
    /// applying collapse geometry from a previous deletion.
    public func reset() {
        lockedHeight = nil
    }
}
