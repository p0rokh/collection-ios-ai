import UIKit

/// Получает уведомления о пакетах удалений от `CellCollapseLayoutController`
/// до финализации layout attributes.
///
/// Реализуйте этот protocol, чтобы перехватывать index path удаляемых элементов
/// и решать, для каких из них применять эффект взрыва+коллапса. Координатор —
/// рабочая реализация; передайте его как `layoutController.delegate`
/// (что `init` координатора делает автоматически).
public protocol CellCollapseLayoutControllerDelegate: AnyObject {
    /// Вызывается во время `prepare(forCollectionViewUpdates:)`, когда из
    /// collection view удаляется один или несколько элементов.
    ///
    /// Delegate обязан вызвать `controller.markCollapsing(at:)` для подмножества
    /// `indexPaths`, которое нужно анимировать, до возврата из метода — потому что
    /// `finalLayoutAttributesForDisappearingItem(at:)` синхронно обращается
    /// к помеченному множеству в той же итерации run-loop.
    ///
    /// - Parameters:
    ///   - controller: Layout-контроллер, обнаруживший удаления.
    ///   - indexPaths: Все index path, удаляемые в текущем пакете.
    func cellCollapseLayoutController(
        _ controller: CellCollapseLayoutController,
        willProcessDeletionsAt indexPaths: [IndexPath]
    )
}

/// Вспомогательный composition-объект, встраивающий анимацию коллапса в любой
/// существующий подкласс `UICollectionViewFlowLayout`.
///
/// Вместо наследования от layout этого пакета потребитель добавляет
/// `CellCollapseLayoutController` как хранимое свойство и перенаправляет
/// три точки переопределения layout:
///
/// ```swift
/// override func prepare(forCollectionViewUpdates items: [UICollectionViewUpdateItem]) {
///     super.prepare(forCollectionViewUpdates: items)
///     collapseController.prepare(updateItems: items)
/// }
///
/// override func finalizeCollectionViewUpdates() {
///     super.finalizeCollectionViewUpdates()
///     collapseController.finalize()
/// }
///
/// override func finalLayoutAttributesForDisappearingItem(
///     at itemIndexPath: IndexPath
/// ) -> UICollectionViewLayoutAttributes? {
///     let base = super.finalLayoutAttributesForDisappearingItem(at: itemIndexPath)
///     return collapseController.finalAttributes(for: itemIndexPath, base: base)
/// }
/// ```
///
/// При обработке пакета удалений `prepare(updateItems:)` уведомляет `delegate`
/// (как правило, `CellExplosionCoordinator`), который в ответ вызывает
/// `markCollapsing(at:)` для нужных path. `finalAttributes(for:base:)` затем
/// возвращает `CollapsibleLayoutAttributes` только для помеченных path, оставляя
/// остальные со стандартными attributes исчезновения.
public final class CellCollapseLayoutController {

    /// Delegate, получающий `willProcessDeletionsAt:` и решающий, какие
    /// path анимировать. Устанавливается автоматически в `CellExplosionCoordinator.init`.
    public weak var delegate: CellCollapseLayoutControllerDelegate?

    /// Активная конфигурация взрыва. Потребители могут менять её во время выполнения;
    /// изменения применяются к следующему пакету удалений.
    public var configuration: ExplosionConfiguration

    private var marked: Set<IndexPath> = []

    /// Создаёт layout-контроллер с заданной конфигурацией.
    ///
    /// - Parameter configuration: Начальные параметры физики и тайминга. По умолчанию
    ///   `.default`, соответствующее настройкам референсного демо.
    public init(configuration: ExplosionConfiguration = .default) {
        self.configuration = configuration
    }

    /// Отфильтровывает действия удаления из `updateItems` и уведомляет delegate.
    ///
    /// Вызывайте в начале `prepare(forCollectionViewUpdates:)`, после вызова `super`.
    /// Если удаляемых элементов нет, delegate не вызывается.
    ///
    /// - Parameter updateItems: Полный массив, полученный из
    ///   `prepare(forCollectionViewUpdates:)`.
    public func prepare(updateItems: [UICollectionViewUpdateItem]) {
        let deletePaths = updateItems.compactMap { item -> IndexPath? in
            guard item.updateAction == .delete else { return nil }
            return item.indexPathBeforeUpdate
        }
        guard !deletePaths.isEmpty else { return }
        delegate?.cellCollapseLayoutController(self, willProcessDeletionsAt: deletePaths)
    }

    /// Очищает множество помеченных path по завершении пакетного обновления.
    ///
    /// Вызывайте внутри `finalizeCollectionViewUpdates()`, после `super`. Если
    /// не вызвать `finalize()`, устаревшие path останутся помеченными и могут
    /// ошибочно подавить стандартную анимацию исчезновения в следующем пакете удалений.
    public func finalize() {
        marked.removeAll()
    }

    /// Помечает `indexPaths` так, чтобы `finalAttributes(for:base:)` возвращал
    /// для них `CollapsibleLayoutAttributes`.
    ///
    /// Вызывается `CellExplosionCoordinator` после захвата snapshot и готовности
    /// управлять коллапсом. Непомеченные path получают немодифицированные `base`
    /// attributes и анимируются стандартным переходом удаления UICollectionView.
    ///
    /// - Parameter indexPaths: Path, для которых в текущем пакете должен быть
    ///   применён эффект коллапса+взрыва.
    public func markCollapsing(at indexPaths: [IndexPath]) {
        for path in indexPaths { marked.insert(path) }
    }

    /// Возвращает финальные layout attributes для исчезающего элемента.
    ///
    /// Для помеченных path возвращает `CollapsibleLayoutAttributes` с `frame.height`
    /// равным `0`, `alpha` зафиксированным на `1` (чтобы ячейка оставалась видимой
    /// во время управляемого координатором коллапса, а не угасала через стандартную
    /// анимацию исчезновения UIKit), `lockedHeight` равным исходной высоте элемента
    /// и `collapseProgress` равным `0`. Для всех остальных path возвращаются
    /// `base` attributes без изменений.
    ///
    /// Вызывайте в конце `finalLayoutAttributesForDisappearingItem(at:)`,
    /// передавая значение из `super` как `base`.
    ///
    /// - Parameters:
    ///   - itemIndexPath: Index path исчезающего элемента.
    ///   - base: Attributes, сформированные суперклассом, или `nil`, если суперкласс
    ///     ничего не вернул.
    /// - Returns: Модифицированные `CollapsibleLayoutAttributes` для помеченных path
    ///   или немодифицированные `base` для непомеченных.
    public func finalAttributes(
        for itemIndexPath: IndexPath,
        base: UICollectionViewLayoutAttributes?
    ) -> UICollectionViewLayoutAttributes? {
        guard marked.contains(itemIndexPath), let base else { return base }
        if let collapsible = base as? CollapsibleLayoutAttributes {
            let initialHeight = collapsible.frame.height
            var frame = collapsible.frame
            frame.size.height = 0
            collapsible.frame = frame
            collapsible.alpha = 1
            collapsible.lockedHeight = initialHeight
            collapsible.collapseProgress = 0
            return collapsible
        }
        let copy = base.copy() as! UICollectionViewLayoutAttributes
        var frame = copy.frame
        frame.size.height = 0
        copy.frame = frame
        copy.alpha = 1
        return copy
    }
}
