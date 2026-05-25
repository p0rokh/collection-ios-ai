import UIKit
import QuartzCore

/// Управляет одной анимацией коллапса и предоставляет её прогресс в реальном времени.
///
/// `CollapseTracker` — внутренняя утилита UIKit-слоя; она не является частью
/// публичного API. Координатор создаёт один tracker на пакет удалений и разделяет
/// его между всеми ячейками этого пакета, чтобы одна `CABasicAnimation` синхронно
/// управляла всеми параллельными коллапсами. Tracker удерживается живым внутри
/// `PendingExplosion` через RAII: его `deinit` удаляет `CALayer` из контейнера,
/// поэтому очистка происходит автоматически при отбрасывании последней
/// ожидающей записи.
final class CollapseTracker {

    static let initialHeight: CGFloat = 1000

    private let layer = CALayer()
    private weak var container: UIView?

    init(container: UIView) {
        self.container = container
        // Слой располагается далеко за пределами экрана, чтобы никогда не быть
        // видимым; важно только анимированное значение `bounds.size.height`,
        // читаемое через `presentation()`.
        layer.frame = CGRect(x: -10_000, y: -10_000, width: 1, height: Self.initialHeight)
        container.layer.addSublayer(layer)
    }

    /// Запускает анимацию коллапса высоты и вызывает `completion` по её завершении.
    ///
    /// Анимация идёт от `initialHeight` до `0` за `duration` секунд с кривой
    /// ease-in, соответствующей ощущению быстрого коллапса.
    func start(duration: TimeInterval, completion: @escaping () -> Void) {
        let anim = CABasicAnimation(keyPath: "bounds.size.height")
        anim.fromValue = Self.initialHeight
        anim.toValue = 0
        anim.duration = duration
        anim.timingFunction = CAMediaTimingFunction(name: .easeIn)
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false
        layer.add(anim, forKey: "shrink")

        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeIn))
        CATransaction.setCompletionBlock(completion)
        CATransaction.commit()
    }

    /// Возвращает текущий прогресс анимации как долю в `[0, 1]`.
    ///
    /// `1.0` означает, что анимация только началась (полная высота); `0.0` —
    /// что она завершена (нулевая высота). Координатор умножает эту долю на
    /// исходную высоту ячейки, вычисляя, сколько точек ячейки ещё видно.
    func currentFraction() -> CGFloat {
        let presentHeight = layer.presentation()?.bounds.size.height ?? Self.initialHeight
        return max(0, min(1, presentHeight / Self.initialHeight))
    }

    deinit {
        layer.removeFromSuperlayer()
    }
}
