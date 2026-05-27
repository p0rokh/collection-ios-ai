# Clean Architecture Fixes — CellExplosionKit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Устранить четыре системных нарушения Clean Architecture в CellExplosionKit: UIKit в Domain-протоколах, отсутствие Use Case слоя, SRP-нарушение в координаторе и отсутствие явного composition root.

**Architecture:** Domain-слой остаётся чистым Swift без UIKit. Протоколы с UIKit-зависимостями переезжают в UIKit-слой. Из координатора выделяется `ParticleEmitter`, который владеет render loop — координатор становится тонким мостом между UICollectionView-обновлениями и системой взрывов. Новый `CellExplosionKitAssembler` в пакете берёт на себя роль composition root.

**Tech Stack:** Swift 5.9+, UIKit, SpriteKit, XCTest. Пакет: `CellExplosionKit` (Swift Package). Тесты: `swift test` из директории пакета.

---

## Карта файлов

### Создать
- `Packages/CellExplosionKit/Sources/CellExplosionKit/Domain/ParticleOutput.swift` — output port без UIKit
- `Packages/CellExplosionKit/Sources/CellExplosionKit/UIKit/ParticleRenderer.swift` — UIKit-протокол рендерера (переехал из Domain)
- `Packages/CellExplosionKit/Sources/CellExplosionKit/UIKit/CellSnapshotProvider.swift` — snapshot-протокол (переехал из Domain)
- `Packages/CellExplosionKit/Sources/CellExplosionKit/UIKit/ParticleEmitter.swift` — выделяется из координатора
- `Packages/CellExplosionKit/Sources/CellExplosionKit/Assembly/CellExplosionKitAssembler.swift` — composition root

### Изменить
- `Packages/CellExplosionKit/Sources/CellExplosionKit/UIKit/CellExplosionCoordinator.swift` — удалить display link, pendingExplosions; делегировать в ParticleEmitter
- `Packages/CellExplosionKit/Sources/CellExplosionKit/Rendering/SpriteKitParticleRenderer.swift` — импортировать протокол из нового места
- `App/CollectionDemo/MessageCollectionView.swift` — использовать CellExplosionKitAssembler
- `Packages/CellExplosionKit/Tests/CellExplosionKitTests/CellExplosionCoordinatorTests.swift` — обновить MockRenderer и MockSnapshotProvider

### Удалить
- `Packages/CellExplosionKit/Sources/CellExplosionKit/Domain/ParticleRendererProtocol.swift`
- `Packages/CellExplosionKit/Sources/CellExplosionKit/Domain/CellSnapshotProviderProtocol.swift`

---

## Task 1: Выделить `ParticleOutput` — убрать UIKit из Domain/ParticleRendererProtocol

**Проблема:** `Domain/ParticleRendererProtocol.swift` содержит `import UIKit` и `var view: UIView { get }`. Domain-слой знает про UIKit-фреймворк — нарушение Dependency Rule.

**Что делаем:** Разделяем на два протокола. `ParticleOutput` (чистый Domain) описывает только передачу частиц. `ParticleRenderer` (UIKit-слой) добавляет `var view: UIView` и наследует `ParticleOutput`.

**Как проверяем:** `grep -r "import UIKit" Packages/CellExplosionKit/Sources/CellExplosionKit/Domain/` возвращает пустой результат. Тесты проходят.

**Критерии приёмки:**
- Файл `Domain/ParticleRendererProtocol.swift` удалён
- Файл `Domain/ParticleOutput.swift` создан, не содержит `import UIKit`
- Файл `UIKit/ParticleRenderer.swift` создан, `ParticleRenderer: ParticleOutput`
- `SpriteKitParticleRenderer` и `MockRenderer` в тестах конформируют `ParticleRenderer`
- `swift test` — все тесты зелёные

---

- [ ] **Step 1.1: Создать `Domain/ParticleOutput.swift`**

Файл: `Packages/CellExplosionKit/Sources/CellExplosionKit/Domain/ParticleOutput.swift`

```swift
/// Output port Domain-слоя: принимает готовые к рендерингу частицы.
///
/// Не содержит зависимостей от UIKit — Use Case зависит только от этого
/// протокола при передаче результата частичной симуляции во внешний слой.
public protocol ParticleOutput: AnyObject {
    /// Ставит `particles` в очередь для немедленного рендеринга.
    ///
    /// Реализации принимают любое количество вызовов за кадр.
    func addParticles(_ particles: [Particle])
}
```

- [ ] **Step 1.2: Создать `UIKit/ParticleRenderer.swift`**

Файл: `Packages/CellExplosionKit/Sources/CellExplosionKit/UIKit/ParticleRenderer.swift`

```swift
import UIKit

/// UIKit-расширение Domain-порта `ParticleOutput`.
///
/// Добавляет `view: UIView` — единственную UIKit-зависимость рендерера.
/// Координатор вызывает `bringSubviewToFront(renderer.view)` перед взрывом,
/// поэтому `view` существует здесь, а не в Domain-слое.
///
/// Реализация по умолчанию — `SpriteKitParticleRenderer`. Альтернативу на Metal
/// можно подключить, реализовав этот protocol и передав его в
/// `CellExplosionCoordinator.init`.
public protocol ParticleRenderer: ParticleOutput {
    /// Вид, отображающий отрендеренные частицы. Добавьте его как дочерний элемент
    /// того же контейнера, что и collection view.
    var view: UIView { get }
}
```

- [ ] **Step 1.3: Обновить `SpriteKitParticleRenderer` — убрать старый import**

Файл: `Packages/CellExplosionKit/Sources/CellExplosionKit/Rendering/SpriteKitParticleRenderer.swift`

Тип `ParticleRenderer` теперь живёт в UIKit-слое того же модуля — дополнительных импортов не нужно, просто убедиться что `public final class SpriteKitParticleRenderer: ParticleRenderer` компилируется.

Никаких изменений в теле класса не требуется — протокол `ParticleRenderer` остался с теми же методами.

- [ ] **Step 1.4: Удалить `Domain/ParticleRendererProtocol.swift`**

```bash
rm Packages/CellExplosionKit/Sources/CellExplosionKit/Domain/ParticleRendererProtocol.swift
```

- [ ] **Step 1.5: Обновить тест — `MockRenderer` конформирует `ParticleRenderer`**

Файл: `Packages/CellExplosionKit/Tests/CellExplosionKitTests/CellExplosionCoordinatorTests.swift`

Найти:
```swift
private final class MockRenderer: ParticleRenderer {
    let view = UIView()
    var receivedBatches: [[Particle]] = []
    func addParticles(_ particles: [Particle]) {
        receivedBatches.append(particles)
    }
}
```

Изменений не требуется — `MockRenderer` уже имеет `view` и `addParticles`. Убедиться что компилируется.

- [ ] **Step 1.6: Запустить тесты**

```bash
cd Packages/CellExplosionKit && swift test 2>&1 | tail -20
```

Ожидаемый результат: `Test Suite 'All tests' passed`

- [ ] **Step 1.7: Проверить что Domain чист**

```bash
grep -r "import UIKit" Packages/CellExplosionKit/Sources/CellExplosionKit/Domain/
```

Ожидаемый результат: пустой вывод

- [ ] **Step 1.8: Коммит**

```bash
git add Packages/CellExplosionKit/Sources/CellExplosionKit/Domain/ParticleOutput.swift \
        Packages/CellExplosionKit/Sources/CellExplosionKit/UIKit/ParticleRenderer.swift \
        Packages/CellExplosionKit/Sources/CellExplosionKit/Rendering/SpriteKitParticleRenderer.swift
git rm Packages/CellExplosionKit/Sources/CellExplosionKit/Domain/ParticleRendererProtocol.swift
git commit -m "refactor: extract ParticleOutput domain port, move ParticleRenderer to UIKit layer"
```

---

## Task 2: Переместить `CellSnapshotProvider` в UIKit-слой

**Проблема:** `Domain/CellSnapshotProviderProtocol.swift` использует `UICollectionViewCell` и `UIImage` — оба типа из UIKit. Domain-слой зависит от framework-специфичных типов.

**Что делаем:** Просто перемещаем файл из `Domain/` в `UIKit/`. Протокол фундаментально UIKit-специфичен (ячейки и изображения UIKit), поэтому его правильное место — UIKit-слой, а не Domain.

**Как проверяем:** `grep -r "import UIKit" Packages/CellExplosionKit/Sources/CellExplosionKit/Domain/` — пустой результат. Компиляция и тесты успешны.

**Критерии приёмки:**
- Файл `Domain/CellSnapshotProviderProtocol.swift` удалён
- Файл `UIKit/CellSnapshotProvider.swift` создан с тем же содержимым
- `DefaultCellSnapshotProvider` в `UIKit/` компилируется без изменений
- `swift test` — все тесты зелёные

---

- [ ] **Step 2.1: Создать `UIKit/CellSnapshotProvider.swift`**

Файл: `Packages/CellExplosionKit/Sources/CellExplosionKit/UIKit/CellSnapshotProvider.swift`

```swift
import UIKit

/// Абстрагирует захват изображения ячейки, позволяя потребителям с нестандартными
/// координатными пространствами предоставлять скорректированный snapshot.
///
/// Реализация по умолчанию, `DefaultCellSnapshotProvider`, рендерит иерархию
/// ячейки с помощью `drawHierarchy(in:afterScreenUpdates:)` — корректно для
/// стандартных (Y-down) collection view. Чат-коллекции, применяющие переворот
/// `transform.y = -1` к collection view, нуждаются в custom provider.
///
/// Передайте custom реализацию в `CellExplosionCoordinator.init` через параметр
/// `snapshotProvider`.
public protocol CellSnapshotProvider {
    /// Рендерит `cell` в `UIImage` в координатном пространстве, ожидаемом
    /// `ParticleFactory`.
    ///
    /// Вернуть `nil`, если ячейка имеет нулевой размер или не может быть отрендерена.
    func snapshot(of cell: UICollectionViewCell) -> UIImage?

    /// Возвращает нижние `points` точек из `image`.
    ///
    /// Вернуть `nil`, чтобы пропустить взрыв частиц на этом тике.
    ///
    /// - Parameters:
    ///   - image: Полноразмерный snapshot, полученный из `snapshot(of:)`.
    ///   - points: Желаемая высота обрезки в логических точках. Всегда ≥ 1.
    func cropBottom(of image: UIImage, toPoints points: CGFloat) -> UIImage?
}
```

- [ ] **Step 2.2: Удалить `Domain/CellSnapshotProviderProtocol.swift`**

```bash
rm Packages/CellExplosionKit/Sources/CellExplosionKit/Domain/CellSnapshotProviderProtocol.swift
```

- [ ] **Step 2.3: Запустить тесты и проверить чистоту Domain**

```bash
cd Packages/CellExplosionKit && swift test 2>&1 | tail -10
grep -r "import UIKit" Packages/CellExplosionKit/Sources/CellExplosionKit/Domain/
```

Ожидаемый результат: тесты проходят, grep — пустой вывод.

- [ ] **Step 2.4: Коммит**

```bash
git add Packages/CellExplosionKit/Sources/CellExplosionKit/UIKit/CellSnapshotProvider.swift
git rm Packages/CellExplosionKit/Sources/CellExplosionKit/Domain/CellSnapshotProviderProtocol.swift
git commit -m "refactor: move CellSnapshotProvider to UIKit layer, Domain has no UIKit imports"
```

---

## Task 3: Выделить `ParticleEmitter` — устранить SRP-нарушение в координаторе

**Проблема:** `CellExplosionCoordinator` имеет пять самостоятельных ответственностей:
1. Перехват UICollectionView deletions (через layout controller delegate)
2. Захват snapshot ячеек
3. Управление `pendingExplosions[]`
4. Управление `CADisplayLink` жизненным циклом
5. Per-frame логика burst (processTick)

Изменение любой из них (другой рендер-частота, другой тип трекера, другой алгоритм burst) требует правки одного класса. По CA — у модуля должна быть одна причина меняться.

**Что делаем:** Выделяем `ParticleEmitter` в отдельный файл. Он владеет `pendingExplosions`, `CADisplayLink`, `DisplayLinkProxy` и всей per-frame логикой. Координатор становится тонким мостом: получает deletion events → захватывает snapshots → передаёт в emitter.

**Как проверяем:** Новый файл `ParticleEmitter.swift` существует. `CellExplosionCoordinator` не содержит `CADisplayLink`, `pendingExplosions`, `DisplayLinkProxy`. Все существующие тесты проходят без изменений (публичный API координатора не меняется).

**Критерии приёмки:**
- `CellExplosionCoordinator` не имеет `pendingExplosions`, `displayLink`, `displayLinkProxy`, `DisplayLinkProxy`
- `ParticleEmitter` содержит всю per-frame логику burst
- `ProcessTick` тесты (`tickForTesting`) по-прежнему работают (хук переезжает в `ParticleEmitter`)
- `swift test` — все тесты зелёные

---

- [ ] **Step 3.1: Написать тест на `ParticleEmitter` до его создания (TDD)**

Файл: `Packages/CellExplosionKit/Tests/CellExplosionKitTests/ParticleEmitterTests.swift`

```swift
import XCTest
import UIKit
@testable import CellExplosionKit

private final class MockRendererForEmitter: ParticleRenderer {
    let view = UIView()
    var receivedBatches: [[Particle]] = []
    func addParticles(_ particles: [Particle]) { receivedBatches.append(particles) }
}

private final class MockSnapshotForEmitter: CellSnapshotProvider {
    var croppedImage: UIImage?
    func snapshot(of cell: UICollectionViewCell) -> UIImage? { nil }
    func cropBottom(of image: UIImage, toPoints points: CGFloat) -> UIImage? { croppedImage }
}

final class ParticleEmitterTests: XCTestCase {

    private func makeImage(size: CGSize = CGSize(width: 4, height: 4)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    func test_tick_aboveThreshold_doesNotBurst() {
        let container = UIView()
        let renderer = MockRendererForEmitter()
        let snapshot = MockSnapshotForEmitter()
        let emitter = ParticleEmitter(renderer: renderer, snapshotProvider: snapshot, container: container)

        let image = makeImage()
        emitter.addExplosion(ParticleEmitter.PendingExplosion(
            image: image,
            originalFrame: CGRect(x: 0, y: 0, width: 100, height: 60),
            initialHeight: 60,
            tracker: CollapseTracker(container: container)
        ))

        // fraction=0.7 → currentHeight = 42 > burstThreshold(30)
        emitter.tickForTesting(fractionOverride: 0.7, configuration: .default)

        XCTAssertEqual(renderer.receivedBatches.count, 0)
        XCTAssertEqual(emitter.pendingCount, 1)
    }

    func test_tick_belowThreshold_burstsAndClears() {
        let container = UIView()
        let renderer = MockRendererForEmitter()
        let snapshot = MockSnapshotForEmitter()
        snapshot.croppedImage = makeImage(size: CGSize(width: 4, height: 1))
        let emitter = ParticleEmitter(renderer: renderer, snapshotProvider: snapshot, container: container)

        let image = makeImage()
        emitter.addExplosion(ParticleEmitter.PendingExplosion(
            image: image,
            originalFrame: CGRect(x: 0, y: 0, width: 100, height: 60),
            initialHeight: 60,
            tracker: CollapseTracker(container: container)
        ))

        // fraction=0.1 → currentHeight = 6 < burstThreshold(30)
        emitter.tickForTesting(fractionOverride: 0.1, configuration: .default)

        XCTAssertEqual(renderer.receivedBatches.count, 1)
        XCTAssertFalse(renderer.receivedBatches[0].isEmpty)
        XCTAssertEqual(emitter.pendingCount, 0)
    }
}
```

- [ ] **Step 3.2: Запустить тест — убедиться что он падает**

```bash
cd Packages/CellExplosionKit && swift test --filter ParticleEmitterTests 2>&1 | tail -5
```

Ожидаемый результат: ошибка компиляции `cannot find type 'ParticleEmitter'`

- [ ] **Step 3.3: Создать `UIKit/ParticleEmitter.swift`**

Файл: `Packages/CellExplosionKit/Sources/CellExplosionKit/UIKit/ParticleEmitter.swift`

```swift
import UIKit
import QuartzCore

/// Управляет циклом рендеринга частиц: владеет очередью ожидающих взрывов,
/// жизненным циклом `CADisplayLink` и per-frame логикой burst.
///
/// Координатор передаёт в emitter готовые `PendingExplosion` записи сразу после
/// захвата snapshot; emitter самостоятельно решает, когда ячейка достигла
/// порога взрыва (`burstThreshold`), и передаёт частицы в `ParticleRenderer`.
final class ParticleEmitter {

    struct PendingExplosion {
        let image: UIImage
        let originalFrame: CGRect
        let initialHeight: CGFloat
        let tracker: CollapseTracker
    }

    private let renderer: ParticleRenderer
    private let snapshotProvider: CellSnapshotProvider
    private weak var container: UIView?

    private var pendingExplosions: [PendingExplosion] = []
    private var displayLink: CADisplayLink?
    private var displayLinkProxy: DisplayLinkProxy?

    /// Количество ожидающих взрывов. Используется в тестах.
    var pendingCount: Int { pendingExplosions.count }

    init(renderer: ParticleRenderer, snapshotProvider: CellSnapshotProvider, container: UIView) {
        self.renderer = renderer
        self.snapshotProvider = snapshotProvider
        self.container = container
    }

    deinit {
        displayLink?.invalidate()
    }

    func addExplosion(_ explosion: PendingExplosion) {
        pendingExplosions.append(explosion)
        startDisplayLinkIfNeeded()
    }

    private func startDisplayLinkIfNeeded() {
        guard displayLink == nil else { return }
        let proxy = DisplayLinkProxy(target: self)
        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
        displayLinkProxy = proxy
    }

    fileprivate func handleTick() {
        tick(fractionOverride: nil, configuration: .default)
    }

    private func tick(fractionOverride: CGFloat?, configuration: ExplosionConfiguration) {
        guard !pendingExplosions.isEmpty else {
            invalidateDisplayLink()
            return
        }

        var stillPending: [PendingExplosion] = []
        var allParticles: [Particle] = []

        for entry in pendingExplosions {
            let fraction = fractionOverride ?? entry.tracker.currentFraction()
            let currentHeight = entry.initialHeight * fraction
            if currentHeight <= configuration.burstThreshold {
                let h = max(1, currentHeight)
                let currentFrame = CGRect(
                    x: entry.originalFrame.origin.x,
                    y: entry.originalFrame.maxY - h,
                    width: entry.originalFrame.width,
                    height: h
                )
                if let cropped = snapshotProvider.cropBottom(of: entry.image, toPoints: h),
                   let cg = cropped.cgImage {
                    let parts = ParticleFactory.makeParticles(
                        from: cg,
                        scale: cropped.scale,
                        origin: currentFrame.origin,
                        configuration: configuration
                    )
                    allParticles.append(contentsOf: parts)
                }
            } else {
                stillPending.append(entry)
            }
        }
        pendingExplosions = stillPending

        if !allParticles.isEmpty {
            container?.bringSubviewToFront(renderer.view)
            renderer.addParticles(allParticles)
        }

        if pendingExplosions.isEmpty {
            invalidateDisplayLink()
        }
    }

    private func invalidateDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        displayLinkProxy = nil
    }
}

// MARK: - Testing hooks

extension ParticleEmitter {
    func tickForTesting(fractionOverride: CGFloat, configuration: ExplosionConfiguration) {
        tick(fractionOverride: fractionOverride, configuration: configuration)
    }
}

// MARK: - DisplayLinkProxy

private final class DisplayLinkProxy {
    weak var target: ParticleEmitter?

    init(target: ParticleEmitter) {
        self.target = target
    }

    @objc func tick() {
        target?.handleTick()
    }
}
```

**Проблема:** `handleTick()` вызывает `tick(fractionOverride: nil, configuration: .default)` — но `configuration` должна приходить от координатора, а не быть захардкожена. Нужно хранить актуальную конфигурацию в emitter.

Исправляем `ParticleEmitter` — добавляем `var configuration: ExplosionConfiguration`:

```swift
final class ParticleEmitter {
    // ...
    var configuration: ExplosionConfiguration

    init(renderer: ParticleRenderer, snapshotProvider: CellSnapshotProvider, container: UIView, configuration: ExplosionConfiguration = .default) {
        self.renderer = renderer
        self.snapshotProvider = snapshotProvider
        self.container = container
        self.configuration = configuration
    }

    fileprivate func handleTick() {
        tick(fractionOverride: nil, configuration: configuration)
    }
    // ...
}
```

Полная версия файла с этим исправлением в Step 3.3 — это единый финальный вариант.

- [ ] **Step 3.4: Обновить `CellExplosionCoordinator` — удалить display link, делегировать в emitter**

Файл: `Packages/CellExplosionKit/Sources/CellExplosionKit/UIKit/CellExplosionCoordinator.swift`

Удалить из класса:
- `struct PendingExplosion` (переехал в `ParticleEmitter`)
- `private var pendingExplosions: [PendingExplosion]`
- `private var displayLink: CADisplayLink?`
- `private var displayLinkProxy: DisplayLinkProxy?`
- методы `startDisplayLinkIfNeeded()`, `handleDisplayLinkTick()`, `processTick(fractionOverride:)`, `invalidateDisplayLink()`
- класс `DisplayLinkProxy`

Добавить в класс:
- `private let emitter: ParticleEmitter`

В `init` добавить создание emitter после инициализации всех свойств:
```swift
self.emitter = ParticleEmitter(
    renderer: renderer,
    snapshotProvider: snapshotProvider,
    container: container,
    configuration: configuration
)
```

В `handleDeletions(_:)` заменить:
```swift
// Было:
pendingExplosions.append(PendingExplosion(...))
// ...
startDisplayLinkIfNeeded()

// Стало:
emitter.addExplosion(ParticleEmitter.PendingExplosion(
    image: image,
    originalFrame: frameInContainer,
    initialHeight: cell.bounds.height,
    tracker: tracker
))
```

В `var configuration` добавить `didSet`:
```swift
public var configuration: ExplosionConfiguration {
    didSet { emitter.configuration = configuration }
}
```

Убрать из `deinit`:
```swift
deinit {
    displayLink?.invalidate()  // удалить — emitter сам управляет своим display link
}
```

- [ ] **Step 3.5: Обновить тесты координатора — перенести tick-хуки**

Файл: `Packages/CellExplosionKit/Tests/CellExplosionKitTests/CellExplosionCoordinatorTests.swift`

В секции `#if DEBUG` у координатора `pendingExplosionsForTesting` и `tickForTesting` теперь делегируют в emitter. Обновить `DEBUG`-расширение координатора:

```swift
#if DEBUG
extension CellExplosionCoordinator {
    var pendingExplosionsForTesting: [ParticleEmitter.PendingExplosion] {
        emitter.pendingExplosionsForTesting
    }
    func tickForTesting(fractionOverride: CGFloat) {
        emitter.tickForTesting(fractionOverride: fractionOverride, configuration: configuration)
    }
}
#endif
```

Добавить в `ParticleEmitter` расширение для тестов:

```swift
#if DEBUG
extension ParticleEmitter {
    var pendingExplosionsForTesting: [PendingExplosion] { pendingExplosions }
}
#endif
```

- [ ] **Step 3.6: Запустить тесты**

```bash
cd Packages/CellExplosionKit && swift test 2>&1 | tail -15
```

Ожидаемый результат: `Test Suite 'All tests' passed`

- [ ] **Step 3.7: Коммит**

```bash
git add Packages/CellExplosionKit/Sources/CellExplosionKit/UIKit/ParticleEmitter.swift \
        Packages/CellExplosionKit/Sources/CellExplosionKit/UIKit/CellExplosionCoordinator.swift \
        Packages/CellExplosionKit/Tests/CellExplosionKitTests/ParticleEmitterTests.swift \
        Packages/CellExplosionKit/Tests/CellExplosionKitTests/CellExplosionCoordinatorTests.swift
git commit -m "refactor: extract ParticleEmitter from CellExplosionCoordinator (SRP)"
```

---

## Task 4: Создать `CellExplosionKitAssembler` — composition root

**Проблема:** Логика сборки зависимостей (`SpriteKitParticleRenderer`, `CellExplosionCoordinator`, renderer.view) рассыпана по `MessageCollectionView.configure(container:)` в app-слое. App-код знает о конкретных классах пакета — нарушение принципа "Main как plugin". Каждый consumer пакета вынужден воспроизводить одну и ту же последовательность инициализации.

**Что делаем:** Добавляем `CellExplosionKitAssembler` в пакет. Он знает о конкретных реализациях (`SpriteKitParticleRenderer`, `DefaultCellSnapshotProvider`) и создаёт готовый к использованию `CellExplosionCoordinator`. App-код работает через `Assembler` и не импортирует конкретные классы рендерера.

**Как проверяем:** `MessageCollectionView` не содержит `SpriteKitParticleRenderer`. Публичный API `CellExplosionCoordinator` не изменился. Тесты проходят.

**Критерии приёмки:**
- Файл `Assembly/CellExplosionKitAssembler.swift` создан в пакете
- `MessageCollectionView.configure()` использует `CellExplosionKitAssembler.assemble()`
- `MessageCollectionView` не содержит `lazy var renderer = SpriteKitParticleRenderer(...)`
- `swift test` — все тесты зелёные
- Приложение компилируется

---

- [ ] **Step 4.1: Создать `Assembly/CellExplosionKitAssembler.swift`**

Создать директорию: `Packages/CellExplosionKit/Sources/CellExplosionKit/Assembly/`

Файл: `Packages/CellExplosionKit/Sources/CellExplosionKit/Assembly/CellExplosionKitAssembler.swift`

```swift
import UIKit

/// Composition root пакета CellExplosionKit.
///
/// Единственное место, которое знает о конкретных реализациях:
/// `SpriteKitParticleRenderer` и `DefaultCellSnapshotProvider`.
/// Consumer пакета вызывает `assemble(...)` и получает готовый
/// координатор — без прямой зависимости от классов рендерера.
public enum CellExplosionKitAssembler {

    public struct Components {
        /// Готовый к использованию координатор взрывов.
        public let coordinator: CellExplosionCoordinator
        /// Вид рендерера частиц. Добавьте его в иерархию контейнера
        /// и растяните на весь экран — координатор сам вызовет `bringSubviewToFront`.
        public let rendererView: UIView
    }

    /// Собирает полный граф зависимостей для эффекта взрыва ячейки.
    ///
    /// - Parameters:
    ///   - collectionView: Collection view, из которой будут удаляться элементы.
    ///   - container: Корневой вид контроллера — используется как начало координат частиц.
    ///   - layoutController: Layout-контроллер, встроенный в flow layout.
    ///   - snapshotProvider: Стратегия захвата snapshot. По умолчанию `DefaultCellSnapshotProvider`.
    ///   - configuration: Начальные параметры физики. По умолчанию `.default`.
    /// - Returns: `Components` с координатором и видом рендерера.
    public static func assemble(
        collectionView: UICollectionView,
        container: UIView,
        layoutController: CellCollapseLayoutController,
        snapshotProvider: CellSnapshotProvider = DefaultCellSnapshotProvider(),
        configuration: ExplosionConfiguration = .default
    ) -> Components {
        let renderer = SpriteKitParticleRenderer(configuration: configuration)

        let coordinator = CellExplosionCoordinator(
            collectionView: collectionView,
            container: container,
            renderer: renderer,
            layoutController: layoutController,
            snapshotProvider: snapshotProvider,
            configuration: configuration
        )

        return Components(coordinator: coordinator, rendererView: renderer.view)
    }
}
```

- [ ] **Step 4.2: Обновить `MessageCollectionView` — использовать Assembler**

Файл: `App/CollectionDemo/MessageCollectionView.swift`

До изменения:
```swift
private lazy var renderer = SpriteKitParticleRenderer(configuration: .default)
private var explosionCoordinator: CellExplosionCoordinator?

func configure(container: UIView) {
    explosionCoordinator = CellExplosionCoordinator(
        collectionView: self,
        container: container,
        renderer: renderer,
        layoutController: collapseController,
        snapshotProvider: FlippedCellSnapshotProvider(),
        configuration: .default
    )
    container.addSubview(renderer.view)
    renderer.view.frame = container.bounds
    renderer.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
}
```

После изменения:
```swift
private var explosionCoordinator: CellExplosionCoordinator?

func configure(container: UIView) {
    let components = CellExplosionKitAssembler.assemble(
        collectionView: self,
        container: container,
        layoutController: collapseController,
        snapshotProvider: FlippedCellSnapshotProvider(),
        configuration: .default
    )
    explosionCoordinator = components.coordinator
    container.addSubview(components.rendererView)
    components.rendererView.frame = container.bounds
    components.rendererView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
}
```

- [ ] **Step 4.3: Запустить тесты**

```bash
cd Packages/CellExplosionKit && swift test 2>&1 | tail -10
```

Ожидаемый результат: `Test Suite 'All tests' passed`

- [ ] **Step 4.4: Убедиться что app компилируется**

```bash
xcodebuild -project App/CollectionDemo.xcodeproj \
           -scheme CollectionDemo \
           -destination 'generic/platform=iOS Simulator' \
           build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Ожидаемый результат: `BUILD SUCCEEDED`

- [ ] **Step 4.5: Коммит**

```bash
git add Packages/CellExplosionKit/Sources/CellExplosionKit/Assembly/CellExplosionKitAssembler.swift \
        App/CollectionDemo/MessageCollectionView.swift
git commit -m "feat: add CellExplosionKitAssembler as composition root"
```

---

## Task 5: Финальная проверка и измерение прогресса

**Проблема:** Нет. Это верификационный шаг — убеждаемся что все четыре задачи вместе не сломали ничего и архитектурная оценка реально выросла.

**Критерии приёмки:**
- Domain/ не содержит `import UIKit` (grep пустой)
- `CellExplosionCoordinator` не содержит `CADisplayLink`, `pendingExplosions`, `DisplayLinkProxy`
- `CellExplosionKitAssembler` существует в пакете
- `MessageCollectionView` не содержит `SpriteKitParticleRenderer`
- Все тесты зелёные
- Оценка CA по диагностическому чеклисту: не ниже 8.5/10

---

- [ ] **Step 5.1: Полный прогон тестов**

```bash
cd Packages/CellExplosionKit && swift test --parallel 2>&1 | tail -20
```

Ожидаемый результат: `Test Suite 'All tests' passed`

- [ ] **Step 5.2: Проверка чистоты Domain**

```bash
grep -r "import UIKit\|import SpriteKit\|import QuartzCore" \
     Packages/CellExplosionKit/Sources/CellExplosionKit/Domain/
```

Ожидаемый результат: пустой вывод

- [ ] **Step 5.3: Проверка отсутствия display link в координаторе**

```bash
grep -n "CADisplayLink\|pendingExplosions\|DisplayLinkProxy" \
     Packages/CellExplosionKit/Sources/CellExplosionKit/UIKit/CellExplosionCoordinator.swift
```

Ожидаемый результат: пустой вывод (всё уехало в ParticleEmitter)

- [ ] **Step 5.4: Проверка что app не импортирует рендерер напрямую**

```bash
grep -n "SpriteKitParticleRenderer" App/CollectionDemo/MessageCollectionView.swift
```

Ожидаемый результат: пустой вывод

- [ ] **Step 5.5: Итоговый коммит (если нужна правка)**

Если Step 5.1–5.4 всё зелёное — коммитить нечего. Если всплыли мелкие правки:

```bash
git add -p
git commit -m "fix: address review findings after CA refactor"
```

---

## Definition of Done (DoD)

Рефакторинг считается завершённым, когда выполнены **все** пункты:

### Архитектурные инварианты

| # | Инвариант | Проверка |
|---|-----------|----------|
| D1 | Папка `Domain/` не содержит ни одного `import UIKit / SpriteKit / QuartzCore` | `grep -r "import UIKit\|import SpriteKit\|import QuartzCore" .../Domain/` → пустой вывод |
| D2 | Протокол `ParticleOutput` существует в `Domain/` и не имеет UIKit-зависимостей | файл существует, нет `import UIKit` |
| D3 | Протокол `ParticleRenderer` живёт в `UIKit/` и наследует `ParticleOutput` | файл в `UIKit/`, `ParticleRenderer: ParticleOutput` |
| D4 | Протокол `CellSnapshotProvider` живёт в `UIKit/`, не в `Domain/` | файл в `UIKit/`, в `Domain/` его нет |
| D5 | `CellExplosionCoordinator` не содержит `CADisplayLink`, `pendingExplosions`, `DisplayLinkProxy` | grep → пустой вывод |
| D6 | `ParticleEmitter` содержит весь per-frame rendering loop | файл существует, содержит `CADisplayLink` и `pendingExplosions` |
| D7 | `CellExplosionKitAssembler` существует в `Assembly/` и является единственным местом, создающим `SpriteKitParticleRenderer` | файл существует; `grep -r "SpriteKitParticleRenderer()" Sources/` показывает только Assembler |
| D8 | App-код не создаёт `SpriteKitParticleRenderer` напрямую | `grep -rn "SpriteKitParticleRenderer" App/` → пустой вывод |

### Качество кода

| # | Критерий |
|---|----------|
| Q1 | `swift test` в пакете проходит без ошибок и предупреждений |
| Q2 | App собирается через `xcodebuild` без ошибок |
| Q3 | Публичный API пакета (типы и методы, доступные consumer) не изменился — нет breaking changes |
| Q4 | Тесты для `ParticleEmitter` существуют и покрывают оба сценария (above/below threshold) |

### Архитектурная оценка

| До | После | Метод проверки |
|----|-------|----------------|
| 6.5 / 10 | ≥ 8.5 / 10 | Повторный анализ по чеклисту CA (6 принципов × diagnostic questions) |

Конкретные вопросы диагностического чеклиста, которые должны получить ответ "да" после рефакторинга:
- "Can you test business rules without UIKit?" → **да**: Domain не имеет UIKit, `ParticlePhysics` тестируется без мока
- "Do source code dependencies point inward?" → **да**: Domain не зависит от UIKit-слоя
- "Is the framework confined to the outermost circle?" → **да**: UIKit только в UIKit/ и Rendering/ слоях
- "Does Main wire all dependencies?" → **да**: `CellExplosionKitAssembler` — единственный composition root
