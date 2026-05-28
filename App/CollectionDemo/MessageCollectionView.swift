//
//  MessageCollectionView.swift
//  CollectionDemo
//
//  Created by Антон Королев on 24.05.2026.
//

import UIKit
import CellExplosionKit

final class MessageCollectionView: ExplosionCollectionView {

    private let collapseController: CellCollapseLayoutController

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
        let components = CellExplosionKitAssembler.assemble(
            collectionView: self,
            container: container,
            layoutController: collapseController,
            snapshotProvider: FlippedCellSnapshotProvider(),
            configuration: .default
        )
        explosionCoordinator = components.coordinator
        container.addSubview(components.rendererView)
        components.rendererView.frame = container.bounds
        components.rendererView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
}
