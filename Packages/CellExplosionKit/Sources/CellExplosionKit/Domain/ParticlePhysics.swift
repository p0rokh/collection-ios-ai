import Foundation
import CoreGraphics

enum ParticlePhysics {

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
