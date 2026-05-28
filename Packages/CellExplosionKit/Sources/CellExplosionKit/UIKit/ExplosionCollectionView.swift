import UIKit

/// Базовый класс `UICollectionView` с встроенной поддержкой анимации взрыва ячеек.
///
/// Переопределяет стандартный `deleteItems(at:)`: если подключён `explosionCoordinator`,
/// автоматически запускает эффект взрыва через `CellExplosionCoordinator.performDeletion`.
/// Флаг `isExplosionInProgress` предотвращает рекурсию, возникающую из-за того,
/// что `performDeletion` внутри сам вызывает `deleteItems` через `performBatchUpdates`.
///
/// **Интеграция:**
/// 1. Унаследуйте свой `UICollectionView`-подкласс от `ExplosionCollectionView`.
/// 2. Соберите граф зависимостей через `CellExplosionKitAssembler.assemble(...)`.
/// 3. Присвойте полученный `coordinator` в `explosionCoordinator`.
/// 4. Вызывайте стандартный `deleteItems(at:)` — анимация запустится автоматически.
open class ExplosionCollectionView: UICollectionView {

    public var explosionCoordinator: CellExplosionCoordinator?

    private var isExplosionInProgress = false

    override open func deleteItems(at indexPaths: [IndexPath]) {
        guard !isExplosionInProgress, let coordinator = explosionCoordinator else {
            super.deleteItems(at: indexPaths)
            return
        }
        isExplosionInProgress = true
        coordinator.performDeletion(at: indexPaths)
        isExplosionInProgress = false
    }
}
