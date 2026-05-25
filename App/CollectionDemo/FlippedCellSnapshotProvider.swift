//
//  FlippedCellSnapshotProvider.swift
//  CollectionDemo
//
//  Используется в перевёрнутой коллекции (transform y:-1) — рендерит snapshot
//  с инверсией Y, чтобы итоговая картинка не была вверх ногами.
//

import UIKit
import CellExplosionKit

final class FlippedCellSnapshotProvider: CellSnapshotProvider {

    func snapshot(of cell: UICollectionViewCell) -> UIImage? {
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

    func cropBottom(of image: UIImage, toPoints points: CGFloat) -> UIImage? {
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
