import UIKit

/// UIKit-расширение Domain-порта `ParticleOutput`.
///
/// Добавляет `view: UIView` — единственную UIKit-зависимость рендерера.
/// Координатор вызывает `bringSubviewToFront(renderer.view)` перед взрывом,
/// поэтому `view` существует здесь, а не в Domain-слое.
///
/// Реализация по умолчанию — `SpriteKitParticleRenderer`. Альтернативу на Metal
/// можно подключить, реализовав этот protocol и передав его в
/// `CellExplosionCoordinator.init`.
public protocol ParticleRenderer: ParticleOutput {
    /// Вид, отображающий отрендеренные частицы. Добавьте его как дочерний элемент
    /// того же контейнера, что и collection view.
    var view: UIView { get }
}
