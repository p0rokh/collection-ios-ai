import Foundation
import CoreGraphics

/// Pure physics integrator for a single `Particle` step.
///
/// `ParticlePhysics` is an internal Domain utility; it is not part of the public
/// API. The rendering backend calls `step(_:dt:configuration:)` once per display
/// frame for every live particle. Keeping physics in the Domain layer means an
/// alternative renderer (e.g. Metal) inherits the same motion model without
/// touching the Rendering layer.
enum ParticlePhysics {

    /// Advances `particle` by one time step.
    ///
    /// The integrator applies sinusoidal wobble forces, gravity, velocity damping,
    /// positional integration, rotation, and alpha decay — in that order.
    ///
    /// - Parameters:
    ///   - particle: The particle to mutate in place.
    ///   - dt: Elapsed time since the last frame, in seconds. Should be clamped by
    ///     the caller to avoid large jumps after backgrounding.
    ///   - configuration: Physics constants (`gravity`, `damping`, etc.) sourced
    ///     from the active `ExplosionConfiguration`.
    static func step(_ particle: inout Particle, dt: CGFloat, configuration: ExplosionConfiguration) {
        particle.age += dt

        let ax = sin(particle.age * particle.wFreqX * .pi * 2 + particle.wPhaseX) * particle.wAmpX
        let ay = sin(particle.age * particle.wFreqY * .pi * 2 + particle.wPhaseY) * particle.wAmpY

        particle.vx += ax * dt
        particle.vy += (ay + configuration.gravity) * dt
        particle.vx *= configuration.damping
        particle.vy *= configuration.damping

        particle.x += particle.vx * dt
        particle.y += particle.vy * dt

        particle.rotation += particle.vRotation * dt

        particle.alpha = max(0, particle.alpha - particle.alphaDecay * dt)
    }
}
