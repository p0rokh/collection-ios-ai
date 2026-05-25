import UIKit

/// Пользовательские layout attributes, несущие состояние коллапса исчезающей ячейки.
///
/// `CollapsibleLayoutAttributes` расширяет `UICollectionViewLayoutAttributes`
/// двумя дополнительными полями. `CellCollapseLayoutController` создаёт экземпляры
/// этого класса в `finalAttributes(for:base:)`; ячейка потребителя читает их
/// внутри `apply(_:)` через `CellShrinkController.apply(layoutAttributes:)`.
///
/// Чтобы этот механизм работал, `UICollectionViewFlowLayout`-подкласс потребителя
/// должен переопределить `layoutAttributesClass`, вернув `CollapsibleLayoutAttributes.self`:
/// ```swift
/// override class var layoutAttributesClass: AnyClass {
///     CollapsibleLayoutAttributes.self
/// }
/// ```
public final class CollapsibleLayoutAttributes: UICollectionViewLayoutAttributes {

    /// Дробное значение в `[0, 1]`, показывающее, какая часть исходной высоты
    /// ячейки остаётся видимой. `1.0` — полностью раскрыта; `0.0` — полностью свёрнута.
    ///
    /// Когда `CellCollapseLayoutController` выдаёт финальные attributes для
    /// исчезающей ячейки, это значение устанавливается в `0`, чтобы система
    /// layout анимировала ячейку до нулевой высоты.
    public var collapseProgress: CGFloat = 1.0

    /// Исходная высота ячейки до начала коллапса, в точках.
    ///
    /// `CellShrinkController` использует её, чтобы удерживать content view
    /// на полной высоте, пока frame ячейки сжимается, создавая визуальный
    /// эффект скольжения контента вниз при коллапсе.
    public var lockedHeight: CGFloat?

    public override func copy(with zone: NSZone? = nil) -> Any {
        let copy = super.copy(with: zone) as! CollapsibleLayoutAttributes
        copy.collapseProgress = collapseProgress
        copy.lockedHeight = lockedHeight
        return copy
    }

    /// Сравнивает `collapseProgress` и `lockedHeight` в дополнение к стандартным
    /// полям `UICollectionViewLayoutAttributes`.
    ///
    /// Переопределение `isEqual` необходимо, потому что `UICollectionView` опирается
    /// на равенство attributes при решении, нужно ли обновлять layout конкретного
    /// элемента. Без этого переопределения collection view игнорировал бы изменения
    /// пользовательских полей и не запускал анимацию коллапса.
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? CollapsibleLayoutAttributes else { return false }
        guard super.isEqual(other) else { return false }
        return collapseProgress == other.collapseProgress && lockedHeight == other.lockedHeight
    }
}
