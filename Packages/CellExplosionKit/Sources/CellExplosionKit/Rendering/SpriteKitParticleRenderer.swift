import UIKit
import SpriteKit

public final class SpriteKitParticleRenderer: ParticleRenderer {

    private let skView: SKView
    private let scene: SpriteKitParticleScene

    public var view: UIView { skView }

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

    public func addParticles(_ particles: [Particle]) {
        // Сцена использует size SKView; перед добавлением убедимся что size актуальный.
        scene.size = skView.bounds.size
        scene.addParticles(particles)
    }
}
