import UIKit
import SpriteKit

final class SpriteKitParticleScene: SKScene {

    var configuration: ExplosionConfiguration = .default

    private var particles: [Particle] = []
    private var nodes: [SKSpriteNode] = []
    private var dead: [Bool] = []
    private var aliveCount: Int = 0
    private var lastTime: TimeInterval = 0

    func addParticles(_ newParticles: [Particle]) {
        let h = size.height
        for p in newParticles {
            let node = SKSpriteNode(
                color: UIColor(cgColor: p.color),
                size: CGSize(width: p.size, height: p.size)
            )
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
