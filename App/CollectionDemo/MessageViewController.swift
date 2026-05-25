//
//  MessageViewController.swift
//  CollectionDemo
//
//  Created by Антон Королев on 24.05.2026.
//

import UIKit
import SnapKit

class MessageViewController: UIViewController {
    
    private var dataSource: [Message] = demoMessages
    
    private lazy var deleteItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: UIImage(systemName: "arrow.down.message"),
            style: .plain,
            target: self,
            action: #selector(deleteHandler)
        )
        return item
    }()

    private lazy var deleteMiddleItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: UIImage(systemName: "scissors"),
            style: .plain,
            target: self,
            action: #selector(deleteMiddleHandler)
        )
        return item
    }()

    private lazy var deleteMultipleItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: UIImage(systemName: "rectangle.stack.badge.minus"),
            style: .plain,
            target: self,
            action: #selector(deleteMultipleHandler)
        )
        return item
    }()

    private lazy var messageCollectionView: MessageCollectionView = {
        let flowLayout = MessageFlowLayout()
        let collectionView = MessageCollectionView(frame: .zero, collectionViewLayout: flowLayout)
        collectionView.delegate = self
        collectionView.dataSource = self
        return collectionView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItems = [deleteItem, deleteMiddleItem, deleteMultipleItem]
        
        view.addSubview(messageCollectionView)
        messageCollectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    @objc func deleteHandler() {
        guard !dataSource.isEmpty else { return }
        let index = 0
        dataSource.removeFirst()
        UIView.animate(withDuration: 0.40, delay: 0, options: .curveEaseOut) {
            self.messageCollectionView.performBatchUpdates {
                self.messageCollectionView.deleteItems(at: [IndexPath(item: index, section: 0)])
            }
        }
    }

    @objc func deleteMiddleHandler() {
        guard !dataSource.isEmpty else { return }
        let index = dataSource.count / 2
        dataSource.remove(at: index)
        UIView.animate(withDuration: 0.40, delay: 0, options: .curveEaseOut) {
            self.messageCollectionView.performBatchUpdates {
                self.messageCollectionView.deleteItems(at: [IndexPath(item: index, section: 0)])
            }
        }
    }

    @objc func deleteMultipleHandler() {
        guard dataSource.count >= 3 else { return }
        let indices = [0, dataSource.count / 2, dataSource.count - 1]
        for index in indices.sorted(by: >) {
            dataSource.remove(at: index)
        }
        let indexPaths = indices.map { IndexPath(item: $0, section: 0) }
        UIView.animate(withDuration: 0.40, delay: 0, options: .curveEaseOut) {
            self.messageCollectionView.performBatchUpdates {
                self.messageCollectionView.deleteItems(at: indexPaths)
            }
        }
    }
}

extension MessageViewController: UICollectionViewDelegate {

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
