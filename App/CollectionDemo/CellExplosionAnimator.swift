//
//  CellExplosionAnimator.swift
//  CollectionDemo
//

import UIKit

final class CellExplosionAnimator {

    private enum Constants {
        static let chunkSize: CGFloat = 1
        static let speed: CGFloat = 60
        static let gravity: CGFloat = -50
        static let damping: CGFloat = 0.985
        static let upBias: CGFloat = 50
        static let wobbleAmp: CGFloat = 300
        static let wobbleFreq: CGFloat = 0.85
        static let lifetimeRange: ClosedRange<CGFloat> = 0.1...0.8
        static let collapseDuration: TimeInterval = 0.3
        static let threshold: CGFloat = 12
        static let trackerInitialHeight: CGFloat = 1000
    }

    private struct PendingExplosion {
        let image: UIImage
        let originalFrame: CGRect
        let initialHeight: CGFloat
        let tracker: CALayer
    }

    private weak var collectionView: UICollectionView?
    private weak var explosionView: ExplosionView?
    private weak var container: UIView?

    private var pendingExplosions: [PendingExplosion] = []
    private var monitor: CADisplayLink?

    init(collectionView: UICollectionView, explosionView: ExplosionView, container: UIView) {
        self.collectionView = collectionView
        self.explosionView = explosionView
        self.container = container
        explosionView.gravity = Constants.gravity
        explosionView.damping = Constants.damping
    }

    func explodeAndDelete(at indexPaths: [IndexPath], removeFromDataSource: () -> Void) {
        guard let collectionView, let container else { return }

        let tracker = makeTracker(in: container)

        var entries: [PendingExplosion] = []
        for path in indexPaths {
            guard let cell = collectionView.cellForItem(at: path),
                  let image = Self.snapshot(of: cell) else { continue }
            entries.append(PendingExplosion(
                image: image,
                originalFrame: collectionView.convert(cell.frame, to: container),
                initialHeight: cell.bounds.height,
                tracker: tracker
            ))
        }

        pendingExplosions.append(contentsOf: entries)
        startMonitorIfNeeded()

        removeFromDataSource()

        runCollapseAnimation(collectionView: collectionView, indexPaths: indexPaths, tracker: tracker)
    }

    private func makeTracker(in container: UIView) -> CALayer {
        let tracker = CALayer()
        tracker.frame = CGRect(x: -10000, y: -10000, width: 1, height: Constants.trackerInitialHeight)
        container.layer.addSublayer(tracker)
        return tracker
    }

    private func runCollapseAnimation(collectionView: UICollectionView, indexPaths: [IndexPath], tracker: CALayer) {
        let shrinkAnim = CABasicAnimation(keyPath: "bounds.size.height")
        shrinkAnim.fromValue = Constants.trackerInitialHeight
        shrinkAnim.toValue = 0
        shrinkAnim.duration = Constants.collapseDuration
        shrinkAnim.timingFunction = CAMediaTimingFunction(name: .easeIn)
        shrinkAnim.fillMode = .forwards
        shrinkAnim.isRemovedOnCompletion = false
        tracker.add(shrinkAnim, forKey: "shrink")

        CATransaction.begin()
        CATransaction.setAnimationDuration(Constants.collapseDuration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeIn))
        CATransaction.setCompletionBlock { [weak tracker] in
            tracker?.removeFromSuperlayer()
        }
        collectionView.performBatchUpdates {
            collectionView.deleteItems(at: indexPaths)
        }
        CATransaction.commit()
    }

    private func startMonitorIfNeeded() {
        guard monitor == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(checkThreshold))
        link.add(to: .main, forMode: .common)
        monitor = link
    }

    @objc private func checkThreshold() {
        if pendingExplosions.isEmpty {
            monitor?.invalidate()
            monitor = nil
            return
        }

        var stillWaiting: [PendingExplosion] = []
        var ready: [(image: UIImage, frame: CGRect)] = []
        for entry in pendingExplosions {
            let trackerHeight = entry.tracker.presentation()?.bounds.size.height ?? Constants.trackerInitialHeight
            let fraction = max(0, min(1, trackerHeight / Constants.trackerInitialHeight))
            let currentHeight = entry.initialHeight * fraction

            if currentHeight <= Constants.threshold {
                let h = max(1, currentHeight)
                let currentFrame = CGRect(
                    x: entry.originalFrame.origin.x,
                    y: entry.originalFrame.maxY - h,
                    width: entry.originalFrame.width,
                    height: h
                )
                if let cropped = Self.cropBottom(of: entry.image, toPoints: h) {
                    ready.append((cropped, currentFrame))
                }
            } else {
                stillWaiting.append(entry)
            }
        }
        pendingExplosions = stillWaiting

        if !ready.isEmpty {
            burst(snapshots: ready)
        }
    }

    private func burst(snapshots: [(image: UIImage, frame: CGRect)]) {
        guard let explosionView, let container else { return }
        var allParticles: [ExplosionView.Particle] = []
        for snap in snapshots {
            let parts = ExplosionView.makeParticles(
                from: snap.image,
                at: snap.frame.origin,
                chunkSize: Constants.chunkSize,
                speed: Constants.speed,
                upBias: Constants.upBias,
                wobbleAmp: Constants.wobbleAmp,
                wobbleFreq: Constants.wobbleFreq,
                lifetimeRange: Constants.lifetimeRange
            )
            allParticles.append(contentsOf: parts)
        }
        guard !allParticles.isEmpty else { return }
        container.bringSubviewToFront(explosionView)
        explosionView.addParticles(allParticles)
    }

    private static func snapshot(of cell: UICollectionViewCell) -> UIImage? {
        let bounds = cell.bounds
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            cg.translateBy(x: 0, y: bounds.height)
            cg.scaleBy(x: 1, y: -1)
            cell.drawHierarchy(in: bounds, afterScreenUpdates: false)
        }
    }

    private static func cropBottom(of image: UIImage, toPoints points: CGFloat) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let scale = image.scale
        let totalPixelHeight = cgImage.height
        let cropPixelHeight = min(totalPixelHeight, max(1, Int(points * scale)))
        let cropRect = CGRect(
            x: 0,
            y: totalPixelHeight - cropPixelHeight,
            width: cgImage.width,
            height: cropPixelHeight
        )
        guard let croppedCG = cgImage.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: croppedCG, scale: scale, orientation: image.imageOrientation)
    }
}
