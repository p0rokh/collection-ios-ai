import UIKit
import QuartzCore

final class ParticleEmitter {

    struct PendingExplosion {
        let image: UIImage
        let originalFrame: CGRect
        let initialHeight: CGFloat
        let tracker: CollapseTracker
    }

    private let renderer: ParticleRenderer
    private let snapshotProvider: CellSnapshotProvider
    private weak var container: UIView?

    private var pendingExplosions: [PendingExplosion] = []
    private var displayLink: CADisplayLink?
    private var displayLinkProxy: DisplayLinkProxy?

    var configuration: ExplosionConfiguration
    var pendingCount: Int { pendingExplosions.count }

    init(renderer: ParticleRenderer, snapshotProvider: CellSnapshotProvider, container: UIView, configuration: ExplosionConfiguration = .default) {
        self.renderer = renderer
        self.snapshotProvider = snapshotProvider
        self.container = container
        self.configuration = configuration
    }

    deinit {
        displayLink?.invalidate()
    }

    func addExplosion(_ explosion: PendingExplosion) {
        pendingExplosions.append(explosion)
        startDisplayLinkIfNeeded()
    }

    private func startDisplayLinkIfNeeded() {
        guard displayLink == nil else { return }
        let proxy = DisplayLinkProxy(target: self)
        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
        displayLinkProxy = proxy
    }

    fileprivate func handleTick() {
        tick(fractionOverride: nil, configuration: configuration)
    }

    private func tick(fractionOverride: CGFloat?, configuration: ExplosionConfiguration) {
        guard !pendingExplosions.isEmpty else {
            invalidateDisplayLink()
            return
        }

        var stillPending: [PendingExplosion] = []
        var allParticles: [Particle] = []

        for entry in pendingExplosions {
            let fraction = fractionOverride ?? entry.tracker.currentFraction()
            let currentHeight = entry.initialHeight * fraction
            if currentHeight <= configuration.burstThreshold {
                let h = max(1, currentHeight)
                let currentFrame = CGRect(
                    x: entry.originalFrame.origin.x,
                    y: entry.originalFrame.maxY - h,
                    width: entry.originalFrame.width,
                    height: h
                )
                if let cropped = snapshotProvider.cropBottom(of: entry.image, toPoints: h),
                   let cg = cropped.cgImage {
                    let parts = ParticleFactory.makeParticles(
                        from: cg,
                        scale: cropped.scale,
                        origin: currentFrame.origin,
                        configuration: configuration
                    )
                    allParticles.append(contentsOf: parts)
                }
            } else {
                stillPending.append(entry)
            }
        }
        pendingExplosions = stillPending

        if !allParticles.isEmpty {
            container?.bringSubviewToFront(renderer.view)
            renderer.addParticles(allParticles)
        }

        if pendingExplosions.isEmpty {
            invalidateDisplayLink()
        }
    }

    private func invalidateDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        displayLinkProxy = nil
    }
}

// MARK: - Testing hooks

extension ParticleEmitter {
    func tickForTesting(fractionOverride: CGFloat, configuration: ExplosionConfiguration) {
        tick(fractionOverride: fractionOverride, configuration: configuration)
    }
}

#if DEBUG
extension ParticleEmitter {
    var pendingExplosionsForTesting: [PendingExplosion] { pendingExplosions }
}
#endif

// MARK: - DisplayLinkProxy

private final class DisplayLinkProxy {
    weak var target: ParticleEmitter?

    init(target: ParticleEmitter) {
        self.target = target
    }

    @objc func tick() {
        target?.handleTick()
    }
}
