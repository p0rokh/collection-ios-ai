import UIKit
import QuartzCore

public final class CellExplosionCoordinator {

    public var isEnabled: Bool = true
    public var shouldExplode: (IndexPath) -> Bool = { _ in true }
    public var configuration: ExplosionConfiguration

    /// Перекрываемый источник ячейки по indexPath. Используется в тестах для подмены.
    /// По умолчанию = collectionView.cellForItem(at:).
    public var cellProvider: (IndexPath) -> UICollectionViewCell?

    private weak var collectionView: UICollectionView?
    private weak var container: UIView?
    private let renderer: ParticleRenderer
    private let layoutController: CellCollapseLayoutController
    private let snapshotProvider: CellSnapshotProvider

    struct PendingExplosion {
        let image: UIImage
        let originalFrame: CGRect
        let initialHeight: CGFloat
        // RAII: tracker's CALayer is removed from the container in its deinit,
        // tying tracker lifetime to its owning entry in pendingExplosions.
        let tracker: CollapseTracker
    }

    private var pendingExplosions: [PendingExplosion] = []
    private var displayLink: CADisplayLink?
    private var displayLinkProxy: DisplayLinkProxy?

    public init(
        collectionView: UICollectionView,
        container: UIView,
        renderer: ParticleRenderer,
        layoutController: CellCollapseLayoutController,
        snapshotProvider: CellSnapshotProvider = DefaultCellSnapshotProvider(),
        configuration: ExplosionConfiguration = .default
    ) {
        self.collectionView = collectionView
        self.container = container
        self.renderer = renderer
        self.layoutController = layoutController
        self.snapshotProvider = snapshotProvider
        self.configuration = configuration
        self.cellProvider = { [weak collectionView] path in
            collectionView?.cellForItem(at: path)
        }
        layoutController.delegate = self
    }

    deinit {
        displayLink?.invalidate()
    }

    private func handleDeletions(_ paths: [IndexPath]) {
        guard isEnabled, let container else { return }
        let filtered = paths.filter { shouldExplode($0) }
        guard !filtered.isEmpty else { return }

        var ready: [IndexPath] = []
        let tracker = CollapseTracker(container: container)

        for path in filtered {
            guard let cell = cellProvider(path),
                  let image = snapshotProvider.snapshot(of: cell) else { continue }
            let frameInContainer = cell.convert(cell.bounds, to: container)
            pendingExplosions.append(PendingExplosion(
                image: image,
                originalFrame: frameInContainer,
                initialHeight: cell.bounds.height,
                tracker: tracker
            ))
            ready.append(path)
        }

        guard !ready.isEmpty else { return }
        layoutController.markCollapsing(at: ready)
        tracker.start(duration: configuration.collapseDuration) {}
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

    fileprivate func handleDisplayLinkTick() {
        processTick(fractionOverride: nil)
    }

    private func processTick(fractionOverride: CGFloat?) {
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

extension CellExplosionCoordinator: CellCollapseLayoutControllerDelegate {
    public func cellCollapseLayoutController(
        _ controller: CellCollapseLayoutController,
        willProcessDeletionsAt indexPaths: [IndexPath]
    ) {
        handleDeletions(indexPaths)
    }
}

/// Breaks the CADisplayLink → coordinator retain cycle. The runloop holds the
/// proxy strongly, but the proxy only weakly references the coordinator, so
/// dismissing the host view controller mid-animation deallocates the
/// coordinator on schedule (the proxy then forwards no-op ticks until the next
/// invalidation).
private final class DisplayLinkProxy {
    weak var target: CellExplosionCoordinator?

    init(target: CellExplosionCoordinator) {
        self.target = target
    }

    @objc func tick() {
        target?.handleDisplayLinkTick()
    }
}

#if DEBUG
extension CellExplosionCoordinator {
    var pendingExplosionsForTesting: [PendingExplosion] { pendingExplosions }
    func tickForTesting(fractionOverride: CGFloat) {
        processTick(fractionOverride: fractionOverride)
    }
}
#endif
