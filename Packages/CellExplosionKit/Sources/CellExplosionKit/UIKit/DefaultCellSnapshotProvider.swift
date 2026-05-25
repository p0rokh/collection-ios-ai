import UIKit

/// The default `CellSnapshotProvider` for standard (non-inverted) collection views.
///
/// `DefaultCellSnapshotProvider` renders the cell hierarchy into a `UIImage` using
/// `drawHierarchy(in:afterScreenUpdates:)`, which is correct when the collection
/// view's coordinate space is not transformed. If your collection uses a
/// `transform.scaleY(-1)` flip (common in chat UIs), supply a custom
/// `CellSnapshotProvider` that inverts the graphics context before drawing and
/// pass it to `CellExplosionCoordinator.init(snapshotProvider:)`.
public final class DefaultCellSnapshotProvider: CellSnapshotProvider {

    public init() {}

    /// Renders `cell` into a `UIImage` at the screen's native scale.
    ///
    /// Returns `nil` if the cell has zero width or height, in which case the
    /// coordinator skips the burst for that cell and uses the standard UIKit
    /// deletion animation instead.
    public func snapshot(of cell: UICollectionViewCell) -> UIImage? {
        let bounds = cell.bounds
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { _ in
            cell.drawHierarchy(in: bounds, afterScreenUpdates: false)
        }
    }

    /// Crops the bottom `points` logical points from `image`.
    ///
    /// The coordinator calls this every `CADisplayLink` tick with a progressively
    /// smaller `points` value as the cell height collapses, so each tick receives
    /// a thinner slice of the original snapshot. Returns `nil` only if the image
    /// has no backing `CGImage`.
    ///
    /// - Parameters:
    ///   - image: The full-height cell snapshot to crop.
    ///   - points: Desired height of the cropped image, in logical points. Clamped
    ///     to a minimum of 1 pixel by the coordinator before this method is called.
    public func cropBottom(of image: UIImage, toPoints points: CGFloat) -> UIImage? {
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
