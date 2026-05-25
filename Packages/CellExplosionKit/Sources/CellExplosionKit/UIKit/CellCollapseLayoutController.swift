import UIKit

public protocol CellCollapseLayoutControllerDelegate: AnyObject {
    func cellCollapseLayoutController(
        _ controller: CellCollapseLayoutController,
        willProcessDeletionsAt indexPaths: [IndexPath]
    )
}

public final class CellCollapseLayoutController {

    public weak var delegate: CellCollapseLayoutControllerDelegate?
    public var configuration: ExplosionConfiguration

    private var marked: Set<IndexPath> = []

    public init(configuration: ExplosionConfiguration = .default) {
        self.configuration = configuration
    }

    public func prepare(updateItems: [UICollectionViewUpdateItem]) {
        let deletePaths = updateItems.compactMap { item -> IndexPath? in
            guard item.updateAction == .delete else { return nil }
            return item.indexPathBeforeUpdate
        }
        guard !deletePaths.isEmpty else { return }
        delegate?.cellCollapseLayoutController(self, willProcessDeletionsAt: deletePaths)
    }

    public func finalize() {
        marked.removeAll()
    }

    public func markCollapsing(at indexPaths: [IndexPath]) {
        for path in indexPaths { marked.insert(path) }
    }

    public func finalAttributes(
        for itemIndexPath: IndexPath,
        base: UICollectionViewLayoutAttributes?
    ) -> UICollectionViewLayoutAttributes? {
        guard let base else { return base }

        guard marked.contains(itemIndexPath) else {
            // Not marked for collapse - if it's a CollapsibleLayoutAttributes, convert back to plain
            if let collapsible = base as? CollapsibleLayoutAttributes {
                let plain = UICollectionViewLayoutAttributes(forCellWith: collapsible.indexPath)
                plain.frame = collapsible.frame
                plain.alpha = collapsible.alpha
                return plain
            }
            return base
        }

        guard let collapsible = base as? CollapsibleLayoutAttributes else {
            // Fallback: layout не настроил layoutAttributesClass — вернём base со схлопнутой
            // высотой без custom-полей (коллапс будет, но Cell без shrinkController не сможет
            // прижать content к низу — graceful degradation).
            let copy = UICollectionViewLayoutAttributes(forCellWith: base.indexPath)
            copy.frame = base.frame
            var frame = copy.frame
            frame.size.height = 0
            copy.frame = frame
            copy.alpha = 1
            return copy
        }
        let initialHeight = collapsible.frame.height
        var frame = collapsible.frame
        frame.size.height = 0
        collapsible.frame = frame
        collapsible.alpha = 1
        collapsible.lockedHeight = initialHeight
        collapsible.collapseProgress = 0
        return collapsible
    }
}
