//
//  MessageFlowLayout.swift
//  CollectionDemo
//

import UIKit
import CellExplosionKit

final class MessageFlowLayout: UICollectionViewFlowLayout {

    let collapseController: CellCollapseLayoutController

    init(collapseController: CellCollapseLayoutController) {
        self.collapseController = collapseController
        super.init()
        scrollDirection = .vertical
        estimatedItemSize = CGSize(width: UIScreen.main.bounds.width, height: 60)
        minimumLineSpacing = 4
        minimumInteritemSpacing = 0
        sectionInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override class var layoutAttributesClass: AnyClass {
        CollapsibleLayoutAttributes.self
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let collectionView else { return false }
        return newBounds.width != collectionView.bounds.width
    }

    override func prepare(forCollectionViewUpdates updateItems: [UICollectionViewUpdateItem]) {
        super.prepare(forCollectionViewUpdates: updateItems)
        collapseController.prepare(updateItems: updateItems)
    }

    override func finalizeCollectionViewUpdates() {
        super.finalizeCollectionViewUpdates()
        collapseController.finalize()
    }

    override func finalLayoutAttributesForDisappearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let base = super.finalLayoutAttributesForDisappearingItem(at: itemIndexPath)
        return collapseController.finalAttributes(for: itemIndexPath, base: base)
    }
}
