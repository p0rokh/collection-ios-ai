import UIKit
import QuartzCore

final class CollapseTracker {

    static let initialHeight: CGFloat = 1000

    private let layer = CALayer()
    private weak var container: UIView?

    init(container: UIView) {
        self.container = container
        layer.frame = CGRect(x: -10_000, y: -10_000, width: 1, height: Self.initialHeight)
        container.layer.addSublayer(layer)
    }

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

    /// Возвращает текущее значение [0, 1], где 1 = только начали, 0 = коллапс завершён.
    func currentFraction() -> CGFloat {
        let presentHeight = layer.presentation()?.bounds.size.height ?? Self.initialHeight
        return max(0, min(1, presentHeight / Self.initialHeight))
    }

    deinit {
        layer.removeFromSuperlayer()
    }
}
