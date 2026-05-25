# CellExplosionKit — дизайн пакета

**Дата:** 2026-05-25
**Автор:** Антон Королёв (с участием Claude)
**Статус:** approved → готов к implementation plan

## Цель

Вынести существующую анимацию удаления ячейки `UICollectionView` (взрыв на частицы + плавный коллапс высоты) из demo-проекта `App/CollectionDemo/` в самостоятельный Swift Package `CellExplosionKit`, пригодный для подключения в любой UIKit-проект с минимальными правками потребителя.

## Ключевые ограничения и принципы

1. **Без саб-классов** `UICollectionViewFlowLayout` и `UICollectionViewCell` внутри пакета. Анимация встраивается в **существующие** Layout и Cell потребителя через композицию (controller-объекты).
2. **Clean Architecture** — три логических слоя (Domain / Rendering / UIKit) с правилом зависимостей «внутрь».
3. **MVVM-нейтральность** — пакет не диктует presentation pattern. Поднимается как сервис, юзер сам решает откуда дёргать.
4. **SOLID** — каждый юнит имеет одну ответственность, общение через протоколы, замена движка рендеринга (SpriteKit → Metal в будущем) без правок Domain и UIKit-слоёв.
5. **Прозрачная интеграция** — точка входа удаления — стандартный `collectionView.deleteItems(at:)`. Никаких новых методов в публичном API VC.
6. **Graceful degradation** — если интеграция неполная (например, ячейка без shrink-контроллера), удаление работает, просто без части эффектов.
7. **Universal** — пакет работает в standard-координатах. Спецслучай перевёрнутой коллекции (chat-mode) выносится в реализацию потребительского `CellSnapshotProvider`.

## Архитектура

Один таргет `CellExplosionKit`, внутри — три директории-слоя.

```
Sources/CellExplosionKit/
├── Domain/              ← чистый Swift + CoreGraphics, без UIKit/SpriteKit
│   ├── Particle.swift
│   ├── ParticlePhysics.swift
│   ├── ExplosionConfiguration.swift
│   ├── ParticleFactory.swift
│   ├── ParticleRendererProtocol.swift
│   └── CellSnapshotProviderProtocol.swift
│
├── Rendering/           ← реализация ParticleRenderer на SpriteKit
│   ├── SpriteKitParticleRenderer.swift     (public)
│   └── SpriteKitParticleScene.swift        (internal)
│
└── UIKit/               ← интеграция с UICollectionView
    ├── CellExplosionCoordinator.swift
    ├── CellCollapseLayoutController.swift
    ├── CellShrinkController.swift
    ├── CollapsibleLayoutAttributes.swift
    ├── CollapseTracker.swift               (internal)
    └── DefaultCellSnapshotProvider.swift
```

**Правило зависимостей:** Domain → ничего; Rendering → Domain; UIKit → Domain (опционально использует Rendering как дефолт, но потребитель может подменить).

## Публичный API

### Domain

```swift
public struct Particle { /* поля как сейчас, публичные */ }

public struct ExplosionConfiguration {
    public var chunkSize: CGFloat
    public var speed: CGFloat
    public var gravity: CGFloat
    public var damping: CGFloat
    public var upBias: CGFloat
    public var wobbleAmplitude: CGFloat
    public var wobbleFrequency: CGFloat
    public var lifetimeRange: ClosedRange<CGFloat>
    public var collapseDuration: TimeInterval
    public var burstThreshold: CGFloat

    public init(...)

    public static let `default`: ExplosionConfiguration = .init(
        chunkSize: 1,
        speed: 60,
        gravity: -50,
        damping: 0.985,
        upBias: 50,
        wobbleAmplitude: 300,
        wobbleFrequency: 0.85,
        lifetimeRange: 0.1...0.8,
        collapseDuration: 0.3,
        burstThreshold: 12
    )
}

public protocol ParticleRenderer: AnyObject {
    var view: UIView { get }
    func addParticles(_ particles: [Particle])
}

public protocol CellSnapshotProvider {
    func snapshot(of cell: UICollectionViewCell) -> UIImage?
    func cropBottom(of image: UIImage, toPoints points: CGFloat) -> UIImage?
}
```

### Rendering

```swift
public final class SpriteKitParticleRenderer: ParticleRenderer {
    public init(configuration: ExplosionConfiguration)
    public var view: UIView { get }
    public func addParticles(_ particles: [Particle])
}
```

### UIKit

```swift
public final class CellCollapseLayoutController {
    public init(configuration: ExplosionConfiguration = .default)

    // Вызываются из override-ов чужого FlowLayout
    public func prepare(updateItems: [UICollectionViewUpdateItem])
    public func finalize()
    public func finalAttributes(
        for itemIndexPath: IndexPath,
        base: UICollectionViewLayoutAttributes?
    ) -> UICollectionViewLayoutAttributes?

    // Вызывается ИЗВНЕ (координатором) — помечает paths, для которых нужно
    // отдать CollapsibleLayoutAttributes. Не помеченные → возвращается base.
    public func markCollapsing(at indexPaths: [IndexPath])

    // Делегат для нотификации координатора (устанавливается координатором при init)
    public weak var delegate: CellCollapseLayoutControllerDelegate?
}

public protocol CellCollapseLayoutControllerDelegate: AnyObject {
    // Layout-controller сообщает делегату что в batch есть delete-items.
    // Делегат сам решает, какие из них коллапсить через эффект, и вызывает
    // controller.markCollapsing(at:) до того, как Layout запросит finalAttributes.
    func cellCollapseLayoutController(
        _ controller: CellCollapseLayoutController,
        willProcessDeletionsAt indexPaths: [IndexPath]
    )
}

public final class CellShrinkController {
    public init()

    // Вызываются из override-ов чужой Cell
    public func apply(layoutAttributes: UICollectionViewLayoutAttributes)
    public func apply(toContentView contentView: UIView, cellBounds: CGRect)
    public func reset()
}

public final class CollapsibleLayoutAttributes: UICollectionViewLayoutAttributes {
    public var collapseProgress: CGFloat        // 1 = полная высота, 0 = коллапсирована
    public var lockedHeight: CGFloat?
}

public final class CellExplosionCoordinator {
    public init(
        collectionView: UICollectionView,
        container: UIView,
        renderer: ParticleRenderer,
        layoutController: CellCollapseLayoutController,
        snapshotProvider: CellSnapshotProvider = DefaultCellSnapshotProvider(),
        configuration: ExplosionConfiguration = .default
    )

    public var isEnabled: Bool                                       // дефолт: true — глобальный opt-out
    public var shouldExplode: (IndexPath) -> Bool                    // дефолт: { _ in true } — selective opt-out
    public var configuration: ExplosionConfiguration                 // применяется к следующим взрывам
}

public final class DefaultCellSnapshotProvider: CellSnapshotProvider {
    public init()
}
```

**`internal`-типы** (не видны потребителю): `ParticlePhysics`, `ParticleFactory`, `SpriteKitParticleScene`, `CollapseTracker`.

## Поток данных при удалении

Потребитель пишет **обычный** код удаления:

```swift
dataSource.remove(at: index)
collectionView.deleteItems(at: [indexPath])
```

Под капотом:

1. `UICollectionView.performBatchUpdates` собирает `[UICollectionViewUpdateItem]`.
2. `FlowLayout` юзера в `prepare(forCollectionViewUpdates:)` вызывает `layoutController.prepare(updateItems:)`.
3. `CellCollapseLayoutController` фильтрует delete-items из `updateItems` и нотифицирует делегата (`CellExplosionCoordinator`) о полном списке удаляемых paths через `willProcessDeletionsAt:`. Сам он про `shouldExplode` ничего не знает.
4. `CellExplosionCoordinator` в обработчике делегата:
   - если `isEnabled == false` — выходит, ничего не делает (layout-controller не получит mark, finalAttributes отдаст `base` → стандартное удаление);
   - применяет `shouldExplode(path)` к каждому path → получает отфильтрованный список;
   - для каждого отфильтрованного path берёт `collectionView.cellForItem(at: path)`; если `nil` — этот path выкидывается из списка;
   - снимает snapshot через `snapshotProvider.snapshot(of: cell)`, переводит `cell.frame` в систему координат `container`, записывает `PendingExplosion { image, originalFrame, initialHeight }`;
   - вызывает `layoutController.markCollapsing(at: ready)` — передаёт обратно paths, для которых нужно отдать `CollapsibleLayoutAttributes`;
   - стартует `CollapseTracker` (CALayer + CABasicAnimation) с длительностью `configuration.collapseDuration`;
   - запускает `CADisplayLink` (если ещё не запущен).
5. `finalLayoutAttributesForDisappearingItem(at:)` чужого Layout вызывает `layoutController.finalAttributes(for:base:)` — для marked path возвращается `CollapsibleLayoutAttributes` (с `frame.height = 0`, `collapseProgress = 0`, `lockedHeight = base.height`), для остальных — `base` без модификаций.
6. Cell юзера получает attributes:
   - в `apply(_:)` вызывает `shrinkController.apply(layoutAttributes:)` — он сохраняет `lockedHeight` и `progress`;
   - в `layoutSubviews()` вызывает `shrinkController.apply(toContentView:cellBounds:)` — если текущая высота < lockedHeight, контент прижимается к низу.
7. `CADisplayLink` тик у координатора:
   - читает текущую высоту из `tracker.presentation()?.bounds.height`;
   - для каждого pending: `currentHeight = initialHeight × fraction`;
   - если `currentHeight ≤ burstThreshold` — кропает картинку до текущей высоты, генерит частицы через `ParticleFactory`, передаёт в `renderer.addParticles(...)`, убирает из pending;
   - если pending пуст — инвалидирует DisplayLink.
8. `SpriteKitParticleRenderer` в game loop через `ParticlePhysics.step(...)` обновляет состояние частиц (gravity, wobble, damping, alpha decay) и позиции `SKSpriteNode`.

## Интеграция у потребителя

### FlowLayout (любой UICollectionViewFlowLayout-наследник)

```swift
final class MyFlowLayout: UICollectionViewFlowLayout {
    private let collapseController: CellCollapseLayoutController

    init(collapseController: CellCollapseLayoutController) {
        self.collapseController = collapseController
        super.init()
    }
    required init?(coder: NSCoder) { fatalError() }

    override class var layoutAttributesClass: AnyClass {
        CollapsibleLayoutAttributes.self
    }

    override func prepare(forCollectionViewUpdates items: [UICollectionViewUpdateItem]) {
        super.prepare(forCollectionViewUpdates: items)
        collapseController.prepare(updateItems: items)
    }

    override func finalizeCollectionViewUpdates() {
        super.finalizeCollectionViewUpdates()
        collapseController.finalize()
    }

    override func finalLayoutAttributesForDisappearingItem(
        at itemIndexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        let base = super.finalLayoutAttributesForDisappearingItem(at: itemIndexPath)
        return collapseController.finalAttributes(for: itemIndexPath, base: base)
    }
}
```

### Cell (любая UICollectionViewCell)

```swift
final class MyCell: UICollectionViewCell {
    private let shrinkController = CellShrinkController()

    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        shrinkController.apply(layoutAttributes: layoutAttributes)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shrinkController.apply(toContentView: contentView, cellBounds: bounds)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        shrinkController.reset()
    }
}
```

### ViewController (или любая сборочная точка)

```swift
final class MyViewController: UIViewController {
    private let collapseController = CellCollapseLayoutController(configuration: .default)
    private lazy var layout = MyFlowLayout(collapseController: collapseController)
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    private lazy var renderer = SpriteKitParticleRenderer(configuration: .default)

    private lazy var explosionCoordinator = CellExplosionCoordinator(
        collectionView: collectionView,
        container: view,
        renderer: renderer,
        layoutController: collapseController,
        configuration: .default
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(collectionView)
        view.addSubview(renderer.view)
        _ = explosionCoordinator    // активирует подписку delegate
    }

    private func deleteMessage(at index: Int) {
        dataSource.remove(at: index)
        collectionView.deleteItems(at: [IndexPath(item: index, section: 0)])
    }
}
```

**Объём интеграции:** ~12 строк добавочного кода в существующие Layout/Cell + ~6 строк в сборочной точке VC. Код удаления не меняется.

## Поведение в edge cases

| Сценарий | Поведение |
|---|---|
| Пакет не подключён | Стандартное удаление коллекции. |
| Только layout-controller (Cell без shrink) | Коллапс работает, контент в ячейке может «прыгать», взрыв работает. |
| Только shrink-controller (Layout без layout-controller) | Удаление стандартное, shrink — no-op. |
| `coordinator.isEnabled = false` | Полное отключение перехвата, всё работает по дефолту коллекции. |
| `shouldExplode(path) = false` | Этот path удаляется стандартно, остальные в batch — через эффект. |
| `cellForItem(at:) == nil` (off-screen) | Координатор не вызывает `markCollapsing` для этого path → стандартное удаление (нет snapshot → нечем взрываться, и эффект коллапса всё равно не виден пользователю). |
| Несколько `deleteItems` подряд | Очередь pending, каждая партия со своим CollapseTracker, DisplayLink работает пока есть pending. |
| `reloadData` во время анимации | Уже снятые snapshot продолжают анимироваться независимо от состояния коллекции. |
| Освобождение координатора | DisplayLink инвалидируется, CALayer-trackers убираются, в `deinit`. |
| Конфигурация меняется в runtime | Применяется к следующим взрывам. Текущие доигрывают со старой. |
| Несколько коллекций, один renderer | Поддерживается. Renderer не привязан к коллекции. |

## Ограничения (документируются явно)

1. **Только delete** — insert/move через эффект не предлагается.
2. **Standard координаты** — перевёрнутые (chat) поддерживаются через пользовательский `CellSnapshotProvider`.
3. **Section header/footer** — без эффекта, коллапсятся стандартно.
4. **Нет mid-flight отмены** — уже стартовавший взрыв доиграет до конца.

## Структура Package.swift

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CellExplosionKit",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "CellExplosionKit", targets: ["CellExplosionKit"]),
    ],
    targets: [
        .target(name: "CellExplosionKit"),
        .testTarget(name: "CellExplosionKitTests", dependencies: ["CellExplosionKit"]),
    ]
)
```

## Тестирование

```
Tests/CellExplosionKitTests/
├── ParticlePhysicsTests.swift
├── ParticleFactoryTests.swift
├── ExplosionConfigurationTests.swift
├── CellCollapseLayoutControllerTests.swift
├── CellShrinkControllerTests.swift
└── CoordinatorIntegrationTests.swift
```

**Покрытие:**
- **Domain** — pure unit-тесты, цель 100%.
- **UIKit-helpers** — через моки `UICollectionViewUpdateItem`, фейковые `UIView`, проверка состояния.
- **Coordinator** — integration тесты с `MockParticleRenderer` (записывает `addParticles`), `MockSnapshotProvider` (возвращает заготовленный image), проверка sequence willCollapse → snapshot → tracker → burst.

**Не покрываем тестами:** SpriteKit game loop, реальную интеграцию с `performBatchUpdates` (проверяется руками через demo-app).

## Миграция demo-проекта

После создания пакета `App/CollectionDemo/` мигрирует:

- **Удаляются:** `ExplosionView.swift`, `CellExplosionAnimator.swift`.
- **Модифицируется:** `MessageFlowLayout` — встраивает `CellCollapseLayoutController` композицией (4 точки интеграции).
- **Модифицируется:** `MessageCollectionCell` — встраивает `CellShrinkController` композицией (4 точки интеграции). Локальная логика `lockedHeight` уходит в `CellShrinkController`.
- **Модифицируется:** `MessageViewController`:
  - собирает связку (renderer, layoutController, coordinator);
  - пишет локальный `FlippedCellSnapshotProvider`, инвертирующий context при snapshot (особенность чата с `transform y:-1`), и передаёт его в координатор;
  - `deleteHandler` упрощается: обычное `dataSource.remove + collectionView.deleteItems`.

Это становится живым примером того, как (1) пакет интегрируется и (2) как спецслучай координат решается без правок пакета.
