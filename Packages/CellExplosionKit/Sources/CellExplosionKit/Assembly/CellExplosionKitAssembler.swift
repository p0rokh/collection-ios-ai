import UIKit

/// Composition root пакета CellExplosionKit.
///
/// Единственное место, которое знает о конкретных реализациях:
/// `SpriteKitParticleRenderer` и `DefaultCellSnapshotProvider`.
/// Consumer пакета вызывает `assemble(...)` и получает готовый
/// координатор — без прямой зависимости от классов рендерера.
public enum CellExplosionKitAssembler {

    public struct Components {
        /// Готовый к использованию координатор взрывов.
        public let coordinator: CellExplosionCoordinator
        /// Вид рендерера частиц. Добавьте его в иерархию контейнера
        /// и растяните на весь экран — координатор сам вызовет `bringSubviewToFront`.
        public let rendererView: UIView
    }

    /// Собирает полный граф зависимостей для эффекта взрыва ячейки.
    ///
    /// - Parameters:
    ///   - collectionView: Collection view, из которой будут удаляться элементы.
    ///   - container: Корневой вид контроллера — используется как начало координат частиц.
    ///   - layoutController: Layout-контроллер, встроенный в flow layout.
    ///   - snapshotProvider: Стратегия захвата snapshot. По умолчанию `DefaultCellSnapshotProvider`.
    ///   - configuration: Начальные параметры физики. По умолчанию `.default`.
    /// - Returns: `Components` с координатором и видом рендерера.
    public static func assemble(
        collectionView: UICollectionView,
        container: UIView,
        layoutController: CellCollapseLayoutController,
        snapshotProvider: CellSnapshotProvider = DefaultCellSnapshotProvider(),
        configuration: ExplosionConfiguration = .default
    ) -> Components {
        let renderer = SpriteKitParticleRenderer(configuration: configuration)

        let coordinator = CellExplosionCoordinator(
            collectionView: collectionView,
            container: container,
            renderer: renderer,
            layoutController: layoutController,
            snapshotProvider: snapshotProvider,
            configuration: configuration
        )

        return Components(coordinator: coordinator, rendererView: renderer.view)
    }
}
