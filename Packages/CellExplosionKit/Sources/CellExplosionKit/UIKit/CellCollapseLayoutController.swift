import UIKit

/// Receives delete-batch notifications from `CellCollapseLayoutController` before
/// layout attributes are finalized.
///
/// Implement this protocol to intercept deletion index paths and decide which ones
/// should use the explosion+collapse effect. The coordinator is the production
/// implementation; pass it as `layoutController.delegate` (which the coordinator's
/// `init` does automatically).
public protocol CellCollapseLayoutControllerDelegate: AnyObject {
    /// Called during `prepare(forCollectionViewUpdates:)` when one or more items
    /// are being deleted from the collection view.
    ///
    /// The delegate must call `controller.markCollapsing(at:)` with the subset of
    /// `indexPaths` it wants to animate before the method returns, because
    /// `finalLayoutAttributesForDisappearingItem(at:)` queries the marked set
    /// synchronously on the same run-loop turn.
    ///
    /// - Parameters:
    ///   - controller: The layout controller that detected the deletions.
    ///   - indexPaths: All index paths that are being deleted in the current batch.
    func cellCollapseLayoutController(
        _ controller: CellCollapseLayoutController,
        willProcessDeletionsAt indexPaths: [IndexPath]
    )
}

/// Composition helper that plugs the collapse animation into any existing
/// `UICollectionViewFlowLayout` subclass.
///
/// Instead of subclassing a layout provided by this package, the consumer embeds
/// `CellCollapseLayoutController` as a stored property and forwards three layout
/// override points to it:
///
/// ```swift
/// override func prepare(forCollectionViewUpdates items: [UICollectionViewUpdateItem]) {
///     super.prepare(forCollectionViewUpdates: items)
///     collapseController.prepare(updateItems: items)
/// }
///
/// override func finalizeCollectionViewUpdates() {
///     super.finalizeCollectionViewUpdates()
///     collapseController.finalize()
/// }
///
/// override func finalLayoutAttributesForDisappearingItem(
///     at itemIndexPath: IndexPath
/// ) -> UICollectionViewLayoutAttributes? {
///     let base = super.finalLayoutAttributesForDisappearingItem(at: itemIndexPath)
///     return collapseController.finalAttributes(for: itemIndexPath, base: base)
/// }
/// ```
///
/// When a deletion batch is processed, `prepare(updateItems:)` notifies `delegate`
/// (typically `CellExplosionCoordinator`), which calls back `markCollapsing(at:)`
/// for the paths it wants to animate. `finalAttributes(for:base:)` then returns
/// `CollapsibleLayoutAttributes` only for marked paths, leaving all other paths
/// with their standard disappearance attributes.
public final class CellCollapseLayoutController {

    /// The delegate that receives `willProcessDeletionsAt:` and decides which
    /// paths to animate. Set automatically by `CellExplosionCoordinator.init`.
    public weak var delegate: CellCollapseLayoutControllerDelegate?

    /// The active explosion configuration. Consumers may swap this at runtime;
    /// changes apply to the next deletion batch.
    public var configuration: ExplosionConfiguration

    private var marked: Set<IndexPath> = []

    /// Creates a layout controller with the given configuration.
    ///
    /// - Parameter configuration: Initial physics and timing parameters. Defaults
    ///   to `.default`, which matches the reference demo tuning.
    public init(configuration: ExplosionConfiguration = .default) {
        self.configuration = configuration
    }

    /// Filters delete actions from `updateItems` and notifies the delegate.
    ///
    /// Call this at the start of `prepare(forCollectionViewUpdates:)`, after
    /// calling `super`. If there are no delete items the delegate is not called.
    ///
    /// - Parameter updateItems: The full array received from
    ///   `prepare(forCollectionViewUpdates:)`.
    public func prepare(updateItems: [UICollectionViewUpdateItem]) {
        let deletePaths = updateItems.compactMap { item -> IndexPath? in
            guard item.updateAction == .delete else { return nil }
            return item.indexPathBeforeUpdate
        }
        guard !deletePaths.isEmpty else { return }
        delegate?.cellCollapseLayoutController(self, willProcessDeletionsAt: deletePaths)
    }

    /// Clears the set of marked paths at the end of the batch update.
    ///
    /// Call this inside `finalizeCollectionViewUpdates()`, after `super`. Failing
    /// to call `finalize()` will leave stale paths marked and may incorrectly
    /// suppress the standard disappearance animation in the next deletion batch.
    public func finalize() {
        marked.removeAll()
    }

    /// Marks `indexPaths` so that `finalAttributes(for:base:)` returns
    /// `CollapsibleLayoutAttributes` for them.
    ///
    /// Called by `CellExplosionCoordinator` after it has captured snapshots and
    /// is ready to drive the collapse. Paths that are not marked receive the
    /// unmodified `base` attributes and animate with the standard UICollectionView
    /// deletion transition.
    ///
    /// - Parameter indexPaths: The paths for which the collapse+explosion effect
    ///   should be applied in the current batch.
    public func markCollapsing(at indexPaths: [IndexPath]) {
        for path in indexPaths { marked.insert(path) }
    }

    /// Returns the final layout attributes for a disappearing item.
    ///
    /// For marked paths, returns `CollapsibleLayoutAttributes` with `frame.height`
    /// set to `0`, `alpha` pinned to `1` (so the cell stays visible during the
    /// coordinator-driven collapse rather than fading out via UIKit's default
    /// disappearance animation), `lockedHeight` set to the item's original height,
    /// and `collapseProgress` set to `0`. For all other paths the `base` attributes
    /// are returned unchanged.
    ///
    /// Call this at the end of `finalLayoutAttributesForDisappearingItem(at:)`,
    /// passing the value from `super` as `base`.
    ///
    /// - Parameters:
    ///   - itemIndexPath: The index path of the disappearing item.
    ///   - base: The attributes produced by the superclass, or `nil` if the
    ///     superclass has none.
    /// - Returns: Modified `CollapsibleLayoutAttributes` for marked paths, or
    ///   `base` unmodified for unmarked paths.
    public func finalAttributes(
        for itemIndexPath: IndexPath,
        base: UICollectionViewLayoutAttributes?
    ) -> UICollectionViewLayoutAttributes? {
        guard marked.contains(itemIndexPath), let base else { return base }
        if let collapsible = base as? CollapsibleLayoutAttributes {
            let initialHeight = collapsible.frame.height
            var frame = collapsible.frame
            frame.size.height = 0
            collapsible.frame = frame
            collapsible.alpha = 1
            collapsible.lockedHeight = initialHeight
            collapsible.collapseProgress = 0
            return collapsible
        }
        let copy = base.copy() as! UICollectionViewLayoutAttributes
        var frame = copy.frame
        frame.size.height = 0
        copy.frame = frame
        copy.alpha = 1
        return copy
    }
}
