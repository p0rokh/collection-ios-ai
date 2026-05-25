import UIKit

public protocol CellSnapshotProvider {
    func snapshot(of cell: UICollectionViewCell) -> UIImage?
    func cropBottom(of image: UIImage, toPoints points: CGFloat) -> UIImage?
}
