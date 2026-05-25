import UIKit
import QuartzCore

/// The central orchestrator of the cell explosion and height-collapse effect.
///
/// `CellExplosionCoordinator` wires together the layout controller, snapshot
/// provider, and renderer into a single object that the consumer creates once and
/// keeps alive for the lifetime of the collection view. It acts as the
/// `CellCollapseLayoutControllerDelegate`, intercepts deletion batches, captures
/// cell snapshots, starts `CollapseTracker` animations, and drives a
/// `CADisplayLink` loop that bursts particles the moment a cell's visible height
/// drops below `configuration.burstThreshold`.
///
/// **Typical setup:**
/// ```swift
/// let renderer = SpriteKitParticleRenderer(configuration: .default)
/// renderer.view.frame = view.bounds
/// view.addSubview(renderer.view)
///
/// let coordinator = CellExplosionCoordinator(
///     collectionView: collectionView,
///     container: view,
///     renderer: renderer,
///     layoutController: collapseController
/// )
/// ```
///
/// After construction, standard `collectionView.deleteItems(at:)` calls trigger
/// the effect automatically. No changes to the deletion code are required.
///
/// **Disabling the effect:**
/// Set `isEnabled = false` to make the coordinator a complete no-op. Deletions
/// proceed with the standard `UICollectionView` animation, and no snapshots are
/// captured.
///
/// **Selective opt-out:**
/// Set `shouldExplode` to return `false` for specific index paths. Those paths
/// use the standard deletion animation while the rest of the batch still bursts.
/// For example:
/// ```swift
/// coordinator.shouldExplode = { indexPath in indexPath.item != pinnedItemIndex }
/// ```
///
/// **Runtime configuration:**
/// Assigning a new `ExplosionConfiguration` to `configuration` takes effect for
/// the next deletion batch. In-flight animations always finish with the
/// configuration that was active when they started.
public final class CellExplosionCoordinator {

    /// When `false`, the coordinator is a complete no-op: the delegate method
    /// returns immediately, `markCollapsing` is never called, and deletions
    /// animate with the standard `UICollectionView` transition.
    public var isEnabled: Bool = true

    /// A per-path predicate that decides whether a deleted cell should explode.
    ///
    /// The default returns `true` for every path (all deletions burst). Return
    /// `false` for a specific path to let that path use the standard deletion
    /// animation while the rest of the batch still explodes. The closure is called
    /// synchronously on the main thread during `prepare(forCollectionViewUpdates:)`.
    public var shouldExplode: (IndexPath) -> Bool = { _ in true }

    /// The physics and timing parameters applied to the next explosion batch.
    public var configuration: ExplosionConfiguration

    /// The source of cells by index path. Defaults to `collectionView.cellForItem(at:)`.
    ///
    /// Override this in tests to supply mock cells without a live collection view.
    /// In production code the default is sufficient; this property is public only
    /// to make integration testing practical.
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

    /// Creates a coordinator and registers it as the layout controller's delegate.
    ///
    /// The coordinator holds weak references to `collectionView` and `container`
    /// so it does not prevent deallocation of the hosting view hierarchy.
    ///
    /// - Parameters:
    ///   - collectionView: The collection view whose deletions will be intercepted.
    ///   - container: The view used as the coordinate-space origin for particle
    ///     positions and as the parent of `CollapseTracker` layers. Typically the
    ///     view controller's root view.
    ///   - renderer: The particle rendering backend. Its `view` should already be
    ///     added to `container` before any deletions occur.
    ///   - layoutController: The layout controller embedded in the consumer's flow
    ///     layout. The coordinator sets itself as the controller's delegate.
    ///   - snapshotProvider: The cell snapshot strategy. Defaults to
    ///     `DefaultCellSnapshotProvider`, which is correct for non-inverted layouts.
    ///   - configuration: Initial physics and timing parameters.
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

    /// Handles a confirmed deletion batch after `isEnabled` and `shouldExplode` filtering.
    ///
    /// One `CollapseTracker` is shared by the entire batch so that a single
    /// `CABasicAnimation` drives all parallel cell collapses in sync. Each cell
    /// that passes the snapshot check produces a `PendingExplosion` entry, and
    /// the `CADisplayLink` loop fires until all entries have burst.
    private func handleDeletions(_ paths: [IndexPath]) {
        guard isEnabled, let container else { return }
        let filtered = paths.filter { shouldExplode($0) }
        guard !filtered.isEmpty else { return }

        var ready: [IndexPath] = []
        // One tracker per batch: a single CABasicAnimation drives all parallel
        // collapses in the same delete batch in lock-step.
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

    /// Processes one `CADisplayLink` tick: checks each pending explosion for burst,
    /// generates particles, and invalidates the display link when all entries are done.
    ///
    /// `max(1, currentHeight)` guards against passing a zero-height value to
    /// `cropBottom(of:toPoints:)`, which would produce a zero-pixel crop and an
    /// empty particle batch.
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
                // Clamp to at least 1 point so cropBottom never receives a
                // zero height, which would produce an empty (or nil) crop.
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
