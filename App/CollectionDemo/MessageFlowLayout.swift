//
//  MessageFlowLayout.swift
//  CollectionDemo
//
//  Created by Антон Королев on 24.05.2026.
//

import UIKit

class MessageFlowLayout: UICollectionViewFlowLayout {

    private var deletingIndexPaths: Set<IndexPath> = []

    override init() {
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

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let collectionView else { return false }
        return newBounds.width != collectionView.bounds.width
    }

    override func prepare(forCollectionViewUpdates updateItems: [UICollectionViewUpdateItem]) {
        super.prepare(forCollectionViewUpdates: updateItems)
        deletingIndexPaths = Set(updateItems.compactMap {
            $0.updateAction == .delete ? $0.indexPathBeforeUpdate : nil
        })
    }

    override func finalizeCollectionViewUpdates() {
        super.finalizeCollectionViewUpdates()
        deletingIndexPaths.removeAll()
    }

    override func finalLayoutAttributesForDisappearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let attributes = super.finalLayoutAttributesForDisappearingItem(at: itemIndexPath)
        guard deletingIndexPaths.contains(itemIndexPath), let attributes else {
            return attributes
        }
        var frame = attributes.frame
        frame.size.height = 0
        attributes.frame = frame
        attributes.alpha = 1
        return attributes
    }
}
