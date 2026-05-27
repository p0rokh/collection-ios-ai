//
//  MessageCollectionView.swift
//  CollectionDemo
//
//  Created by Антон Королев on 24.05.2026.
//

import UIKit
import CellExplosionKit

final class MessageCollectionView: UICollectionView {

    private let collapseController: CellCollapseLayoutController
    private lazy var renderer = SpriteKitParticleRenderer(configuration: .default)
    private var explosionCoordinator: CellExplosionCoordinator?

    init() {
        let ctrl = CellCollapseLayoutController(configuration: .default)
        collapseController = ctrl
        super.init(frame: .zero, collectionViewLayout: MessageFlowLayout(collapseController: ctrl))
        backgroundColor = nil
        alwaysBounceVertical = true
        transform = CGAffineTransform(scaleX: 1, y: -1)
        register(MessageCollectionCell.self, forCellWithReuseIdentifier: MessageCollectionCell.reuseIdentifier)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Подключает анимацию взрыва к иерархии видов. Вызывать из `viewDidLoad` хост-контроллера.
    /// `container` — корневой вид контроллера: renderer.view добавляется поверх него,
    /// чтобы частицы не обрезались границами коллекции.
    func configure(container: UIView) {
        explosionCoordinator = CellExplosionCoordinator(
            collectionView: self,
            container: container,
            renderer: renderer,
            layoutController: collapseController,
            snapshotProvider: FlippedCellSnapshotProvider(),
            configuration: .default
        )
        container.addSubview(renderer.view)
        renderer.view.frame = container.bounds
        renderer.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    /// Удаляет элементы с анимацией взрыва. Data source должен быть обновлён до вызова.
    func delete(at indexPaths: [IndexPath]) {
        explosionCoordinator?.performDeletion(at: indexPaths)
    }
}
