//
//  MessageViewController.swift
//  CollectionDemo
//

import UIKit
import SnapKit
import CellExplosionKit

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

    private let collapseController = CellCollapseLayoutController(configuration: .default)

    private lazy var messageCollectionView: MessageCollectionView = {
        let layout = MessageFlowLayout(collapseController: collapseController)
        let cv = MessageCollectionView(frame: .zero, collectionViewLayout: layout)
        cv.dataSource = self
        return cv
    }()

    private lazy var renderer = SpriteKitParticleRenderer(configuration: .default)

    private lazy var explosionCoordinator = CellExplosionCoordinator(
        collectionView: messageCollectionView,
        container: view,
        renderer: renderer,
        layoutController: collapseController,
        snapshotProvider: FlippedCellSnapshotProvider(),
        configuration: .default
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItems = [deleteItem, deleteMiddleItem, deleteMultipleItem]
        view.addSubview(messageCollectionView)
        messageCollectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        view.addSubview(renderer.view)
        renderer.view.frame = view.bounds
        renderer.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        _ = explosionCoordinator
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
        for path in indexPaths.sorted(by: { $0.item > $1.item }) {
            dataSource.remove(at: path.item)
        }

        // Определяем какие cells будут двигаться. Двигаются те, у кого старый
        // item > минимального удалённого и сами они не в deleted set.
        let minDeletedItem = indexPaths.map(\.item).min() ?? 0
        let deletedSet = Set(indexPaths)
        let movingCells = messageCollectionView.visibleCells.filter { cell in
            guard let p = messageCollectionView.indexPath(for: cell) else { return false }
            return p.item > minDeletedItem && !deletedSet.contains(p)
        }

        // Единый бесшовный таймлайн на трёх синхронных частях:
        //  1) UICollectionView collapse — задаём через UIView.animate (только
        //     UIKit-уровень реально форсит duration deleteItems). Длительность =
        //     totalDuration × collapseFraction.
        //  2) CollapseTracker внутри пакета — синхронизируем, передав ту же
        //     duration в coordinator.configuration.collapseDuration (иначе burst
        //     рассчитается по 0.3s по умолчанию и опоздает).
        //  3) CAKeyframeAnimation на transform.translation.y у двигающихся cells —
        //     длится totalDuration, до collapseFraction остаётся 0, затем один
        //     отскок вверх и обратно. Запускаем animation ДО UIView.animate в
        //     том же RunLoop turn — обе стартуют синхронно.
        let totalDuration: CFTimeInterval = 0.33
        let collapseFraction: Double = 0.45
        let collapseDuration = totalDuration * collapseFraction

        explosionCoordinator.configuration.collapseDuration = collapseDuration
        // При быстром коллапсе (≈100мс) и burstThreshold=12 окно срабатывания
        // получается ~8мс, меньше шага CADisplayLink (~16.7мс) — burst иногда
        // «проскакивает» между тиками. Поднимаем порог, чтобы окно стало шире
        // и burst срабатывал ещё пока cell видна, в районе её половинной высоты.
        explosionCoordinator.configuration.burstThreshold = 30

        let bounce = CAKeyframeAnimation(keyPath: "transform.translation.y")
        bounce.values   = [0, 0, 4.0, 0, 0]
        bounce.keyTimes = [
            0,
            NSNumber(value: collapseFraction),
            NSNumber(value: collapseFraction + 0.10),
            NSNumber(value: collapseFraction + 0.25),
            1,
        ]
        bounce.duration = totalDuration
        // Per-segment curves: точное соответствие моментов keyframe реальному
        // времени (глобальный timingFunction сделал бы нелинейную развёртку).
        //   1) до приземления — linear (значение всё равно 0).
        //   2) подъём 0 → 4.0 — easeOut (быстро от наковальни, тормоз в пике).
        //   3) падение 4.0 → 0 — easeIn (с пика медленно, к низу — gravity).
        //   4) после приземления — linear, держим 0.
        bounce.timingFunctions = [
            CAMediaTimingFunction(name: .linear),
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeIn),
            CAMediaTimingFunction(name: .linear),
        ]

        for cell in movingCells {
            cell.layer.add(bounce, forKey: "anvil-bounce")
        }

        UIView.animate(
            withDuration: collapseDuration,
            delay: 0,
            options: [.curveEaseIn],
            animations: {
                self.messageCollectionView.performBatchUpdates {
                    self.messageCollectionView.deleteItems(at: indexPaths)
                }
            },
            completion: nil
        )
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
