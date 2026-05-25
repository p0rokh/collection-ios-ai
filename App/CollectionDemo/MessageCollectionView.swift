//
//  MessageCollectionView.swift
//  CollectionDemo
//
//  Created by Антон Королев on 24.05.2026.
//

import UIKit

class MessageCollectionView: UICollectionView {

    override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
        backgroundColor = nil
        alwaysBounceVertical = true
        transform = CGAffineTransform(scaleX: 1, y: -1)
        register(MessageCollectionCell.self, forCellWithReuseIdentifier: MessageCollectionCell.reuseIdentifier)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
