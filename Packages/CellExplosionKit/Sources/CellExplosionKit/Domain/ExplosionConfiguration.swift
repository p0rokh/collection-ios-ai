import Foundation
import CoreGraphics

/// Tunable parameters that govern the particle burst and height-collapse animations.
///
/// `ExplosionConfiguration` lives in the Domain layer and is shared by every
/// other layer: `ParticleFactory` uses it to spawn particles, `ParticlePhysics`
/// uses it each frame to evolve them, `CellCollapseLayoutController` uses
/// `collapseDuration`, and `CellExplosionCoordinator` uses `burstThreshold`.
///
/// Start with `.default`, which reproduces the reference demo tuning, and adjust
/// individual fields as needed. Mutations are applied to the next explosion batch;
/// in-flight animations always finish with the configuration that was active when
/// they started.
public struct ExplosionConfiguration {
    /// Edge length of each particle square, in logical points. Smaller values
    /// produce finer-grained bursts at the cost of more particles.
    public var chunkSize: CGFloat
    /// Base launch speed of particles, in points per second.
    public var speed: CGFloat
    /// Acceleration applied to vertical velocity each second, in points per second².
    /// Negative values pull particles upward (UIKit Y-down convention).
    public var gravity: CGFloat
    /// Per-frame velocity multiplier in `(0, 1)`. Values close to 1 let particles
    /// travel farther before stopping; lower values kill momentum quickly.
    public var damping: CGFloat
    /// Extra upward bias added to each particle's initial vertical velocity, in
    /// points per second. Produces the characteristic upward "pop" of the burst.
    public var upBias: CGFloat
    /// Maximum wobble displacement along each axis, in points.
    public var wobbleAmplitude: CGFloat
    /// Base wobble oscillation frequency, in Hz. Each particle randomises this
    /// within ±50 % to avoid a uniform wave appearance.
    public var wobbleFrequency: CGFloat
    /// Random range for particle lifetime, in seconds. Shorter lifetimes make the
    /// burst dissipate faster; `alphaDecay` is derived from the sampled value.
    public var lifetimeRange: ClosedRange<CGFloat>
    /// Duration of the cell height-collapse animation, in seconds.
    public var collapseDuration: TimeInterval
    /// Remaining visible height of a collapsing cell, in points, at which the
    /// particle burst is triggered. Lower values delay the burst until the cell is
    /// nearly gone; higher values burst earlier while more of the cell is visible.
    public var burstThreshold: CGFloat

    public init(
        chunkSize: CGFloat,
        speed: CGFloat,
        gravity: CGFloat,
        damping: CGFloat,
        upBias: CGFloat,
        wobbleAmplitude: CGFloat,
        wobbleFrequency: CGFloat,
        lifetimeRange: ClosedRange<CGFloat>,
        collapseDuration: TimeInterval,
        burstThreshold: CGFloat
    ) {
        self.chunkSize = chunkSize
        self.speed = speed
        self.gravity = gravity
        self.damping = damping
        self.upBias = upBias
        self.wobbleAmplitude = wobbleAmplitude
        self.wobbleFrequency = wobbleFrequency
        self.lifetimeRange = lifetimeRange
        self.collapseDuration = collapseDuration
        self.burstThreshold = burstThreshold
    }

    /// The reference configuration used in the CellExplosionKit demo project.
    ///
    /// Use this as a baseline and tune individual properties to match your app's
    /// visual style.
    public static let `default`: ExplosionConfiguration = .init(
        chunkSize: 1,
        speed: 60,
        gravity: -50,
        damping: 0.985,
        upBias: 50,
        wobbleAmplitude: 300,
        wobbleFrequency: 0.85,
        lifetimeRange: 0.1...0.8,
        collapseDuration: 0.3,
        burstThreshold: 12
    )
}
