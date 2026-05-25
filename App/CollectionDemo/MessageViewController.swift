//
//  MessageViewController.swift
//  CollectionDemo
//
//  Created by Антон Королев on 24.05.2026.
//

import UIKit
import SnapKit

class MessageViewController: UIViewController {
    
    private var dataSource: [Message] = demoMessages
    
    private lazy var deleteItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: UIImage(systemName: "arrow.down.message"),
            style: .plain,
            target: self,
            action: #selector(deleteHandler)
        )
        return item
    }()

    private lazy var deleteMiddleItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: UIImage(systemName: "scissors"),
            style: .plain,
            target: self,
            action: #selector(deleteMiddleHandler)
        )
        return item
    }()

    private lazy var deleteMultipleItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: UIImage(systemName: "rectangle.stack.badge.minus"),
            style: .plain,
            target: self,
            action: #selector(deleteMultipleHandler)
        )
        return item
    }()

    private lazy var messageCollectionView: MessageCollectionView = {
        let flowLayout = MessageFlowLayout()
        let collectionView = MessageCollectionView(frame: .zero, collectionViewLayout: flowLayout)
        collectionView.delegate = self
        collectionView.dataSource = self
        return collectionView
    }()

    private lazy var explosionView: ExplosionView = {
        let v = ExplosionView(frame: view.bounds)
        v.gravity = Explosion.gravity
        v.damping = Explosion.damping
        v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return v
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItems = [deleteItem, deleteMiddleItem, deleteMultipleItem]

        view.addSubview(messageCollectionView)
        messageCollectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        view.addSubview(explosionView)
    }
    
    private enum Explosion {
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
    }

    private struct PendingExplosion {
        let image: UIImage
        let originalFrame: CGRect
        let initialHeight: CGFloat
        let tracker: CALayer
    }

    private static let trackerInitialHeight: CGFloat = 1000

    private var pendingExplosions: [PendingExplosion] = []
    private var explosionMonitor: CADisplayLink?

    @objc func deleteHandler() {
        guard !dataSource.isEmpty else { return }
        explodeAndDelete(at: [IndexPath(item: 0, section: 0)])
    }

    @objc func deleteMiddleHandler() {
        guard !dataSource.isEmpty else { return }
        explodeAndDelete(at: [IndexPath(item: dataSource.count / 2, section: 0)])
    }

    @objc func deleteMultipleHandler() {
        guard dataSource.count >= 3 else { return }
        let indices = [0, dataSource.count / 2, dataSource.count - 1]
        explodeAndDelete(at: indices.map { IndexPath(item: $0, section: 0) })
    }

    private func explodeAndDelete(at indexPaths: [IndexPath]) {
        let tracker = CALayer()
        tracker.frame = CGRect(x: -10000, y: -10000, width: 1, height: Self.trackerInitialHeight)
        view.layer.addSublayer(tracker)

        var entries: [PendingExplosion] = []
        for path in indexPaths {
            guard let cell = messageCollectionView.cellForItem(at: path) else { continue }
            guard let image = snapshotVisibleContent(of: cell) else { continue }
            let frame = messageCollectionView.convert(cell.frame, to: view)
            entries.append(PendingExplosion(
                image: image,
                originalFrame: frame,
                initialHeight: cell.bounds.height,
                tracker: tracker
            ))
        }

        pendingExplosions.append(contentsOf: entries)
        startExplosionMonitorIfNeeded()

        for path in indexPaths.sorted(by: { $0.item > $1.item }) {
            dataSource.remove(at: path.item)
        }

        let shrinkAnim = CABasicAnimation(keyPath: "bounds.size.height")
        shrinkAnim.fromValue = Self.trackerInitialHeight
        shrinkAnim.toValue = 0
        shrinkAnim.duration = Explosion.collapseDuration
        shrinkAnim.timingFunction = CAMediaTimingFunction(name: .easeIn)
        shrinkAnim.fillMode = .forwards
        shrinkAnim.isRemovedOnCompletion = false
        tracker.add(shrinkAnim, forKey: "shrink")

        CATransaction.begin()
        CATransaction.setAnimationDuration(Explosion.collapseDuration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeIn))
        CATransaction.setCompletionBlock { [weak tracker] in
            tracker?.removeFromSuperlayer()
        }
        messageCollectionView.performBatchUpdates {
            self.messageCollectionView.deleteItems(at: indexPaths)
        }
        CATransaction.commit()
    }

    private func startExplosionMonitorIfNeeded() {
        guard explosionMonitor == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(checkExplosionThreshold))
        link.add(to: .main, forMode: .common)
        explosionMonitor = link
    }

    @objc private func checkExplosionThreshold() {
        if pendingExplosions.isEmpty {
            explosionMonitor?.invalidate()
            explosionMonitor = nil
            return
        }

        var stillWaiting: [PendingExplosion] = []
        var ready: [(image: UIImage, frame: CGRect)] = []
        for entry in pendingExplosions {
            let trackerHeight = entry.tracker.presentation()?.bounds.size.height ?? Self.trackerInitialHeight
            let fraction = max(0, min(1, trackerHeight / Self.trackerInitialHeight))
            let currentHeight = entry.initialHeight * fraction

            if currentHeight <= Explosion.threshold {
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
            startExplosion(snapshots: ready)
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

    private func snapshotVisibleContent(of cell: UICollectionViewCell) -> UIImage? {
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

    private func startExplosion(snapshots: [(image: UIImage, frame: CGRect)]) {
        guard !snapshots.isEmpty else { return }
        var allParticles: [ExplosionView.Particle] = []
        for snap in snapshots {
            let parts = ExplosionView.makeParticles(
                from: snap.image,
                at: snap.frame.origin,
                chunkSize: Explosion.chunkSize,
                speed: Explosion.speed,
                upBias: Explosion.upBias,
                wobbleAmp: Explosion.wobbleAmp,
                wobbleFreq: Explosion.wobbleFreq,
                lifetimeRange: Explosion.lifetimeRange
            )
            allParticles.append(contentsOf: parts)
        }
        guard !allParticles.isEmpty else { return }
        view.bringSubviewToFront(explosionView)
        explosionView.addParticles(allParticles)
    }
}

extension MessageViewController: UICollectionViewDelegate {

}

extension MessageViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        dataSource.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: MessageCollectionCell.reuseIdentifier,
            for: indexPath
        ) as! MessageCollectionCell
        cell.configure(with: dataSource[indexPath.item])
        return cell
    }
}
