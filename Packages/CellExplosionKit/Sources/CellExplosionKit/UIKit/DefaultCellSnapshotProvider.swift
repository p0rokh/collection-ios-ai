import UIKit

public final class DefaultCellSnapshotProvider: CellSnapshotProvider {

    public init() {}

    public func snapshot(of cell: UICollectionViewCell) -> UIImage? {
        let bounds = cell.bounds
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { _ in
            cell.drawHierarchy(in: bounds, afterScreenUpdates: false)
        }
    }

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
