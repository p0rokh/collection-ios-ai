import UIKit

/// Abstracts the capture of a cell image so that consumers with non-standard
/// coordinate spaces can provide a corrected snapshot.
///
/// The default implementation, `DefaultCellSnapshotProvider`, renders the cell
/// hierarchy with `drawHierarchy(in:afterScreenUpdates:)` — correct for standard
/// (Y-down) collection views. Chat-style collections that apply a `transform.y = -1`
/// flip to their collection view need a custom provider that inverts the graphics
/// context before drawing, so that the resulting image is right-side up when the
/// `ParticleFactory` reads its pixels.
///
/// Pass a custom implementation to `CellExplosionCoordinator.init` via the
/// `snapshotProvider` parameter.
public protocol CellSnapshotProvider {
    /// Renders `cell` into a `UIImage` in the coordinate space expected by
    /// `ParticleFactory`.
    ///
    /// Return `nil` if the cell has zero size or cannot be rendered; the
    /// coordinator silently skips that cell and falls back to the standard
    /// UICollectionView deletion animation for its index path.
    func snapshot(of cell: UICollectionViewCell) -> UIImage?

    /// Returns the bottom `points` points of `image`, cropped to the current
    /// visible height of the collapsing cell.
    ///
    /// The coordinator calls this every `CADisplayLink` tick, passing a
    /// progressively smaller `points` value as the cell collapses. Return `nil`
    /// to skip the particle burst for that tick; the coordinator will retry on
    /// the next frame.
    ///
    /// - Parameters:
    ///   - image: The full-height snapshot produced by `snapshot(of:)`.
    ///   - points: The desired crop height in logical points. Always ≥ 1.
    func cropBottom(of image: UIImage, toPoints points: CGFloat) -> UIImage?
}
