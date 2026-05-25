import UIKit

/// Вспомогательный composition-объект, удерживающий content view ячейки прижатым
/// к нижнему краю, пока frame ячейки сжимается в ходе анимации коллапса.
///
/// Добавьте `CellShrinkController` как хранимое свойство в любой подкласс
/// `UICollectionViewCell` и перенаправьте две точки переопределения layout и `prepareForReuse`:
///
/// ```swift
/// private let shrinkController = CellShrinkController()
///
/// override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
///     super.apply(layoutAttributes)
///     shrinkController.apply(layoutAttributes: layoutAttributes)
/// }
///
/// override func layoutSubviews() {
///     super.layoutSubviews()
///     shrinkController.apply(toContentView: contentView, cellBounds: bounds)
/// }
///
/// override func prepareForReuse() {
///     super.prepareForReuse()
///     shrinkController.reset()
/// }
/// ```
///
/// Когда `CollapsibleLayoutAttributes` отсутствуют (например, при обычном скролле
/// или когда layout-контроллер не подключён), `CellShrinkController` является
/// полным no-op и не добавляет накладных расходов.
public final class CellShrinkController {

    private var lockedHeight: CGFloat?

    public init() {}

    /// Читает `lockedHeight` из `layoutAttributes`, если они являются `CollapsibleLayoutAttributes`.
    ///
    /// Вызывайте внутри `apply(_:)`, после `super`. Если `layoutAttributes` не является
    /// экземпляром `CollapsibleLayoutAttributes`, метод ничего не делает.
    ///
    /// - Parameter layoutAttributes: Attributes, переданные layout-системой.
    public func apply(layoutAttributes: UICollectionViewLayoutAttributes) {
        guard let collapsible = layoutAttributes as? CollapsibleLayoutAttributes else { return }
        if let locked = collapsible.lockedHeight {
            self.lockedHeight = locked
        }
    }

    /// Перемещает `contentView` так, чтобы его нижний край оставался выровненным
    /// с нижней границей исходной (до коллапса) области ячейки, пока frame
    /// ячейки сжимается вверх.
    ///
    /// Вызывайте внутри `layoutSubviews()`, после `super`. Когда текущий
    /// `cellBounds.height` меньше `lockedHeight`, content view получает исходный
    /// размер и смещается вниз, оставаясь «прикреплённым» к нижнему краю —
    /// создавая эффект неподвижного контента при коллапсе верхней части ячейки.
    ///
    /// Реализация устанавливает `bounds` и `center`, а не `frame`, чтобы сохранить
    /// любой `transform`, применённый к content view. В чат-коллекциях к ячейке
    /// применён переворот `transform.scaleY(-1)`, и прямая установка `frame`
    /// работала бы в пространстве родителя (до transform) и давала бы неверный layout.
    ///
    /// - Parameters:
    ///   - contentView: `contentView` ячейки для перепозиционирования.
    ///   - cellBounds: Текущие `bounds` ячейки, сжимающиеся по мере анимации коллапса.
    public func apply(toContentView contentView: UIView, cellBounds: CGRect) {
        guard let lockedHeight, cellBounds.height < lockedHeight else { return }
        contentView.bounds = CGRect(x: 0, y: 0, width: cellBounds.width, height: lockedHeight)
        contentView.center = CGPoint(x: cellBounds.width / 2, y: cellBounds.height + lockedHeight / 2)
    }

    /// Сбрасывает сохранённую заблокированную высоту.
    ///
    /// Вызывайте внутри `prepareForReuse()`, чтобы переиспользуемая ячейка не
    /// применяла ненадолго геометрию коллапса от предыдущего удаления.
    public func reset() {
        lockedHeight = nil
    }
}
