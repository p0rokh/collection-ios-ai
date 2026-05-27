# Plan: Move Deletion Animation into CellExplosionKit

## Context

Вся логика анимации удаления сейчас в `MessageViewController.delete(at:)` (строки 84–158): тайминги, bounce, `UIView.animate + performBatchUpdates + deleteItems`. Это не переиспользуемо. Нужно вынести в `CellExplosionCoordinator.performDeletion(at:)` так, чтобы анимация осталась идентичной, а API не мутировал конфигурацию как побочный эффект.

**Ключевое архитектурное решение:** `collapseDuration` становится **вычисляемым свойством** `totalAnimationDuration * collapseTimingFraction`. Тогда `performDeletion` вообще не мутирует `configuration` — читает корректные значения напрямую. `handleDeletions` (делегатный путь) тоже получает правильный `collapseDuration` автоматически.

**Проверка непрерывности анимации:**
- Старый ViewController: `collapseDuration = 0.33 × 0.45 = 0.1485`, затем `UIView.animate(withDuration: 0.1485)`
- После рефакторинга: `configuration.collapseDuration` возвращает `0.33 × 0.45 = 0.1485` (вычисляемое)
- Результат идентичен ✓

---

## Файлы

| Файл | Изменение |
|---|---|
| `Packages/CellExplosionKit/Sources/CellExplosionKit/Domain/ExplosionConfiguration.swift` | `collapseDuration` → computed, +2 stored поля, `burstThreshold` default → 30 |
| `Packages/CellExplosionKit/Sources/CellExplosionKit/UIKit/CellExplosionCoordinator.swift` | +публичный метод `performDeletion(at:)` |
| `App/CollectionDemo/MessageViewController.swift` | упростить `delete(at:)` до 2 строк |
| `Packages/CellExplosionKit/Tests/CellExplosionKitTests/ExplosionConfigurationTests.swift` | обновить ассерты |
| `Packages/CellExplosionKit/Tests/CellExplosionKitTests/CellExplosionCoordinatorTests.swift` | **обновить тест на порог** (иначе сломается) |

---

## Step 1 — ExplosionConfiguration.swift

### Добавить два stored поля (вместо `collapseDuration`):

```swift
/// Полная продолжительность составной анимации удаления: коллапс + отскок, в секундах.
public var totalAnimationDuration: TimeInterval

/// Доля от `totalAnimationDuration`, отводимая фазе коллапса UICollectionView.
public var collapseTimingFraction: Double
```

### Изменить `collapseDuration` на computed (убрать из stored полей и init):

```swift
/// Продолжительность фазы коллапса: `totalAnimationDuration × collapseTimingFraction`.
public var collapseDuration: TimeInterval { totalAnimationDuration * collapseTimingFraction }
```

### Обновить `init` — убрать `collapseDuration:`, добавить два новых параметра:

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

> Нет прямых вызовов `ExplosionConfiguration(...)` вне `.default` — сигнатура меняется безопасно.

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

> **Почему `burstThreshold: 30`:** при `collapseDuration≈148ms` с порогом 12pt окно срабатывания ≈8ms — меньше одного тика CADisplayLink (16.7ms). Порог 30 расширяет окно до ~30ms.

---

## Step 2 — CellExplosionCoordinator.swift: метод performDeletion

Добавить публичный метод после `init`, до `handleDeletions`. Никаких мутаций `configuration`. **Контракт: data source должен быть обновлён до вызова.**

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
    let collapseDuration = configuration.collapseDuration  // totalDuration * collapseFraction

    let minDeletedItem = indexPaths.map(\.item).min() ?? 0
    let deletedSet     = Set(indexPaths)
    let movingCells = collectionView.visibleCells.filter { cell in
        guard let p = collectionView.indexPath(for: cell) else { return false }
        return p.item > minDeletedItem && !deletedSet.contains(p)
    }

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

> Новых импортов не нужно: `UIKit` и `QuartzCore` уже есть.

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

В `test_default_hasExpectedValues` заменить:

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

`test_isValueType_mutationDoesNotAffectOriginal` — без изменений (мутирует `speed`).

---

## Step 5 — CellExplosionCoordinatorTests.swift: исправить сломанный тест ⚠️

**Критично: план изначально этот шаг пропустил.** После изменения `burstThreshold` в `.default` с 12 на 30 тест `test_tick_aboveThreshold_doesNotBurst` сломается:

```
fraction=0.5 → currentHeight = 60 × 0.5 = 30
условие: 30 <= burstThreshold(30) → TRUE → burst сработает → XCTAssertEqual(cropCalls, 0) упадёт
```

В `test_tick_aboveThreshold_doesNotBurst` изменить `fractionOverride: 0.5` → `fractionOverride: 0.6` и обновить комментарий:

```swift
// Было:
// fraction=0.5 → currentHeight = 30 > threshold(12)
coordinator.tickForTesting(fractionOverride: 0.5)

// Станет:
// fraction=0.6 → currentHeight = 36 > threshold(30)
coordinator.tickForTesting(fractionOverride: 0.6)
```

В `test_tick_belowThreshold_burstsAndClearsPending` обновить только комментарий (логика остаётся верной, `6 < 30` ✓):

```swift
// Было: // эмулируем тик с fraction=0.1 → currentHeight = 60*0.1 = 6 < threshold(12)
// Станет: // эмулируем тик с fraction=0.1 → currentHeight = 60*0.1 = 6 < threshold(30)
```

---

## Порядок исполнения

```
1. ExplosionConfiguration.swift     — computed collapseDuration, новые поля, новый .default
2. CellExplosionCoordinator.swift   — добавить performDeletion(at:)
3. MessageViewController.swift      — упростить delete(at:)
4. ExplosionConfigurationTests.swift — обновить ассерты
5. CellExplosionCoordinatorTests.swift — исправить порог в тесте
```

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