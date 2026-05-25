//
//  MessageViewController.swift
//  CollectionDemo
//
//  Created by Антон Королев on 24.05.2026.
//

import UIKit
import SnapKit

final class MessageViewController: UIViewController {

    private var dataSource: [Message] = demoMessages

    private lazy var deleteItem = UIBarButtonItem(
        image: UIImage(systemName: "arrow.down.message"),
        style: .plain,
        target: self,
        action: #selector(deleteHandler)
    )

    private lazy var deleteMiddleItem = UIBarButtonItem(
        image: UIImage(systemName: "scissors"),
        style: .plain,
        target: self,
        action: #selector(deleteMiddleHandler)
    )

    private lazy var deleteMultipleItem = UIBarButtonItem(
        image: UIImage(systemName: "rectangle.stack.badge.minus"),
        style: .plain,
        target: self,
        action: #selector(deleteMultipleHandler)
    )

    private lazy var messageCollectionView: MessageCollectionView = {
        let collectionView = MessageCollectionView(frame: .zero, collectionViewLayout: MessageFlowLayout())
        collectionView.dataSource = self
        return collectionView
    }()

    private lazy var explosionView: ExplosionView = {
        let v = ExplosionView(frame: view.bounds)
        v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return v
    }()

    private lazy var explosionAnimator = CellExplosionAnimator(
        collectionView: messageCollectionView,
        explosionView: explosionView,
        container: view
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItems = [deleteItem, deleteMiddleItem, deleteMultipleItem]
        view.addSubview(messageCollectionView)
        messageCollectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        view.addSubview(explosionView)
        _ = explosionAnimator
    }

    @objc private func deleteHandler() {
        guard !dataSource.isEmpty else { return }
        delete(at: [IndexPath(item: 0, section: 0)])
    }

    @objc private func deleteMiddleHandler() {
        guard !dataSource.isEmpty else { return }
        delete(at: [IndexPath(item: dataSource.count / 2, section: 0)])
    }

    @objc private func deleteMultipleHandler() {
        guard dataSource.count >= 3 else { return }
        let indices = [0, dataSource.count / 2, dataSource.count - 1]
        delete(at: indices.map { IndexPath(item: $0, section: 0) })
    }

    private func delete(at indexPaths: [IndexPath]) {
        explosionAnimator.explodeAndDelete(at: indexPaths) {
            for path in indexPaths.sorted(by: { $0.item > $1.item }) {
                dataSource.remove(at: path.item)
            }
        }
    }
}

extension MessageViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        dataSource.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: MessageCollectionCell.reuseIdentifier,
            for: indexPath
        ) as! MessageCollectionCell
        cell.configure(with: dataSource[indexPath.item])
        return cell
    }
}
