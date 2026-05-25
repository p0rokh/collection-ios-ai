import UIKit

/// Реализация `CellSnapshotProvider` по умолчанию для стандартных (неперевёрнутых) collection view.
///
/// `DefaultCellSnapshotProvider` рендерит иерархию ячейки в `UIImage` с помощью
/// `drawHierarchy(in:afterScreenUpdates:)` — корректно, когда координатное
/// пространство collection view не трансформировано. Если ваша коллекция
/// использует переворот `transform.scaleY(-1)` (характерно для чат-интерфейсов),
/// предоставьте custom `CellSnapshotProvider`, инвертирующий графический контекст
/// перед рисованием, и передайте его в `CellExplosionCoordinator.init(snapshotProvider:)`.
public final class DefaultCellSnapshotProvider: CellSnapshotProvider {

    public init() {}

    /// Рендерит `cell` в `UIImage` в нативном масштабе экрана.
    ///
    /// Возвращает `nil`, если ячейка имеет нулевую ширину или высоту; в таком
    /// случае координатор пропускает взрыв для этой ячейки и использует
    /// стандартную анимацию удаления UIKit.
    public func snapshot(of cell: UICollectionViewCell) -> UIImage? {
        let bounds = cell.bounds
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { _ in
            cell.drawHierarchy(in: bounds, afterScreenUpdates: false)
        }
    }

    /// Обрезает нижние `points` логических точек из `image`.
    ///
    /// Координатор вызывает этот метод на каждом тике `CADisplayLink` с прогрессивно
    /// уменьшающимся значением `points` по мере коллапса высоты ячейки, получая
    /// всё более тонкий срез исходного snapshot. Возвращает `nil` только если
    /// изображение не имеет backing `CGImage`.
    ///
    /// - Parameters:
    ///   - image: Полноразмерный snapshot ячейки для обрезки.
    ///   - points: Желаемая высота обрезанного изображения в логических точках.
    ///     Координатор ограничивает минимум одним пикселем до вызова этого метода.
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
