# Plan: Move Deletion Animation into CellExplosionKit

## Context

Вся логика анимации удаления сейчас в `MessageViewController.delete(at:)`: тайминги, bounce, `UIView.animate + performBatchUpdates + deleteItems`. Это не переиспользуемо. Нужно вынести в `CellExplosionCoordinator.performDeletion(at:)` так, чтобы анимация осталась идентичной, а API не мутировал конфигурацию как побочный эффект.

**Ключевое архитектурное решение:** `collapseDuration` становится **вычисляемым свойством** `totalAnimationDuration * collapseTimingFraction`. Тогда `performDeletion` вообще не мутирует `configuration` — читает корректные значения напрямую. `handleDeletions` (делегатный путь) тоже получает правильный `collapseDuration` автоматически.

**Проверка непрерывности анимации:**
- Старый ViewController: `collapseDuration = 0.33 × 0.45 = 0.1485`, затем `UIView.animate(withDuration: 0.1485)`
- После рефакторинга: `configuration.collapseDuration` возвращает `0.33 × 0.45 = 0.1485` (вычисляемое)
- Результат идентичен ✓

---

## Файлы

| Файл | Изменение |
|---|---|
| `Packages/CellExplosionKit/Sources/.../Domain/ExplosionConfiguration.swift` | +2 stored поля, `collapseDuration` → computed, `burstThreshold` default → 30 |
| `Packages/CellExplosionKit/Sources/.../UIKit/CellExplosionCoordinator.swift` | +метод `performDeletion(at:)` |
| `App/CollectionDemo/MessageViewController.swift` | упростить `delete(at:)` до 2 строк |
| `Packages/CellExplosionKit/Tests/.../ExplosionConfigurationTests.swift` | обновить ассерты |

---

## Step 1 — ExplosionConfiguration.swift

### Добавить два stored поля (после `burstThreshold`):

```swift
/// Полная продолжительность составной анимации удаления: коллапс + отскок, в секундах.
public var totalAnimationDuration: TimeInterval

/// Доля от `totalAnimationDuration`, отводимая фазе коллапса UICollectionView.
public var collapseTimingFraction: Double
```

### Изменить `collapseDuration` на computed:

```swift
/// Продолжительность фазы коллапса: `totalAnimationDuration × collapseTimingFraction`.
public var collapseDuration: TimeInterval { totalAnimationDuration * collapseTimingFraction }
```

Убрать `collapseDuration` из `init` (он больше не stored).

### Обновить `init` — убрать `collapseDuration:`, добавить два новых параметра после `burstThreshold`:

```swift
public init(
    chunkSize: CGFloat,
    speed: CGFloat,
    gravity: CGFloat,
    damping: CGFloat,
    upBias: CGFloat,
    wobbleAmplitude: CGFloat,
    wobbleFrequency: CGFloat,
    lifetimeRange: ClosedRange<CGFloat>,
    burstThreshold: CGFloat,
    totalAnimationDuration: TimeInterval,
    collapseTimingFraction: Double
)
```

### Обновить `.default`:

```swift
public static let `default`: ExplosionConfiguration = .init(
    chunkSize: 1,
    speed: 60,
    gravity: -50,
    damping: 0.985,
    upBias: 50,
    wobbleAmplitude: 300,
    wobbleFrequency: 0.85,
    lifetimeRange: 0.1...0.8,
    burstThreshold: 30,              // ← было 12; 30 корректно для collapseDuration≈148ms
    totalAnimationDuration: 0.33,
    collapseTimingFraction: 0.45
)
```

> **Почему `burstThreshold: 30` в `.default`:** при `collapseDuration≈148ms` с порогом 12pt окно срабатывания ≈8ms — меньше одного тика CADisplayLink (16.7ms). Порог 30 расширяет окно до ~30ms. Пользователь всегда может переопределить `burstThreshold` для своей конфигурации — `performDeletion` его не трогает.

---

## Step 2 — CellExplosionCoordinator.swift: метод performDeletion

Добавить публичный метод (после `init`, до `handleDeletions`). Никаких мутаций `configuration` — только чтение:

```swift
/// Вызывайте после обновления data source. Берёт на себя всю анимацию удаления:
/// вычисляет тайминги из configuration, запускает bounce соседних ячеек,
/// оборачивает deleteItems в UIView.animate + performBatchUpdates.
///
/// - Parameter indexPaths: Index path элементов, уже удалённых из data source.
public func performDeletion(at indexPaths: [IndexPath]) {
    guard let collectionView else { return }

    let totalDuration    = configuration.totalAnimationDuration
    let collapseFraction = configuration.collapseTimingFraction
    let collapseDuration = configuration.collapseDuration  // computed: totalDuration * collapseFraction

    // Moving cells: видимые, с item > minDeleted, не из удаляемого множества
    let minDeletedItem = indexPaths.map(\.item).min() ?? 0
    let deletedSet     = Set(indexPaths)
    let movingCells = collectionView.visibleCells.filter { cell in
        guard let p = collectionView.indexPath(for: cell) else { return false }
        return p.item > minDeletedItem && !deletedSet.contains(p)
    }

    // Bounce animation — запускаем ДО UIView.animate (тот же RunLoop turn),
    // иначе bounce стартует позже и не совпадёт с коллапсом.
    let bounce            = CAKeyframeAnimation(keyPath: "transform.translation.y")
    bounce.values         = [0, 0, 4.0, 0, 0]
    bounce.keyTimes       = [
        0,
        NSNumber(value: collapseFraction),
        NSNumber(value: collapseFraction + 0.10),
        NSNumber(value: collapseFraction + 0.25),
        1,
    ]
    bounce.duration       = totalDuration
    bounce.timingFunctions = [
        CAMediaTimingFunction(name: .linear),
        CAMediaTimingFunction(name: .easeOut),
        CAMediaTimingFunction(name: .easeIn),
        CAMediaTimingFunction(name: .linear),
    ]
    for cell in movingCells {
        cell.layer.add(bounce, forKey: "anvil-bounce")
    }

    UIView.animate(
        withDuration: collapseDuration,
        delay: 0,
        options: [.curveEaseIn],
        animations: {
            collectionView.performBatchUpdates {
                collectionView.deleteItems(at: indexPaths)
            }
        },
        completion: nil
    )
}
```

> Никаких новых импортов: `UIKit` и `QuartzCore` уже есть.

---

## Step 3 — MessageViewController.swift: упростить delete(at:)

Метод `delete(at:)` (строки 84–158) заменить на:

```swift
private func delete(at indexPaths: [IndexPath]) {
    for path in indexPaths.sorted(by: { $0.item > $1.item }) {
        dataSource.remove(at: path.item)
    }
    explosionCoordinator.performDeletion(at: indexPaths)
}
```

Три `@objc`-хендлера, `viewDidLoad`, `UICollectionViewDataSource` — без изменений.

---

## Step 4 — ExplosionConfigurationTests.swift: обновить ассерты

В `test_default_hasExpectedValues` заменить ассерт на `collapseDuration` и `burstThreshold`:

```swift
// Было:
XCTAssertEqual(config.collapseDuration, 0.3)
XCTAssertEqual(config.burstThreshold, 12)

// Станет:
XCTAssertEqual(config.collapseDuration, 0.33 * 0.45, accuracy: 0.001)  // computed
XCTAssertEqual(config.burstThreshold, 30)
XCTAssertEqual(config.totalAnimationDuration, 0.33, accuracy: 0.001)
XCTAssertEqual(config.collapseTimingFraction, 0.45, accuracy: 0.001)
```

В `test_isValueType_mutationDoesNotAffectOriginal` — без изменений (мутирует `speed`, computed `collapseDuration` не затрагивает).

---

## Порядок исполнения

1. `ExplosionConfiguration.swift` — computed `collapseDuration`, новые поля, новый `.default`
2. `CellExplosionCoordinator.swift` — добавить `performDeletion(at:)`
3. `MessageViewController.swift` — упростить `delete(at:)`
4. `ExplosionConfigurationTests.swift` — обновить ассерты

---

## Верификация

```bash
# Unit tests пакета
xcodebuild test -scheme CellExplosionKit \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -10

# Сборка demo app
xcodebuild build -project App/CollectionDemo.xcodeproj \
  -scheme CollectionDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```

Ручная проверка в симуляторе: все три кнопки удаления дают идентичную визуальную анимацию (частицы + bounce соседних ячеек).
