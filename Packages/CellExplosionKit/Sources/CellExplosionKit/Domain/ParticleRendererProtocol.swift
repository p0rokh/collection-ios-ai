import UIKit

/// The seam between the Domain layer and any particle rendering backend.
///
/// `ParticleRenderer` is the only point where Domain code depends on UIKit: the
/// `view` property exists so the coordinator can bring the renderer's overlay
/// in front of the collection view at burst time. The physics and lifecycle of
/// every particle remains entirely inside the Domain and Rendering layers.
///
/// The default implementation is `SpriteKitParticleRenderer`. A Metal-based
/// alternative can be substituted by conforming to this protocol and passing it
/// to `CellExplosionCoordinator.init`; no Domain or UIKit layer code needs to change.
public protocol ParticleRenderer: AnyObject {
    /// The view that displays rendered particles. Add it as a sibling of the
    /// collection view in the container hierarchy; the coordinator will call
    /// `bringSubviewToFront` automatically before each burst.
    var view: UIView { get }

    /// Enqueues `particles` for immediate rendering.
    ///
    /// Implementations should accept any number of calls per frame — the
    /// coordinator may call this once per deleted cell in a batch update.
    /// Particles are rendered until their `alpha` drops below the renderer's
    /// removal threshold.
    func addParticles(_ particles: [Particle])
}
