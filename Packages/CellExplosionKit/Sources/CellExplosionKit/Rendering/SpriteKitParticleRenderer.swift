import UIKit
import SpriteKit

/// The default `ParticleRenderer` implementation, backed by a full-screen `SKView`.
///
/// `SpriteKitParticleRenderer` lives in the Rendering layer and depends only on
/// Domain types (`Particle`, `ExplosionConfiguration`). It wraps an `SKView` that
/// hosts `SpriteKitParticleScene`, which runs the SpriteKit game loop and calls
/// `ParticlePhysics.step` every frame.
///
/// **Setup:** Add `renderer.view` to your view hierarchy as a sibling of the
/// collection view, sized to fill the container:
/// ```swift
/// let renderer = SpriteKitParticleRenderer(configuration: .default)
/// renderer.view.frame = view.bounds
/// view.addSubview(renderer.view)
/// ```
/// The coordinator calls `bringSubviewToFront` automatically before each burst, so
/// ordering at insertion time does not matter.
public final class SpriteKitParticleRenderer: ParticleRenderer {

    private let skView: SKView
    private let scene: SpriteKitParticleScene

    /// The transparent `SKView` that displays the particle simulation.
    ///
    /// Add this to your container view and size it to fill the screen. The view is
    /// non-interactive (`isUserInteractionEnabled = false`) so it does not intercept
    /// touches on the collection view beneath it.
    public var view: UIView { skView }

    /// Creates a renderer configured with the given explosion parameters.
    ///
    /// - Parameter configuration: Controls physics constants used by the SpriteKit
    ///   game loop. Pass `.default` to match the reference demo tuning.
    public init(configuration: ExplosionConfiguration = .default) {
        let v = SKView(frame: .zero)
        v.backgroundColor = .clear
        v.allowsTransparency = true
        v.isUserInteractionEnabled = false
        v.ignoresSiblingOrder = true
        v.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let s = SpriteKitParticleScene()
        s.configuration = configuration
        s.scaleMode = .resizeFill
        s.backgroundColor = .clear

        v.presentScene(s)
        self.skView = v
        self.scene = s
    }

    /// Forwards `particles` to the underlying `SpriteKitParticleScene`.
    ///
    /// The scene size is refreshed from the current `SKView` bounds before adding
    /// nodes so that the UIKit-to-SpriteKit Y-axis conversion is always based on
    /// the actual rendered height.
    public func addParticles(_ particles: [Particle]) {
        // Sync scene size to the current SKView bounds before adding nodes so that
        // the Y-axis flip (UIKit Y-down → SpriteKit Y-up) uses the correct height.
        scene.size = skView.bounds.size
        scene.addParticles(particles)
    }
}
