import UIKit
import SpriteKit

/// Внутренняя SpriteKit-сцена, владеющая всеми живыми узлами частиц и анимирующая их.
///
/// `SpriteKitParticleScene` не является частью публичного API; ею полностью управляет
/// `SpriteKitParticleRenderer`. Каждое значение `Particle`, добавленное через
/// `addParticles`, получает соответствующий `SKSpriteNode`; игровой цикл SpriteKit
/// продвигает физику через `ParticlePhysics.step` и удаляет узлы, когда они
/// становятся невидимыми или покидают видимую область.
final class SpriteKitParticleScene: SKScene {

    var configuration: ExplosionConfiguration = .default

    private var particles: [Particle] = []
    private var nodes: [SKSpriteNode] = []
    private var dead: [Bool] = []
    private var aliveCount: Int = 0
    private var lastTime: TimeInterval = 0

    /// Создаёт `SKSpriteNode` для каждой частицы и добавляет его в сцену.
    ///
    /// Координаты `Particle` используют Y-down конвенцию UIKit; преобразование
    /// `h - p.y` переводит их в координатное пространство SpriteKit (Y-up),
    /// где `h` — текущая высота сцены.
    func addParticles(_ newParticles: [Particle]) {
        let h = size.height
        for p in newParticles {
            let node = SKSpriteNode(
                color: UIColor(cgColor: p.color),
                size: CGSize(width: p.size, height: p.size)
            )
            // Particle.y хранится в пространстве UIKit (Y-down); SpriteKit использует
            // Y-up, поэтому позиция переворачивается относительно вертикальной середины сцены.
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
        // Ограничиваем dt значением 0.05 с (нижний предел 20 fps), чтобы переход
        // в фоновый режим или медленный кадр не вызывал большого скачка позиции,
        // мгновенно выбрасывающего частицы за экран.
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
                // Применяем то же преобразование UIKit Y-down → SpriteKit Y-up, что и в addParticles.
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
