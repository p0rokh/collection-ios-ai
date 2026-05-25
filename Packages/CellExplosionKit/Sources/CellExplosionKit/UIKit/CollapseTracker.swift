import UIKit
import QuartzCore

/// Drives a single collapse animation and exposes its real-time progress.
///
/// `CollapseTracker` is an internal UIKit-layer utility; it is not part of the
/// public API. The coordinator creates one tracker per delete batch and shares it
/// across all cells in that batch so a single `CABasicAnimation` drives all
/// parallel collapses uniformly. The tracker is kept alive inside
/// `PendingExplosion` via RAII: its `deinit` removes the `CALayer` from the
/// container, so cleanup is automatic when the last pending entry is discarded.
final class CollapseTracker {

    static let initialHeight: CGFloat = 1000

    private let layer = CALayer()
    private weak var container: UIView?

    init(container: UIView) {
        self.container = container
        // The layer is positioned far off-screen so it is never visible; only its
        // animated `bounds.size.height` value (read via `presentation()`) matters.
        layer.frame = CGRect(x: -10_000, y: -10_000, width: 1, height: Self.initialHeight)
        container.layer.addSublayer(layer)
    }

    /// Starts the height-collapse animation and calls `completion` when it finishes.
    ///
    /// The animation runs from `initialHeight` to `0` over `duration` seconds with
    /// an ease-in timing curve to match the feel of a fast collapse.
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

    /// Returns the current animation progress as a fraction in `[0, 1]`.
    ///
    /// `1.0` means the animation has just started (full height); `0.0` means it
    /// has completed (zero height). The coordinator multiplies this fraction by the
    /// cell's original height to compute how many points of cell remain visible.
    func currentFraction() -> CGFloat {
        let presentHeight = layer.presentation()?.bounds.size.height ?? Self.initialHeight
        return max(0, min(1, presentHeight / Self.initialHeight))
    }

    deinit {
        layer.removeFromSuperlayer()
    }
}
