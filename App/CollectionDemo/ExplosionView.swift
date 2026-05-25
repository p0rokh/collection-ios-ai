//
//  ExplosionView.swift
//  CollectionDemo
//

import UIKit
import SpriteKit

final class ExplosionView: SKView {

    struct Particle {
        var x: CGFloat
        var y: CGFloat
        var vx: CGFloat
        var vy: CGFloat
        var color: CGColor
        var size: CGFloat
        var rotation: CGFloat
        var vRotation: CGFloat
        var alpha: CGFloat
        var alphaDecay: CGFloat
        var age: CGFloat
        var wAmpX: CGFloat
        var wAmpY: CGFloat
        var wFreqX: CGFloat
        var wFreqY: CGFloat
        var wPhaseX: CGFloat
        var wPhaseY: CGFloat
    }

    var gravity: CGFloat {
        get { particleScene.gravity }
        set { particleScene.gravity = newValue }
    }
    var damping: CGFloat {
        get { particleScene.damping }
        set { particleScene.damping = newValue }
    }
    var enableRotation: Bool {
        get { particleScene.enableRotation }
        set { particleScene.enableRotation = newValue }
    }

    private let particleScene = ParticleScene()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        allowsTransparency = true
        isUserInteractionEnabled = false
        ignoresSiblingOrder = true
        particleScene.size = frame.size
        particleScene.scaleMode = .resizeFill
        particleScene.backgroundColor = .clear
        presentScene(particleScene)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addParticles(_ particles: [Particle]) {
        particleScene.addParticles(particles)
    }
}

extension ExplosionView {

    static func makeParticles(
        from image: UIImage,
        at origin: CGPoint,
        chunkSize: CGFloat,
        speed: CGFloat,
        upBias: CGFloat,
        wobbleAmp: CGFloat,
        wobbleFreq: CGFloat,
        lifetimeRange: ClosedRange<CGFloat>
    ) -> [Particle] {
        guard let cgImage = image.cgImage else { return [] }
        let width = cgImage.width
        let height = cgImage.height
        let scale = image.scale
        let chunkPixels = max(1, Int(chunkSize * scale))

        var pixelData = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var particles: [Particle] = []
        particles.reserveCapacity((width / chunkPixels) * (height / chunkPixels))

        var py = 0
        while py < height {
            var px = 0
            while px < width {
                let cx = min(px + chunkPixels / 2, width - 1)
                let cy = min(py + chunkPixels / 2, height - 1)
                let i = (cy * width + cx) * 4
                let a = pixelData[i + 3]
                if a > 30 {
                    let jitter: CGFloat = 0.08
                    let r = max(0, min(1, CGFloat(pixelData[i]) / 255 + CGFloat.random(in: -jitter...jitter)))
                    let g = max(0, min(1, CGFloat(pixelData[i + 1]) / 255 + CGFloat.random(in: -jitter...jitter)))
                    let b = max(0, min(1, CGFloat(pixelData[i + 2]) / 255 + CGFloat.random(in: -jitter...jitter)))
                    let alpha = CGFloat(a) / 255
                    let color = UIColor(red: r, green: g, blue: b, alpha: alpha).cgColor
                    let angle = CGFloat.random(in: 0...(.pi * 2))
                    let sp = speed * CGFloat.random(in: 0.5...1.3)
                    let lifetime = max(0.05, CGFloat.random(in: lifetimeRange))
                    particles.append(Particle(
                        x: origin.x + CGFloat(px) / scale + chunkSize / 2,
                        y: origin.y + CGFloat(py) / scale + chunkSize / 2,
                        vx: cos(angle) * sp,
                        vy: sin(angle) * sp - upBias * CGFloat.random(in: 0.5...1.0),
                        color: color,
                        size: chunkSize,
                        rotation: 0,
                        vRotation: CGFloat.random(in: -12...12),
                        alpha: 1,
                        alphaDecay: 1.0 / lifetime,
                        age: 0,
                        wAmpX: wobbleAmp * CGFloat.random(in: 0.4...1.6),
                        wAmpY: wobbleAmp * 0.3 * CGFloat.random(in: 0.4...1.4),
                        wFreqX: wobbleFreq * CGFloat.random(in: 0.5...1.5),
                        wFreqY: wobbleFreq * CGFloat.random(in: 0.5...1.5),
                        wPhaseX: CGFloat.random(in: 0...(.pi * 2)),
                        wPhaseY: CGFloat.random(in: 0...(.pi * 2))
                    ))
                }
                px += chunkPixels
            }
            py += chunkPixels
        }
        return particles
    }
}

private final class ParticleScene: SKScene {

    var gravity: CGFloat = 600
    var damping: CGFloat = 0.990
    var enableRotation: Bool = true

    private var particles: [ExplosionView.Particle] = []
    private var nodes: [SKSpriteNode] = []
    private var dead: [Bool] = []
    private var aliveCount: Int = 0
    private var lastTime: TimeInterval = 0

    func addParticles(_ newParticles: [ExplosionView.Particle]) {
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

            particles[i].age += dt
            let ax = sin(particles[i].age * particles[i].wFreqX * .pi * 2 + particles[i].wPhaseX) * particles[i].wAmpX
            let ay = sin(particles[i].age * particles[i].wFreqY * .pi * 2 + particles[i].wPhaseY) * particles[i].wAmpY
            particles[i].vx += ax * dt
            particles[i].vy += (ay + gravity) * dt
            particles[i].vx *= damping
            particles[i].vy *= damping
            particles[i].x += particles[i].vx * dt
            particles[i].y += particles[i].vy * dt
            if enableRotation {
                particles[i].rotation += particles[i].vRotation * dt
            }
            particles[i].alpha = max(0, particles[i].alpha - particles[i].alphaDecay * dt)

            if particles[i].y < topLimit || particles[i].y > bottomLimit || particles[i].alpha < 0.02 {
                nodes[i].removeFromParent()
                dead[i] = true
                aliveCount -= 1
            } else {
                nodes[i].position = CGPoint(x: particles[i].x, y: h - particles[i].y)
                if enableRotation {
                    nodes[i].zRotation = -particles[i].rotation
                }
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
