import UIKit
import SpriteKit

/// Internal SpriteKit scene that owns and animates all live particle nodes.
///
/// `SpriteKitParticleScene` is not part of the public API; it is driven entirely
/// by `SpriteKitParticleRenderer`. Each `Particle` value added via `addParticles`
/// gets a corresponding `SKSpriteNode`; the SpriteKit game loop advances physics
/// via `ParticlePhysics.step` and removes nodes when they become invisible or
/// leave the visible area.
final class SpriteKitParticleScene: SKScene {

    var configuration: ExplosionConfiguration = .default

    private var particles: [Particle] = []
    private var nodes: [SKSpriteNode] = []
    private var dead: [Bool] = []
    private var aliveCount: Int = 0
    private var lastTime: TimeInterval = 0

    /// Spawns an `SKSpriteNode` for each particle and appends it to the scene.
    ///
    /// `Particle` coordinates use UIKit's Y-down convention; the conversion
    /// `h - p.y` maps them to SpriteKit's Y-up coordinate space, where `h` is
    /// the current scene height.
    func addParticles(_ newParticles: [Particle]) {
        let h = size.height
        for p in newParticles {
            let node = SKSpriteNode(
                color: UIColor(cgColor: p.color),
                size: CGSize(width: p.size, height: p.size)
            )
            // Particle.y is stored in UIKit Y-down space; SpriteKit uses Y-up,
            // so the position is flipped around the scene's vertical midpoint.
            node.position = CGPoint(x: p.x, y: h - p.y)
            addChild(node)
            nodes.append(node)
            particles.append(p)
            dead.append(false)
        }
        aliveCount += newParticles.count
    }

    override func update(_ currentTime: TimeInterval) {
        if lastTime == 0 {
            lastTime = currentTime
            return
        }
        // Clamp dt to 0.05 s (20 fps floor) so that backgrounding or a slow frame
        // never produces a huge position jump that sends particles off-screen instantly.
        let dt = CGFloat(min(0.05, currentTime - lastTime))
        lastTime = currentTime

        if particles.isEmpty { return }

        let h = size.height
        let topLimit: CGFloat = -50
        let bottomLimit = h + 50

        for i in particles.indices {
            if dead[i] { continue }

            ParticlePhysics.step(&particles[i], dt: dt, configuration: configuration)

            if particles[i].y < topLimit || particles[i].y > bottomLimit || particles[i].alpha < 0.02 {
                nodes[i].removeFromParent()
                dead[i] = true
                aliveCount -= 1
            } else {
                // Apply the same UIKit Y-down → SpriteKit Y-up conversion used in addParticles.
                nodes[i].position = CGPoint(x: particles[i].x, y: h - particles[i].y)
                nodes[i].zRotation = -particles[i].rotation
                nodes[i].alpha = particles[i].alpha
            }
        }

        if aliveCount == 0 {
            particles.removeAll(keepingCapacity: true)
            nodes.removeAll(keepingCapacity: true)
            dead.removeAll(keepingCapacity: true)
        }
    }
}
