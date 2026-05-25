# CellExplosionKit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Вынести анимацию удаления ячейки UICollectionView (взрыв на частицы + плавный коллапс высоты) из demo-проекта `App/CollectionDemo/` в отдельный Swift Package `CellExplosionKit`, и мигрировать demo на этот пакет.

**Architecture:** Один таргет, три слоя Clean Architecture (Domain / Rendering / UIKit). Domain — pure Swift + CoreGraphics, Rendering — SpriteKit-реализация порта `ParticleRenderer`, UIKit — composition-helpers, встраиваемые в существующие Layout/Cell потребителя без саб-классов. Триггер анимации — стандартный `collectionView.deleteItems(at:)`.

**Tech Stack:** Swift 5.9+, iOS 15+, SwiftPM, UIKit, SpriteKit, CoreGraphics, XCTest, xcodebuild.

**Spec:** `docs/superpowers/specs/2026-05-25-cell-explosion-package-design.md`

---

## File Structure

```
Packages/CellExplosionKit/
├── Package.swift
└── Sources/
    └── CellExplosionKit/
        ├── Domain/
        │   ├── Particle.swift                       (public)
        │   ├── ExplosionConfiguration.swift         (public + .default)
        │   ├── ParticlePhysics.swift                (internal)
        │   ├── ParticleFactory.swift                (internal)
        │   ├── ParticleRendererProtocol.swift       (public)
        │   └── CellSnapshotProviderProtocol.swift   (public)
        ├── Rendering/
        │   ├── SpriteKitParticleRenderer.swift      (public)
        │   └── SpriteKitParticleScene.swift         (internal)
        └── UIKit/
            ├── CollapsibleLayoutAttributes.swift    (public)
            ├── CollapseTracker.swift                (internal)
            ├── CellCollapseLayoutController.swift   (public)
            ├── CellShrinkController.swift           (public)
            ├── DefaultCellSnapshotProvider.swift    (public)
            └── CellExplosionCoordinator.swift       (public)

Tests/CellExplosionKitTests/
├── ParticlePhysicsTests.swift
├── ParticleFactoryTests.swift
├── ExplosionConfigurationTests.swift
├── CollapsibleLayoutAttributesTests.swift
├── CellCollapseLayoutControllerTests.swift
├── CellShrinkControllerTests.swift
└── CellExplosionCoordinatorTests.swift
```

После создания пакета — миграция `App/CollectionDemo/`:
- Удалить: `ExplosionView.swift`, `CellExplosionAnimator.swift`.
- Модифицировать: `MessageFlowLayout.swift`, `MessageCollectionCell.swift`, `MessageViewController.swift`.
- Создать в demo-app: `FlippedCellSnapshotProvider.swift` (учитывает `transform y:-1`).

---

## Build & Test Command (используется в каждой задаче)

```bash
cd /Users/antonkorolev/Repository/collection-ios-ai/Packages/CellExplosionKit && \
xcodebuild test \
  -scheme CellExplosionKit \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:CellExplosionKitTests/<TestClass>/<testMethod> 2>&1 | xcpretty
```

Замени `<TestClass>/<testMethod>` на конкретный тест. Для прогона всех тестов — без `-only-testing`.

---

## Phase 1: Package skeleton

### Task 1: Создание Package.swift и каркаса директорий

**Files:**
- Create: `Packages/CellExplosionKit/Package.swift`
- Create: `Packages/CellExplosionKit/Sources/CellExplosionKit/.gitkeep`
- Create: `Packages/CellExplosionKit/Tests/CellExplosionKitTests/.gitkeep`

- [ ] **Step 1: Создать структуру директорий**

```bash
cd /Users/antonkorolev/Repository/collection-ios-ai
mkdir -p Packages/CellExplosionKit/Sources/CellExplosionKit/{Domain,Rendering,UIKit}
mkdir -p Packages/CellExplosionKit/Tests/CellExplosionKitTests
touch Packages/CellExplosionKit/Sources/CellExplosionKit/.gitkeep
touch Packages/CellExplosionKit/Tests/CellExplosionKitTests/.gitkeep
```

- [ ] **Step 2: Создать Package.swift**

Файл `Packages/CellExplosionKit/Package.swift`:

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
        .target(
            name: "CellExplosionKit",
            path: "Sources/CellExplosionKit"
        ),
        .testTarget(
            name: "CellExplosionKitTests",
            dependencies: ["CellExplosionKit"],
            path: "Tests/CellExplosionKitTests"
        ),
    ]
)
```

- [ ] **Step 3: Проверить что пакет резолвится**

```bash
cd Packages/CellExplosionKit
xcodebuild -list 2>&1 | head -20
```

Expected output: список schemes, включая `CellExplosionKit`.

- [ ] **Step 4: Коммит**

```bash
cd /Users/antonkorolev/Repository/collection-ios-ai
git add Packages/CellExplosionKit/Package.swift \
        Packages/CellExplosionKit/Sources/CellExplosionKit/.gitkeep \
        Packages/CellExplosionKit/Tests/CellExplosionKitTests/.gitkeep
git commit -m "feat(CellExplosionKit): scaffold SPM package"
```

---

## Phase 2: Domain layer

### Task 2: Particle struct + ExplosionConfiguration + .default

**Files:**
- Create: `Packages/CellExplosionKit/Sources/CellExplosionKit/Domain/Particle.swift`
- Create: `Packages/CellExplosionKit/Sources/CellExplosionKit/Domain/ExplosionConfiguration.swift`
- Create: `Packages/CellExplosionKit/Tests/CellExplosionKitTests/ExplosionConfigurationTests.swift`

- [ ] **Step 1: Создать Particle.swift**

```swift
import CoreGraphics

public struct Particle {
    public var x: CGFloat
    public var y: CGFloat
    public var vx: CGFloat
    public var vy: CGFloat
    public var color: CGColor
    public var size: CGFloat
    public var rotation: CGFloat
    public var vRotation: CGFloat
    public var alpha: CGFloat
    public var alphaDecay: CGFloat
    public var age: CGFloat
    public var wAmpX: CGFloat
    public var wAmpY: CGFloat
    public var wFreqX: CGFloat
    public var wFreqY: CGFloat
    public var wPhaseX: CGFloat
    public var wPhaseY: CGFloat

    public init(
        x: CGFloat, y: CGFloat,
        vx: CGFloat, vy: CGFloat,
        color: CGColor,
        size: CGFloat,
        rotation: CGFloat = 0, vRotation: CGFloat = 0,
        alpha: CGFloat = 1, alphaDecay: CGFloat,
        age: CGFloat = 0,
        wAmpX: CGFloat, wAmpY: CGFloat,
        wFreqX: CGFloat, wFreqY: CGFloat,
        wPhaseX: CGFloat, wPhaseY: CGFloat
    ) {
        self.x = x; self.y = y
        self.vx = vx; self.vy = vy
        self.color = color
        self.size = size
        self.rotation = rotation; self.vRotation = vRotation
        self.alpha = alpha; self.alphaDecay = alphaDecay
        self.age = age
        self.wAmpX = wAmpX; self.wAmpY = wAmpY
        self.wFreqX = wFreqX; self.wFreqY = wFreqY
        self.wPhaseX = wPhaseX; self.wPhaseY = wPhaseY
    }
}
```

- [ ] **Step 2: Написать падающий тест для ExplosionConfiguration**

Файл `Tests/CellExplosionKitTests/ExplosionConfigurationTests.swift`:

```swift
import XCTest
@testable import CellExplosionKit

final class ExplosionConfigurationTests: XCTestCase {

    func test_default_hasExpectedValues() {
        let config = ExplosionConfiguration.default
        XCTAssertEqual(config.chunkSize, 1)
        XCTAssertEqual(config.speed, 60)
        XCTAssertEqual(config.gravity, -50)
        XCTAssertEqual(config.damping, 0.985)
        XCTAssertEqual(config.upBias, 50)
        XCTAssertEqual(config.wobbleAmplitude, 300)
        XCTAssertEqual(config.wobbleFrequency, 0.85)
        XCTAssertEqual(config.lifetimeRange, 0.1...0.8)
        XCTAssertEqual(config.collapseDuration, 0.3)
        XCTAssertEqual(config.burstThreshold, 12)
    }

    func test_isValueType_mutationDoesNotAffectOriginal() {
        let original = ExplosionConfiguration.default
        var copy = original
        copy.speed = 999
        XCTAssertEqual(original.speed, 60)
        XCTAssertEqual(copy.speed, 999)
    }
}
```

- [ ] **Step 3: Прогнать тест — должен FAIL (нет ExplosionConfiguration)**

```bash
cd /Users/antonkorolev/Repository/collection-ios-ai/Packages/CellExplosionKit
xcodebuild test -scheme CellExplosionKit \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:CellExplosionKitTests/ExplosionConfigurationTests 2>&1 | tail -20
```

Expected: ошибка компиляции `cannot find 'ExplosionConfiguration' in scope`.

- [ ] **Step 4: Реализовать ExplosionConfiguration.swift**

```swift
import Foundation
import CoreGraphics

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

    public init(
        chunkSize: CGFloat,
        speed: CGFloat,
        gravity: CGFloat,
        damping: CGFloat,
        upBias: CGFloat,
        wobbleAmplitude: CGFloat,
        wobbleFrequency: CGFloat,
        lifetimeRange: ClosedRange<CGFloat>,
        collapseDuration: TimeInterval,
        burstThreshold: CGFloat
    ) {
        self.chunkSize = chunkSize
        self.speed = speed
        self.gravity = gravity
        self.damping = damping
        self.upBias = upBias
        self.wobbleAmplitude = wobbleAmplitude
        self.wobbleFrequency = wobbleFrequency
        self.lifetimeRange = lifetimeRange
        self.collapseDuration = collapseDuration
        self.burstThreshold = burstThreshold
    }

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
```

- [ ] **Step 5: Прогнать тест — должен PASS**

Та же команда, что в Step 3. Expected: `Test Suite 'ExplosionConfigurationTests' passed`.

- [ ] **Step 6: Коммит**

```bash
git add Packages/CellExplosionKit/Sources/CellExplosionKit/Domain/Particle.swift \
        Packages/CellExplosionKit/Sources/CellExplosionKit/Domain/ExplosionConfiguration.swift \
        Packages/CellExplosionKit/Tests/CellExplosionKitTests/ExplosionConfigurationTests.swift
git commit -m "feat(CellExplosionKit): Particle, ExplosionConfiguration, .default"
```

---

### Task 3: Protocols (ParticleRenderer, CellSnapshotProvider)

**Files:**
- Create: `Packages/CellExplosionKit/Sources/CellExplosionKit/Domain/ParticleRendererProtocol.swift`
- Create: `Packages/CellExplosionKit/Sources/CellExplosionKit/Domain/CellSnapshotProviderProtocol.swift`

Протоколы без поведения тестировать не нужно — проверим компилируемостью на следующих шагах.

- [ ] **Step 1: Создать ParticleRendererProtocol.swift**

```swift
import UIKit

public protocol ParticleRenderer: AnyObject {
    var view: UIView { get }
    func addParticles(_ particles: [Particle])
}
```

- [ ] **Step 2: Создать CellSnapshotProviderProtocol.swift**

```swift
import UIKit

public protocol CellSnapshotProvider {
    func snapshot(of cell: UICollectionViewCell) -> UIImage?
    func cropBottom(of image: UIImage, toPoints points: CGFloat) -> UIImage?
}
```

- [ ] **Step 3: Проверить компиляцию**

```bash
cd /Users/antonkorolev/Repository/collection-ios-ai/Packages/CellExplosionKit
xcodebuild build -scheme CellExplosionKit \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Коммит**

```bash
git add Packages/CellExplosionKit/Sources/CellExplosionKit/Domain/ParticleRendererProtocol.swift \
        Packages/CellExplosionKit/Sources/CellExplosionKit/Domain/CellSnapshotProviderProtocol.swift
git commit -m "feat(CellExplosionKit): ParticleRenderer, CellSnapshotProvider protocols"
```

---

### Task 4: ParticlePhysics (TDD — один шаг симуляции)

**Files:**
- Create: `Packages/CellExplosionKit/Sources/CellExplosionKit/Domain/ParticlePhysics.swift`
- Create: `Packages/CellExplosionKit/Tests/CellExplosionKitTests/ParticlePhysicsTests.swift`

- [ ] **Step 1: Написать падающие тесты**

Файл `Tests/CellExplosionKitTests/ParticlePhysicsTests.swift`:

```swift
import XCTest
import CoreGraphics
@testable import CellExplosionKit

final class ParticlePhysicsTests: XCTestCase {

    private func makeParticle(vx: CGFloat = 0, vy: CGFloat = 0, alpha: CGFloat = 1, alphaDecay: CGFloat = 0) -> Particle {
        Particle(
            x: 0, y: 0, vx: vx, vy: vy,
            color: UIColor.red.cgColor, size: 1,
            alpha: alpha, alphaDecay: alphaDecay,
            wAmpX: 0, wAmpY: 0, wFreqX: 0, wFreqY: 0, wPhaseX: 0, wPhaseY: 0
        )
    }

    func test_step_appliesGravityToVy() {
        var p = makeParticle(vy: 0)
        let config = ExplosionConfiguration.default  // gravity = -50
        ParticlePhysics.step(&p, dt: 1.0, configuration: config)
        // vy += (0 + gravity) * dt = -50, потом damping: -50 * 0.985 = -49.25
        XCTAssertEqual(p.vy, -49.25, accuracy: 0.01)
    }

    func test_step_appliesDampingToVelocities() {
        var p = makeParticle(vx: 100, vy: 100)
        var config = ExplosionConfiguration.default
        config.gravity = 0   // изолируем демпинг
        ParticlePhysics.step(&p, dt: 0.001, configuration: config)
        // vx ≈ 100 * 0.985 = 98.5
        XCTAssertEqual(p.vx, 98.5, accuracy: 0.01)
        XCTAssertEqual(p.vy, 98.5, accuracy: 0.01)
    }

    func test_step_advancesPosition() {
        var p = makeParticle(vx: 10, vy: 20)
        var config = ExplosionConfiguration.default
        config.gravity = 0
        config.damping = 1.0  // отключаем демпинг
        ParticlePhysics.step(&p, dt: 0.5, configuration: config)
        // x += vx * dt = 5; y += vy * dt = 10
        XCTAssertEqual(p.x, 5.0, accuracy: 0.01)
        XCTAssertEqual(p.y, 10.0, accuracy: 0.01)
    }

    func test_step_decreasesAlpha() {
        var p = makeParticle(alpha: 1.0, alphaDecay: 0.5)
        let config = ExplosionConfiguration.default
        ParticlePhysics.step(&p, dt: 1.0, configuration: config)
        // alpha = max(0, 1.0 - 0.5 * 1.0) = 0.5
        XCTAssertEqual(p.alpha, 0.5, accuracy: 0.01)
    }

    func test_step_alphaClampedAtZero() {
        var p = makeParticle(alpha: 0.1, alphaDecay: 10)
        let config = ExplosionConfiguration.default
        ParticlePhysics.step(&p, dt: 1.0, configuration: config)
        XCTAssertEqual(p.alpha, 0)
    }

    func test_step_advancesAge() {
        var p = makeParticle()
        let config = ExplosionConfiguration.default
        ParticlePhysics.step(&p, dt: 0.25, configuration: config)
        XCTAssertEqual(p.age, 0.25, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Прогнать — должен FAIL (`ParticlePhysics` не найден)**

```bash
cd /Users/antonkorolev/Repository/collection-ios-ai/Packages/CellExplosionKit
xcodebuild test -scheme CellExplosionKit \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:CellExplosionKitTests/ParticlePhysicsTests 2>&1 | tail -15
```

Expected: ошибка компиляции `cannot find 'ParticlePhysics' in scope`.

- [ ] **Step 3: Реализовать ParticlePhysics.swift**

```swift
import Foundation
import CoreGraphics

enum ParticlePhysics {

    static func step(_ particle: inout Particle, dt: CGFloat, configuration: ExplosionConfiguration) {
        particle.age += dt

        let ax = sin(particle.age * particle.wFreqX * .pi * 2 + particle.wPhaseX) * particle.wAmpX
        let ay = sin(particle.age * particle.wFreqY * .pi * 2 + particle.wPhaseY) * particle.wAmpY

        particle.vx += ax * dt
        particle.vy += (ay + configuration.gravity) * dt
        particle.vx *= configuration.damping
        particle.vy *= configuration.damping

        particle.x += particle.vx * dt
        particle.y += particle.vy * dt

        particle.rotation += particle.vRotation * dt

        particle.alpha = max(0, particle.alpha - particle.alphaDecay * dt)
    }
}
```

- [ ] **Step 4: Прогнать тест — все должны PASS**

Та же команда из Step 2. Expected: 6 tests passed.

- [ ] **Step 5: Коммит**

```bash
git add Packages/CellExplosionKit/Sources/CellExplosionKit/Domain/ParticlePhysics.swift \
        Packages/CellExplosionKit/Tests/CellExplosionKitTests/ParticlePhysicsTests.swift
git commit -m "feat(CellExplosionKit): ParticlePhysics step simulation"
```

---

### Task 5: ParticleFactory (CGImage → [Particle])

**Files:**
- Create: `Packages/CellExplosionKit/Sources/CellExplosionKit/Domain/ParticleFactory.swift`
- Create: `Packages/CellExplosionKit/Tests/CellExplosionKitTests/ParticleFactoryTests.swift`

- [ ] **Step 1: Написать падающий тест**

Файл `Tests/CellExplosionKitTests/ParticleFactoryTests.swift`:

```swift
import XCTest
import CoreGraphics
import UIKit
@testable import CellExplosionKit

final class ParticleFactoryTests: XCTestCase {

    private func makeOpaqueRedImage(size: CGSize) -> CGImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return img.cgImage!
    }

    private func makeFullyTransparentImage(size: CGSize) -> CGImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { _ in
            // ничего не рисуем — прозрачно
        }
        return img.cgImage!
    }

    func test_makeParticles_fromTransparentImage_returnsEmpty() {
        let cg = makeFullyTransparentImage(size: CGSize(width: 10, height: 10))
        let parts = ParticleFactory.makeParticles(
            from: cg, scale: 1, origin: .zero, configuration: .default
        )
        XCTAssertEqual(parts.count, 0)
    }

    func test_makeParticles_fromOpaqueRed_returnsExpectedCount() {
        // 10×10 image, chunkSize=1 (= chunkPixels=1 при scale=1)
        // → 10*10 = 100 частиц
        let cg = makeOpaqueRedImage(size: CGSize(width: 10, height: 10))
        let parts = ParticleFactory.makeParticles(
            from: cg, scale: 1, origin: .zero, configuration: .default
        )
        XCTAssertEqual(parts.count, 100)
    }

    func test_makeParticles_offsetByOrigin() {
        let cg = makeOpaqueRedImage(size: CGSize(width: 2, height: 2))
        let origin = CGPoint(x: 100, y: 200)
        let parts = ParticleFactory.makeParticles(
            from: cg, scale: 1, origin: origin, configuration: .default
        )
        XCTAssertFalse(parts.isEmpty)
        // все x >= 100, y >= 200
        XCTAssertTrue(parts.allSatisfy { $0.x >= 100 && $0.y >= 200 })
    }

    func test_makeParticles_alphaDecayMatchesLifetime() {
        let cg = makeOpaqueRedImage(size: CGSize(width: 1, height: 1))
        var config = ExplosionConfiguration.default
        config.lifetimeRange = 1.0...1.0  // фиксированный lifetime = 1
        let parts = ParticleFactory.makeParticles(
            from: cg, scale: 1, origin: .zero, configuration: config
        )
        XCTAssertEqual(parts.count, 1)
        XCTAssertEqual(parts[0].alphaDecay, 1.0, accuracy: 0.01)
    }
}
```

- [ ] **Step 2: Прогнать — должен FAIL**

```bash
cd /Users/antonkorolev/Repository/collection-ios-ai/Packages/CellExplosionKit
xcodebuild test -scheme CellExplosionKit \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:CellExplosionKitTests/ParticleFactoryTests 2>&1 | tail -15
```

Expected: `cannot find 'ParticleFactory' in scope`.

- [ ] **Step 3: Реализовать ParticleFactory.swift**

```swift
import Foundation
import CoreGraphics
import UIKit

enum ParticleFactory {

    static func makeParticles(
        from cgImage: CGImage,
        scale: CGFloat,
        origin: CGPoint,
        configuration: ExplosionConfiguration
    ) -> [Particle] {
        let width = cgImage.width
        let height = cgImage.height
        let chunkPixels = max(1, Int(configuration.chunkSize * scale))

        var pixelData = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var particles: [Particle] = []
        let chunkSize = configuration.chunkSize
        let speed = configuration.speed
        let upBias = configuration.upBias
        let wobbleAmp = configuration.wobbleAmplitude
        let wobbleFreq = configuration.wobbleFrequency
        let lifetimeRange = configuration.lifetimeRange

        particles.reserveCapacity((width / chunkPixels) * (height / chunkPixels))

        var py = 0
        while py < height {
            var px = 0
            while px < width {
                let cx = min(px + chunkPixels / 2, width - 1)
                let cy = min(py + chunkPixels / 2, height - 1)
                let i = (cy * width + cx) * 4
                let a = pixelData[i + 3]
                if a > 30 {
                    let jitter: CGFloat = 0.08
                    let r = max(0, min(1, CGFloat(pixelData[i]) / 255 + CGFloat.random(in: -jitter...jitter)))
                    let g = max(0, min(1, CGFloat(pixelData[i + 1]) / 255 + CGFloat.random(in: -jitter...jitter)))
                    let b = max(0, min(1, CGFloat(pixelData[i + 2]) / 255 + CGFloat.random(in: -jitter...jitter)))
                    let alpha = CGFloat(a) / 255
                    let color = UIColor(red: r, green: g, blue: b, alpha: alpha).cgColor
                    let angle = CGFloat.random(in: 0...(.pi * 2))
                    let sp = speed * CGFloat.random(in: 0.5...1.3)
                    let lifetime = max(0.05, CGFloat.random(in: lifetimeRange))
                    particles.append(Particle(
                        x: origin.x + CGFloat(px) / scale + chunkSize / 2,
                        y: origin.y + CGFloat(py) / scale + chunkSize / 2,
                        vx: cos(angle) * sp,
                        vy: sin(angle) * sp - upBias * CGFloat.random(in: 0.5...1.0),
                        color: color,
                        size: chunkSize,
                        vRotation: CGFloat.random(in: -12...12),
                        alphaDecay: 1.0 / lifetime,
                        wAmpX: wobbleAmp * CGFloat.random(in: 0.4...1.6),
                        wAmpY: wobbleAmp * 0.3 * CGFloat.random(in: 0.4...1.4),
                        wFreqX: wobbleFreq * CGFloat.random(in: 0.5...1.5),
                        wFreqY: wobbleFreq * CGFloat.random(in: 0.5...1.5),
                        wPhaseX: CGFloat.random(in: 0...(.pi * 2)),
                        wPhaseY: CGFloat.random(in: 0...(.pi * 2))
                    ))
                }
                px += chunkPixels
            }
            py += chunkPixels
        }
        return particles
    }
}
```

- [ ] **Step 4: Прогнать тесты — PASS**

Та же команда из Step 2. Expected: 4 tests passed.

- [ ] **Step 5: Коммит**

```bash
git add Packages/CellExplosionKit/Sources/CellExplosionKit/Domain/ParticleFactory.swift \
        Packages/CellExplosionKit/Tests/CellExplosionKitTests/ParticleFactoryTests.swift
git commit -m "feat(CellExplosionKit): ParticleFactory from CGImage"
```

---

## Phase 3: UIKit layer

### Task 6: CollapsibleLayoutAttributes (с тестом copy)

**Files:**
- Create: `Packages/CellExplosionKit/Sources/CellExplosionKit/UIKit/CollapsibleLayoutAttributes.swift`
- Create: `Packages/CellExplosionKit/Tests/CellExplosionKitTests/CollapsibleLayoutAttributesTests.swift`

- [ ] **Step 1: Написать падающий тест**

```swift
import XCTest
import UIKit
@testable import CellExplosionKit

final class CollapsibleLayoutAttributesTests: XCTestCase {

    func test_defaultValues() {
        let attr = CollapsibleLayoutAttributes(forCellWith: IndexPath(item: 0, section: 0))
        XCTAssertEqual(attr.collapseProgress, 1)
        XCTAssertNil(attr.lockedHeight)
    }

    func test_copy_preservesCustomFields() {
        let attr = CollapsibleLayoutAttributes(forCellWith: IndexPath(item: 5, section: 0))
        attr.collapseProgress = 0.42
        attr.lockedHeight = 120

        let copy = attr.copy() as! CollapsibleLayoutAttributes
        XCTAssertEqual(copy.collapseProgress, 0.42)
        XCTAssertEqual(copy.lockedHeight, 120)
        XCTAssertEqual(copy.indexPath, IndexPath(item: 5, section: 0))
    }

    func test_equality_consideringCustomFields() {
        let a = CollapsibleLayoutAttributes(forCellWith: IndexPath(item: 0, section: 0))
        let b = CollapsibleLayoutAttributes(forCellWith: IndexPath(item: 0, section: 0))
        a.collapseProgress = 0.5
        b.collapseProgress = 0.5
        XCTAssertEqual(a, b)
        b.collapseProgress = 0.6
        XCTAssertNotEqual(a, b)
    }
}
```

- [ ] **Step 2: Прогнать — FAIL**

```bash
xcodebuild test -scheme CellExplosionKit \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:CellExplosionKitTests/CollapsibleLayoutAttributesTests 2>&1 | tail -10
```

Expected: `cannot find 'CollapsibleLayoutAttributes' in scope`.

- [ ] **Step 3: Реализовать CollapsibleLayoutAttributes.swift**

```swift
import UIKit

public final class CollapsibleLayoutAttributes: UICollectionViewLayoutAttributes {

    public var collapseProgress: CGFloat = 1.0
    public var lockedHeight: CGFloat?

    public override func copy(with zone: NSZone? = nil) -> Any {
        let copy = super.copy(with: zone) as! CollapsibleLayoutAttributes
        copy.collapseProgress = collapseProgress
        copy.lockedHeight = lockedHeight
        return copy
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? CollapsibleLayoutAttributes else { return false }
        guard super.isEqual(other) else { return false }
        return collapseProgress == other.collapseProgress && lockedHeight == other.lockedHeight
    }
}
```

- [ ] **Step 4: Прогнать — PASS**

Та же команда из Step 2. Expected: 3 tests passed.

- [ ] **Step 5: Коммит**

```bash
git add Packages/CellExplosionKit/Sources/CellExplosionKit/UIKit/CollapsibleLayoutAttributes.swift \
        Packages/CellExplosionKit/Tests/CellExplosionKitTests/CollapsibleLayoutAttributesTests.swift
git commit -m "feat(CellExplosionKit): CollapsibleLayoutAttributes"
```

---

### Task 7: CollapseTracker (internal, без отдельных юнит-тестов)

Проверяется индиректно через тесты координатора. CALayer + CABasicAnimation поведение покрывается Apple-фреймворком.

**Files:**
- Create: `Packages/CellExplosionKit/Sources/CellExplosionKit/UIKit/CollapseTracker.swift`

- [ ] **Step 1: Реализовать CollapseTracker.swift**

```swift
import UIKit
import QuartzCore

final class CollapseTracker {

    static let initialHeight: CGFloat = 1000

    private let layer = CALayer()
    private weak var container: UIView?

    init(container: UIView) {
        self.container = container
        layer.frame = CGRect(x: -10_000, y: -10_000, width: 1, height: Self.initialHeight)
        container.layer.addSublayer(layer)
    }

    func start(duration: TimeInterval, completion: @escaping () -> Void) {
        let anim = CABasicAnimation(keyPath: "bounds.size.height")
        anim.fromValue = Self.initialHeight
        anim.toValue = 0
        anim.duration = duration
        anim.timingFunction = CAMediaTimingFunction(name: .easeIn)
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false
        layer.add(anim, forKey: "shrink")

        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeIn))
        CATransaction.setCompletionBlock(completion)
        CATransaction.commit()
    }

    /// Возвращает текущее значение [0, 1], где 1 = только начали, 0 = коллапс завершён.
    func currentFraction() -> CGFloat {
        let presentHeight = layer.presentation()?.bounds.size.height ?? Self.initialHeight
        return max(0, min(1, presentHeight / Self.initialHeight))
    }

    deinit {
        layer.removeFromSuperlayer()
    }
}
```

- [ ] **Step 2: Проверить компиляцию**

```bash
cd /Users/antonkorolev/Repository/collection-ios-ai/Packages/CellExplosionKit
xcodebuild build -scheme CellExplosionKit \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Коммит**

```bash
git add Packages/CellExplosionKit/Sources/CellExplosionKit/UIKit/CollapseTracker.swift
git commit -m "feat(CellExplosionKit): CollapseTracker (CALayer-based progress)"
```

---

### Task 8: CellCollapseLayoutController + Delegate

**Files:**
- Create: `Packages/CellExplosionKit/Sources/CellExplosionKit/UIKit/CellCollapseLayoutController.swift`
- Create: `Packages/CellExplosionKit/Tests/CellExplosionKitTests/CellCollapseLayoutControllerTests.swift`

- [ ] **Step 1: Написать падающий тест**

```swift
import XCTest
import UIKit
@testable import CellExplosionKit

private final class TestUpdateItem: UICollectionViewUpdateItem {
    private let _action: UICollectionUpdateAction
    private let _indexPathBeforeUpdate: IndexPath?

    init(action: UICollectionUpdateAction, indexPathBeforeUpdate: IndexPath?) {
        self._action = action
        self._indexPathBeforeUpdate = indexPathBeforeUpdate
        super.init()
    }

    override var updateAction: UICollectionUpdateAction { _action }
    override var indexPathBeforeUpdate: IndexPath? { _indexPathBeforeUpdate }
}

private final class CapturingDelegate: CellCollapseLayoutControllerDelegate {
    var captured: [IndexPath] = []
    func cellCollapseLayoutController(
        _ controller: CellCollapseLayoutController,
        willProcessDeletionsAt indexPaths: [IndexPath]
    ) {
        captured = indexPaths
    }
}

final class CellCollapseLayoutControllerTests: XCTestCase {

    func test_prepare_notifiesDelegateOnlyAboutDeletes() {
        let controller = CellCollapseLayoutController()
        let delegate = CapturingDelegate()
        controller.delegate = delegate

        let items: [UICollectionViewUpdateItem] = [
            TestUpdateItem(action: .delete, indexPathBeforeUpdate: IndexPath(item: 0, section: 0)),
            TestUpdateItem(action: .insert, indexPathBeforeUpdate: IndexPath(item: 5, section: 0)),
            TestUpdateItem(action: .delete, indexPathBeforeUpdate: IndexPath(item: 2, section: 0)),
        ]

        controller.prepare(updateItems: items)

        XCTAssertEqual(delegate.captured, [
            IndexPath(item: 0, section: 0),
            IndexPath(item: 2, section: 0),
        ])
    }

    func test_prepare_withNoDeletes_doesNotNotify() {
        let controller = CellCollapseLayoutController()
        let delegate = CapturingDelegate()
        controller.delegate = delegate

        let items: [UICollectionViewUpdateItem] = [
            TestUpdateItem(action: .insert, indexPathBeforeUpdate: nil),
        ]
        controller.prepare(updateItems: items)

        XCTAssertTrue(delegate.captured.isEmpty)
    }

    func test_finalAttributes_returnsBase_whenNotMarked() {
        let controller = CellCollapseLayoutController()
        let base = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: 0, section: 0))
        base.frame = CGRect(x: 0, y: 0, width: 100, height: 60)

        let result = controller.finalAttributes(for: IndexPath(item: 0, section: 0), base: base)

        XCTAssertNotNil(result)
        XCTAssertFalse(result is CollapsibleLayoutAttributes)
        XCTAssertEqual(result?.frame, base.frame)
    }

    func test_finalAttributes_returnsCollapsible_whenMarked() {
        let controller = CellCollapseLayoutController()
        let base = CollapsibleLayoutAttributes(forCellWith: IndexPath(item: 0, section: 0))
        base.frame = CGRect(x: 0, y: 0, width: 100, height: 60)

        controller.markCollapsing(at: [IndexPath(item: 0, section: 0)])
        let result = controller.finalAttributes(for: IndexPath(item: 0, section: 0), base: base) as? CollapsibleLayoutAttributes

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.frame.height, 0, "height collapsed to 0")
        XCTAssertEqual(result?.frame.origin, base.frame.origin)
        XCTAssertEqual(result?.lockedHeight, 60)
        XCTAssertEqual(result?.collapseProgress, 0)
    }

    func test_finalize_clearsMarkedSet() {
        let controller = CellCollapseLayoutController()
        let base = CollapsibleLayoutAttributes(forCellWith: IndexPath(item: 0, section: 0))
        base.frame = CGRect(x: 0, y: 0, width: 100, height: 60)
        controller.markCollapsing(at: [IndexPath(item: 0, section: 0)])
        controller.finalize()

        let result = controller.finalAttributes(for: IndexPath(item: 0, section: 0), base: base)
        XCTAssertFalse(result is CollapsibleLayoutAttributes, "after finalize, mark cleared, base returned")
    }
}
```

- [ ] **Step 2: Прогнать — FAIL**

```bash
xcodebuild test -scheme CellExplosionKit \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:CellExplosionKitTests/CellCollapseLayoutControllerTests 2>&1 | tail -15
```

Expected: `cannot find 'CellCollapseLayoutController' in scope`.

- [ ] **Step 3: Реализовать CellCollapseLayoutController.swift**

```swift
import UIKit

public protocol CellCollapseLayoutControllerDelegate: AnyObject {
    func cellCollapseLayoutController(
        _ controller: CellCollapseLayoutController,
        willProcessDeletionsAt indexPaths: [IndexPath]
    )
}

public final class CellCollapseLayoutController {

    public weak var delegate: CellCollapseLayoutControllerDelegate?
    public var configuration: ExplosionConfiguration

    private var marked: Set<IndexPath> = []

    public init(configuration: ExplosionConfiguration = .default) {
        self.configuration = configuration
    }

    public func prepare(updateItems: [UICollectionViewUpdateItem]) {
        let deletePaths = updateItems.compactMap { item -> IndexPath? in
            guard item.updateAction == .delete else { return nil }
            return item.indexPathBeforeUpdate
        }
        guard !deletePaths.isEmpty else { return }
        delegate?.cellCollapseLayoutController(self, willProcessDeletionsAt: deletePaths)
    }

    public func finalize() {
        marked.removeAll()
    }

    public func markCollapsing(at indexPaths: [IndexPath]) {
        for path in indexPaths { marked.insert(path) }
    }

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
        // Fallback: layout не настроил layoutAttributesClass — вернём base со схлопнутой
        // высотой без custom-полей (коллапс будет, но Cell без shrinkController не сможет
        // прижать content к низу — graceful degradation).
        let copy = base.copy() as! UICollectionViewLayoutAttributes
        var frame = copy.frame
        frame.size.height = 0
        copy.frame = frame
        copy.alpha = 1
        return copy
    }
}
```

- [ ] **Step 4: Прогнать тесты — все PASS**

Та же команда из Step 2. Expected: 5 tests passed.

- [ ] **Step 5: Коммит**

```bash
git add Packages/CellExplosionKit/Sources/CellExplosionKit/UIKit/CellCollapseLayoutController.swift \
        Packages/CellExplosionKit/Tests/CellExplosionKitTests/CellCollapseLayoutControllerTests.swift
git commit -m "feat(CellExplosionKit): CellCollapseLayoutController with delegate"
```

---

### Task 9: CellShrinkController

**Files:**
- Create: `Packages/CellExplosionKit/Sources/CellExplosionKit/UIKit/CellShrinkController.swift`
- Create: `Packages/CellExplosionKit/Tests/CellExplosionKitTests/CellShrinkControllerTests.swift`

- [ ] **Step 1: Написать падающий тест**

```swift
import XCTest
import UIKit
@testable import CellExplosionKit

final class CellShrinkControllerTests: XCTestCase {

    func test_apply_layoutSubviews_noLockedHeight_doesNothing() {
        let controller = CellShrinkController()
        let contentView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 60))
        let cellBounds = CGRect(x: 0, y: 0, width: 100, height: 60)
        controller.apply(toContentView: contentView, cellBounds: cellBounds)
        XCTAssertEqual(contentView.frame, CGRect(x: 0, y: 0, width: 100, height: 60))
    }

    func test_apply_whenCellShorterThanLocked_pinsContentToBottom() {
        let controller = CellShrinkController()
        let attr = CollapsibleLayoutAttributes(forCellWith: IndexPath(item: 0, section: 0))
        attr.lockedHeight = 60
        controller.apply(layoutAttributes: attr)

        let contentView = UIView(frame: .zero)
        let cellBounds = CGRect(x: 0, y: 0, width: 100, height: 20)  // schлопнулась до 20
        controller.apply(toContentView: contentView, cellBounds: cellBounds)

        XCTAssertEqual(contentView.bounds.size, CGSize(width: 100, height: 60))
        XCTAssertEqual(contentView.center, CGPoint(x: 50, y: 20 + 60/2))
    }

    func test_apply_whenCellTallerThanLocked_doesNothing() {
        let controller = CellShrinkController()
        let attr = CollapsibleLayoutAttributes(forCellWith: IndexPath(item: 0, section: 0))
        attr.lockedHeight = 60
        controller.apply(layoutAttributes: attr)

        let contentView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 60))
        let cellBounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        let originalFrame = contentView.frame
        controller.apply(toContentView: contentView, cellBounds: cellBounds)

        XCTAssertEqual(contentView.frame, originalFrame)
    }

    func test_reset_clearsLockedHeight() {
        let controller = CellShrinkController()
        let attr = CollapsibleLayoutAttributes(forCellWith: IndexPath(item: 0, section: 0))
        attr.lockedHeight = 60
        controller.apply(layoutAttributes: attr)
        controller.reset()

        let contentView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 60))
        let cellBounds = CGRect(x: 0, y: 0, width: 100, height: 20)
        let originalFrame = contentView.frame
        controller.apply(toContentView: contentView, cellBounds: cellBounds)

        XCTAssertEqual(contentView.frame, originalFrame, "after reset, behaves as no-op")
    }

    func test_apply_nonCollapsibleAttributes_doesNotAffect() {
        let controller = CellShrinkController()
        let attr = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: 0, section: 0))
        controller.apply(layoutAttributes: attr)

        let contentView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 60))
        let cellBounds = CGRect(x: 0, y: 0, width: 100, height: 20)
        let originalFrame = contentView.frame
        controller.apply(toContentView: contentView, cellBounds: cellBounds)

        XCTAssertEqual(contentView.frame, originalFrame)
    }
}
```

- [ ] **Step 2: Прогнать — FAIL**

```bash
xcodebuild test -scheme CellExplosionKit \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:CellExplosionKitTests/CellShrinkControllerTests 2>&1 | tail -15
```

Expected: `cannot find 'CellShrinkController' in scope`.

- [ ] **Step 3: Реализовать CellShrinkController.swift**

```swift
import UIKit

public final class CellShrinkController {

    private var lockedHeight: CGFloat?

    public init() {}

    public func apply(layoutAttributes: UICollectionViewLayoutAttributes) {
        guard let collapsible = layoutAttributes as? CollapsibleLayoutAttributes else { return }
        if let locked = collapsible.lockedHeight {
            self.lockedHeight = locked
        }
    }

    public func apply(toContentView contentView: UIView, cellBounds: CGRect) {
        guard let lockedHeight, cellBounds.height < lockedHeight else { return }
        contentView.bounds = CGRect(x: 0, y: 0, width: cellBounds.width, height: lockedHeight)
        contentView.center = CGPoint(x: cellBounds.width / 2, y: cellBounds.height + lockedHeight / 2)
    }

    public func reset() {
        lockedHeight = nil
    }
}
```

- [ ] **Step 4: Прогнать тесты — PASS**

Та же команда из Step 2. Expected: 5 tests passed.

- [ ] **Step 5: Коммит**

```bash
git add Packages/CellExplosionKit/Sources/CellExplosionKit/UIKit/CellShrinkController.swift \
        Packages/CellExplosionKit/Tests/CellExplosionKitTests/CellShrinkControllerTests.swift
git commit -m "feat(CellExplosionKit): CellShrinkController"
```

---

### Task 10: DefaultCellSnapshotProvider

**Files:**
- Create: `Packages/CellExplosionKit/Sources/CellExplosionKit/UIKit/DefaultCellSnapshotProvider.swift`

Тестов не пишем — это тонкая обёртка над UIKit-рендерингом, эффективнее проверяется в координаторе через MockSnapshotProvider.

- [ ] **Step 1: Реализовать DefaultCellSnapshotProvider.swift**

```swift
import UIKit

public final class DefaultCellSnapshotProvider: CellSnapshotProvider {

    public init() {}

    public func snapshot(of cell: UICollectionViewCell) -> UIImage? {
        let bounds = cell.bounds
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { _ in
            cell.drawHierarchy(in: bounds, afterScreenUpdates: false)
        }
    }

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
```

- [ ] **Step 2: Build**

```bash
xcodebuild build -scheme CellExplosionKit \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Коммит**

```bash
git add Packages/CellExplosionKit/Sources/CellExplosionKit/UIKit/DefaultCellSnapshotProvider.swift
git commit -m "feat(CellExplosionKit): DefaultCellSnapshotProvider"
```

---

### Task 11: CellExplosionCoordinator (integration test через мок-providers)

Координатор подписывается на `layoutController.delegate` и при сигнале `willProcessDeletionsAt`:
1. фильтрует через `shouldExplode`;
2. для каждого path запрашивает ячейку через `cellProvider(path)` (closure-абстракция вместо прямого `collectionView.cellForItem`, для тестируемости);
3. снимает snapshot, считает frame, маркирует в layoutController;
4. стартует tracker и DisplayLink.

DisplayLink-цикл тестируем вручную через публичный `tick()` метод (internal-видимость + `@testable` доступ).

**Files:**
- Create: `Packages/CellExplosionKit/Sources/CellExplosionKit/UIKit/CellExplosionCoordinator.swift`
- Create: `Packages/CellExplosionKit/Tests/CellExplosionKitTests/CellExplosionCoordinatorTests.swift`

- [ ] **Step 1: Написать падающий тест**

```swift
import XCTest
import UIKit
@testable import CellExplosionKit

private final class MockRenderer: ParticleRenderer {
    let view = UIView()
    var receivedBatches: [[Particle]] = []
    func addParticles(_ particles: [Particle]) {
        receivedBatches.append(particles)
    }
}

private final class MockSnapshotProvider: CellSnapshotProvider {
    var snapshotImage: UIImage?
    var croppedImage: UIImage?
    var snapshotCalls = 0
    var cropCalls = 0
    func snapshot(of cell: UICollectionViewCell) -> UIImage? {
        snapshotCalls += 1
        return snapshotImage
    }
    func cropBottom(of image: UIImage, toPoints points: CGFloat) -> UIImage? {
        cropCalls += 1
        return croppedImage
    }
}

final class CellExplosionCoordinatorTests: XCTestCase {

    private func makeImage(size: CGSize = CGSize(width: 4, height: 4)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func makeCollectionView() -> UICollectionView {
        UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), collectionViewLayout: UICollectionViewFlowLayout())
    }

    func test_willProcessDeletions_shouldExplodeFalse_doesNotMark() {
        let container = UIView()
        let layoutController = CellCollapseLayoutController()
        let renderer = MockRenderer()
        let snapshot = MockSnapshotProvider()
        snapshot.snapshotImage = makeImage()

        let coordinator = CellExplosionCoordinator(
            collectionView: makeCollectionView(),
            container: container,
            renderer: renderer,
            layoutController: layoutController,
            snapshotProvider: snapshot
        )
        coordinator.shouldExplode = { _ in false }
        coordinator.cellProvider = { _ in UICollectionViewCell(frame: CGRect(x: 0, y: 0, width: 100, height: 60)) }

        layoutController.prepare(updateItems: [
            TestUpdate(action: .delete, indexPath: IndexPath(item: 0, section: 0))
        ])

        XCTAssertEqual(snapshot.snapshotCalls, 0)
        XCTAssertTrue(coordinator.pendingExplosionsForTesting.isEmpty)
    }

    func test_willProcessDeletions_isEnabledFalse_doesNotMark() {
        let container = UIView()
        let layoutController = CellCollapseLayoutController()
        let renderer = MockRenderer()
        let snapshot = MockSnapshotProvider()
        snapshot.snapshotImage = makeImage()

        let coordinator = CellExplosionCoordinator(
            collectionView: makeCollectionView(),
            container: container,
            renderer: renderer,
            layoutController: layoutController,
            snapshotProvider: snapshot
        )
        coordinator.isEnabled = false
        coordinator.cellProvider = { _ in UICollectionViewCell(frame: CGRect(x: 0, y: 0, width: 100, height: 60)) }

        layoutController.prepare(updateItems: [
            TestUpdate(action: .delete, indexPath: IndexPath(item: 0, section: 0))
        ])

        XCTAssertEqual(snapshot.snapshotCalls, 0)
        XCTAssertTrue(coordinator.pendingExplosionsForTesting.isEmpty)
    }

    func test_willProcessDeletions_cellNotFound_skipsPath() {
        let container = UIView()
        let layoutController = CellCollapseLayoutController()
        let renderer = MockRenderer()
        let snapshot = MockSnapshotProvider()
        snapshot.snapshotImage = makeImage()

        let coordinator = CellExplosionCoordinator(
            collectionView: makeCollectionView(),
            container: container,
            renderer: renderer,
            layoutController: layoutController,
            snapshotProvider: snapshot
        )
        coordinator.cellProvider = { _ in nil }

        layoutController.prepare(updateItems: [
            TestUpdate(action: .delete, indexPath: IndexPath(item: 0, section: 0))
        ])

        XCTAssertEqual(snapshot.snapshotCalls, 0)
        XCTAssertTrue(coordinator.pendingExplosionsForTesting.isEmpty)
    }

    func test_willProcessDeletions_happyPath_snapshotAndMark() {
        let container = UIView()
        let layoutController = CellCollapseLayoutController()
        let renderer = MockRenderer()
        let snapshot = MockSnapshotProvider()
        snapshot.snapshotImage = makeImage()

        let cv = makeCollectionView()
        let coordinator = CellExplosionCoordinator(
            collectionView: cv,
            container: container,
            renderer: renderer,
            layoutController: layoutController,
            snapshotProvider: snapshot
        )
        let cell = UICollectionViewCell(frame: CGRect(x: 10, y: 20, width: 100, height: 60))
        cv.addSubview(cell)
        coordinator.cellProvider = { _ in cell }

        layoutController.prepare(updateItems: [
            TestUpdate(action: .delete, indexPath: IndexPath(item: 0, section: 0))
        ])

        XCTAssertEqual(snapshot.snapshotCalls, 1)
        XCTAssertEqual(coordinator.pendingExplosionsForTesting.count, 1)
        // markCollapsing был вызван:
        let base = CollapsibleLayoutAttributes(forCellWith: IndexPath(item: 0, section: 0))
        base.frame = CGRect(x: 0, y: 0, width: 100, height: 60)
        let attrs = layoutController.finalAttributes(for: IndexPath(item: 0, section: 0), base: base)
        XCTAssertTrue(attrs is CollapsibleLayoutAttributes)
    }

    func test_tick_belowThreshold_burstsAndClearsPending() {
        let container = UIView()
        let layoutController = CellCollapseLayoutController()
        let renderer = MockRenderer()
        let snapshot = MockSnapshotProvider()
        snapshot.snapshotImage = makeImage()
        snapshot.croppedImage = makeImage(size: CGSize(width: 4, height: 1))

        let cv = makeCollectionView()
        let coordinator = CellExplosionCoordinator(
            collectionView: cv,
            container: container,
            renderer: renderer,
            layoutController: layoutController,
            snapshotProvider: snapshot
        )
        let cell = UICollectionViewCell(frame: CGRect(x: 0, y: 0, width: 100, height: 60))
        cv.addSubview(cell)
        coordinator.cellProvider = { _ in cell }

        layoutController.prepare(updateItems: [
            TestUpdate(action: .delete, indexPath: IndexPath(item: 0, section: 0))
        ])
        XCTAssertEqual(coordinator.pendingExplosionsForTesting.count, 1)

        // эмулируем тик с fraction=0.1 → currentHeight = 60*0.1 = 6 < threshold(12)
        coordinator.tickForTesting(fractionOverride: 0.1)

        XCTAssertEqual(snapshot.cropCalls, 1)
        XCTAssertEqual(renderer.receivedBatches.count, 1)
        XCTAssertFalse(renderer.receivedBatches[0].isEmpty)
        XCTAssertTrue(coordinator.pendingExplosionsForTesting.isEmpty)
    }

    func test_tick_aboveThreshold_doesNotBurst() {
        let container = UIView()
        let layoutController = CellCollapseLayoutController()
        let renderer = MockRenderer()
        let snapshot = MockSnapshotProvider()
        snapshot.snapshotImage = makeImage()

        let cv = makeCollectionView()
        let coordinator = CellExplosionCoordinator(
            collectionView: cv,
            container: container,
            renderer: renderer,
            layoutController: layoutController,
            snapshotProvider: snapshot
        )
        let cell = UICollectionViewCell(frame: CGRect(x: 0, y: 0, width: 100, height: 60))
        cv.addSubview(cell)
        coordinator.cellProvider = { _ in cell }

        layoutController.prepare(updateItems: [
            TestUpdate(action: .delete, indexPath: IndexPath(item: 0, section: 0))
        ])

        // fraction=0.5 → currentHeight = 30 > threshold(12)
        coordinator.tickForTesting(fractionOverride: 0.5)

        XCTAssertEqual(snapshot.cropCalls, 0)
        XCTAssertEqual(renderer.receivedBatches.count, 0)
        XCTAssertEqual(coordinator.pendingExplosionsForTesting.count, 1)
    }
}

// Helper из CellCollapseLayoutControllerTests (повтор для изоляции теста)
private final class TestUpdate: UICollectionViewUpdateItem {
    private let _action: UICollectionUpdateAction
    private let _path: IndexPath?
    init(action: UICollectionUpdateAction, indexPath: IndexPath?) {
        self._action = action; self._path = indexPath
        super.init()
    }
    override var updateAction: UICollectionUpdateAction { _action }
    override var indexPathBeforeUpdate: IndexPath? { _path }
}
```

- [ ] **Step 2: Прогнать — FAIL**

```bash
xcodebuild test -scheme CellExplosionKit \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:CellExplosionKitTests/CellExplosionCoordinatorTests 2>&1 | tail -15
```

Expected: `cannot find 'CellExplosionCoordinator' in scope`.

- [ ] **Step 3: Реализовать CellExplosionCoordinator.swift**

```swift
import UIKit
import QuartzCore

public final class CellExplosionCoordinator {

    public var isEnabled: Bool = true
    public var shouldExplode: (IndexPath) -> Bool = { _ in true }
    public var configuration: ExplosionConfiguration

    /// Перекрываемый источник ячейки по indexPath. Используется в тестах для подмены.
    /// По умолчанию = collectionView.cellForItem(at:).
    public var cellProvider: (IndexPath) -> UICollectionViewCell?

    private weak var collectionView: UICollectionView?
    private weak var container: UIView?
    private let renderer: ParticleRenderer
    private let layoutController: CellCollapseLayoutController
    private let snapshotProvider: CellSnapshotProvider

    struct PendingExplosion {
        let image: UIImage
        let originalFrame: CGRect
        let initialHeight: CGFloat
        let tracker: CollapseTracker
    }

    private var pendingExplosions: [PendingExplosion] = []
    private var displayLink: CADisplayLink?

    public init(
        collectionView: UICollectionView,
        container: UIView,
        renderer: ParticleRenderer,
        layoutController: CellCollapseLayoutController,
        snapshotProvider: CellSnapshotProvider = DefaultCellSnapshotProvider(),
        configuration: ExplosionConfiguration = .default
    ) {
        self.collectionView = collectionView
        self.container = container
        self.renderer = renderer
        self.layoutController = layoutController
        self.snapshotProvider = snapshotProvider
        self.configuration = configuration
        self.cellProvider = { [weak collectionView] path in
            collectionView?.cellForItem(at: path)
        }
        layoutController.delegate = self
    }

    deinit {
        displayLink?.invalidate()
    }

    private func handleDeletions(_ paths: [IndexPath]) {
        guard isEnabled, let container else { return }
        let filtered = paths.filter { shouldExplode($0) }
        guard !filtered.isEmpty else { return }

        var ready: [IndexPath] = []
        let tracker = CollapseTracker(container: container)

        for path in filtered {
            guard let cell = cellProvider(path),
                  let image = snapshotProvider.snapshot(of: cell) else { continue }
            let frameInContainer = cell.convert(cell.bounds, to: container)
            pendingExplosions.append(PendingExplosion(
                image: image,
                originalFrame: frameInContainer,
                initialHeight: cell.bounds.height,
                tracker: tracker
            ))
            ready.append(path)
        }

        guard !ready.isEmpty else { return }
        layoutController.markCollapsing(at: ready)
        tracker.start(duration: configuration.collapseDuration) {}
        startDisplayLinkIfNeeded()
    }

    private func startDisplayLinkIfNeeded() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func tick() {
        processTick(fractionOverride: nil)
    }

    private func processTick(fractionOverride: CGFloat?) {
        guard !pendingExplosions.isEmpty else {
            displayLink?.invalidate()
            displayLink = nil
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
            displayLink?.invalidate()
            displayLink = nil
        }
    }
}

extension CellExplosionCoordinator: CellCollapseLayoutControllerDelegate {
    public func cellCollapseLayoutController(
        _ controller: CellCollapseLayoutController,
        willProcessDeletionsAt indexPaths: [IndexPath]
    ) {
        handleDeletions(indexPaths)
    }
}

// MARK: - Test hooks
extension CellExplosionCoordinator {
    var pendingExplosionsForTesting: [PendingExplosion] { pendingExplosions }
    func tickForTesting(fractionOverride: CGFloat) {
        processTick(fractionOverride: fractionOverride)
    }
}
```

- [ ] **Step 4: Прогнать все тесты — PASS**

Та же команда из Step 2. Expected: 6 tests passed.

- [ ] **Step 5: Коммит**

```bash
git add Packages/CellExplosionKit/Sources/CellExplosionKit/UIKit/CellExplosionCoordinator.swift \
        Packages/CellExplosionKit/Tests/CellExplosionKitTests/CellExplosionCoordinatorTests.swift
git commit -m "feat(CellExplosionKit): CellExplosionCoordinator with delegate flow"
```

---

## Phase 4: Rendering layer

### Task 12: SpriteKitParticleScene + SpriteKitParticleRenderer

Тестов на game-loop SpriteKit не пишем — это Apple-фреймворк, эффективнее проверяется руками в demo.

**Files:**
- Create: `Packages/CellExplosionKit/Sources/CellExplosionKit/Rendering/SpriteKitParticleScene.swift`
- Create: `Packages/CellExplosionKit/Sources/CellExplosionKit/Rendering/SpriteKitParticleRenderer.swift`

- [ ] **Step 1: Создать SpriteKitParticleScene.swift**

```swift
import UIKit
import SpriteKit

final class SpriteKitParticleScene: SKScene {

    var configuration: ExplosionConfiguration = .default

    private var particles: [Particle] = []
    private var nodes: [SKSpriteNode] = []
    private var dead: [Bool] = []
    private var aliveCount: Int = 0
    private var lastTime: TimeInterval = 0

    func addParticles(_ newParticles: [Particle]) {
        let h = size.height
        for p in newParticles {
            let node = SKSpriteNode(
                color: UIColor(cgColor: p.color),
                size: CGSize(width: p.size, height: p.size)
            )
            node.position = CGPoint(x: p.x, y: h - p.y)
            addChild(node)
            nodes.append(node)
            particles.append(p)
            dead.append(false)
        }
        aliveCount += newParticles.count
    }

    override func update(_ currentTime: TimeInterval) {
        if lastTime == 0 {
            lastTime = currentTime
            return
        }
        let dt = CGFloat(min(0.05, currentTime - lastTime))
        lastTime = currentTime

        if particles.isEmpty { return }

        let h = size.height
        let topLimit: CGFloat = -50
        let bottomLimit = h + 50

        for i in particles.indices {
            if dead[i] { continue }

            ParticlePhysics.step(&particles[i], dt: dt, configuration: configuration)

            if particles[i].y < topLimit || particles[i].y > bottomLimit || particles[i].alpha < 0.02 {
                nodes[i].removeFromParent()
                dead[i] = true
                aliveCount -= 1
            } else {
                nodes[i].position = CGPoint(x: particles[i].x, y: h - particles[i].y)
                nodes[i].zRotation = -particles[i].rotation
                nodes[i].alpha = particles[i].alpha
            }
        }

        if aliveCount == 0 {
            particles.removeAll(keepingCapacity: true)
            nodes.removeAll(keepingCapacity: true)
            dead.removeAll(keepingCapacity: true)
        }
    }
}
```

- [ ] **Step 2: Создать SpriteKitParticleRenderer.swift**

```swift
import UIKit
import SpriteKit

public final class SpriteKitParticleRenderer: ParticleRenderer {

    private let skView: SKView
    private let scene: SpriteKitParticleScene

    public var view: UIView { skView }

    public init(configuration: ExplosionConfiguration = .default) {
        let v = SKView(frame: .zero)
        v.backgroundColor = .clear
        v.allowsTransparency = true
        v.isUserInteractionEnabled = false
        v.ignoresSiblingOrder = true
        v.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let s = SpriteKitParticleScene()
        s.configuration = configuration
        s.scaleMode = .resizeFill
        s.backgroundColor = .clear

        v.presentScene(s)
        self.skView = v
        self.scene = s
    }

    public func addParticles(_ particles: [Particle]) {
        // Сцена использует size SKView; перед добавлением убедимся что size актуальный.
        scene.size = skView.bounds.size
        scene.addParticles(particles)
    }
}
```

- [ ] **Step 3: Build всего пакета**

```bash
xcodebuild build -scheme CellExplosionKit \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Прогнать ВСЕ тесты пакета**

```bash
xcodebuild test -scheme CellExplosionKit \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20
```

Expected: всё что было до этого + `Test Suite 'All tests' passed`. Должно быть ~26 тестов.

- [ ] **Step 5: Коммит**

```bash
git add Packages/CellExplosionKit/Sources/CellExplosionKit/Rendering/
git commit -m "feat(CellExplosionKit): SpriteKit renderer implementation"
```

---

## Phase 5: Demo app migration

### Task 13: Подключить локальный пакет к Xcode-проекту CollectionDemo

Это **ручной шаг** через Xcode UI — Claude этого сделать не может.

- [ ] **Step 1: Открыть проект в Xcode**

```bash
open /Users/antonkorolev/Repository/collection-ios-ai/App/CollectionDemo.xcodeproj
```

- [ ] **Step 2: Добавить local SPM package**

В Xcode: `File → Add Package Dependencies… → Add Local…` → выбрать папку `/Users/antonkorolev/Repository/collection-ios-ai/Packages/CellExplosionKit` → `Add Package` → в диалоге выбора target поставить галку напротив `CollectionDemo` и продукт `CellExplosionKit` → `Add Package`.

- [ ] **Step 3: Проверить что проект собирается**

В Xcode: `Cmd+B`. Должно собраться без ошибок.

Из терминала:
```bash
cd /Users/antonkorolev/Repository/collection-ios-ai
xcodebuild build -project App/CollectionDemo.xcodeproj \
  -scheme CollectionDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Коммит изменений pbxproj**

```bash
cd /Users/antonkorolev/Repository/collection-ios-ai
git add App/CollectionDemo.xcodeproj/project.pbxproj App/CollectionDemo.xcodeproj/project.xcworkspace
git commit -m "chore(CollectionDemo): add local CellExplosionKit package dependency"
```

---

### Task 14: Удалить старые файлы анимации в demo

**Files:**
- Delete: `App/CollectionDemo/ExplosionView.swift`
- Delete: `App/CollectionDemo/CellExplosionAnimator.swift`

После удаления проект **не собирается** — это ожидаемо. Следующие задачи восстановят его на основе пакета.

- [ ] **Step 1: Удалить файлы из файловой системы**

```bash
cd /Users/antonkorolev/Repository/collection-ios-ai
rm App/CollectionDemo/ExplosionView.swift App/CollectionDemo/CellExplosionAnimator.swift
```

- [ ] **Step 2: Удалить ссылки из project.pbxproj**

Это ручной шаг в Xcode: в Project navigator найти удалённые файлы (они подсвечены красным), выделить и нажать Delete → `Remove Reference`.

Альтернатива через CLI (хрупко, но возможно):
```bash
# Просто опираемся на следующий build — он покажет нужные правки.
```

- [ ] **Step 3: Не коммитим — следующая задача восстановит работу**

---

### Task 15: Модифицировать MessageFlowLayout — встроить CellCollapseLayoutController

**Files:**
- Modify: `App/CollectionDemo/MessageFlowLayout.swift`

Текущий саб-класс остаётся, но логика collapseingIndexPaths переезжает в `CellCollapseLayoutController`.

- [ ] **Step 1: Заменить содержимое MessageFlowLayout.swift**

```swift
//
//  MessageFlowLayout.swift
//  CollectionDemo
//

import UIKit
import CellExplosionKit

final class MessageFlowLayout: UICollectionViewFlowLayout {

    let collapseController: CellCollapseLayoutController

    init(collapseController: CellCollapseLayoutController) {
        self.collapseController = collapseController
        super.init()
        scrollDirection = .vertical
        estimatedItemSize = CGSize(width: UIScreen.main.bounds.width, height: 60)
        minimumLineSpacing = 4
        minimumInteritemSpacing = 0
        sectionInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override class var layoutAttributesClass: AnyClass {
        CollapsibleLayoutAttributes.self
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let collectionView else { return false }
        return newBounds.width != collectionView.bounds.width
    }

    override func prepare(forCollectionViewUpdates updateItems: [UICollectionViewUpdateItem]) {
        super.prepare(forCollectionViewUpdates: updateItems)
        collapseController.prepare(updateItems: updateItems)
    }

    override func finalizeCollectionViewUpdates() {
        super.finalizeCollectionViewUpdates()
        collapseController.finalize()
    }

    override func finalLayoutAttributesForDisappearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let base = super.finalLayoutAttributesForDisappearingItem(at: itemIndexPath)
        return collapseController.finalAttributes(for: itemIndexPath, base: base)
    }
}
```

- [ ] **Step 2: Build пока не запускаем — VC ещё использует старый animator**

---

### Task 16: Модифицировать MessageCollectionCell — встроить CellShrinkController

**Files:**
- Modify: `App/CollectionDemo/MessageCollectionCell.swift`

Локальная логика `lockedHeight` уходит в `CellShrinkController`.

- [ ] **Step 1: Заменить содержимое MessageCollectionCell.swift**

```swift
//
//  MessageCollectionCell.swift
//  CollectionDemo
//

import UIKit
import CellExplosionKit

final class MessageCollectionCell: UICollectionViewCell {

    static let reuseIdentifier = "MessageCollectionCell"

    private let shrinkController = CellShrinkController()

    private let bubbleView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16)
        return label
    }()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 11)
        label.textAlignment = .right
        return label
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        contentView.transform = CGAffineTransform(scaleX: 1, y: -1)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

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
        titleLabel.text = nil
        dateLabel.text = nil
        shrinkController.reset()
    }

    private func setupViews() {
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(titleLabel)
        bubbleView.addSubview(dateLabel)

        leadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12)
        trailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12)

        let maxWidthConstraint = bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75)
        maxWidthConstraint.priority = .required

        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            maxWidthConstraint,

            titleLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),

            dateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            dateLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            dateLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            dateLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8),
        ])
    }

    func configure(with message: Message) {
        titleLabel.text = message.title
        dateLabel.text = Self.dateFormatter.string(from: message.date)

        if message.isMy {
            bubbleView.backgroundColor = .systemBlue
            titleLabel.textColor = .white
            dateLabel.textColor = UIColor.white.withAlphaComponent(0.8)
            leadingConstraint.isActive = false
            trailingConstraint.isActive = true
        } else {
            bubbleView.backgroundColor = .systemGray4
            titleLabel.textColor = .label
            dateLabel.textColor = .secondaryLabel
            trailingConstraint.isActive = false
            leadingConstraint.isActive = true
        }
    }

    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let width = (superview as? UICollectionView)?.bounds.width ?? layoutAttributes.frame.width
        let targetSize = CGSize(width: width, height: 0)
        let size = contentView.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let height = ceil(size.height)
        layoutAttributes.frame.size = CGSize(width: width, height: height)
        // Сообщаем shrinkController высоту, чтобы он использовал её при следующем collapse:
        if let collapsible = layoutAttributes as? CollapsibleLayoutAttributes {
            collapsible.lockedHeight = height
        }
        shrinkController.apply(layoutAttributes: layoutAttributes)
        return layoutAttributes
    }
}
```

- [ ] **Step 2: Build пока не запускаем — VC ещё не обновлён**

---

### Task 17: Создать FlippedCellSnapshotProvider в demo (учитывает transform y:-1)

**Files:**
- Create: `App/CollectionDemo/FlippedCellSnapshotProvider.swift`

В demo `MessageCollectionView` имеет `transform = CGAffineTransform(scaleX: 1, y: -1)`, и `contentView` ячейки — тоже. `cell.drawHierarchy(in:afterScreenUpdates:)` отрисует перевёрнутый bitmap. Этот провайдер инвертирует Y в графическом контексте, чтобы snapshot был «правильным» для частиц.

- [ ] **Step 1: Создать FlippedCellSnapshotProvider.swift**

```swift
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
```

- [ ] **Step 2: Добавить файл в Xcode-проект**

В Xcode: `File → Add Files to "CollectionDemo"…` → выбрать `App/CollectionDemo/FlippedCellSnapshotProvider.swift` → `Add`.

---

### Task 18: Модифицировать MessageViewController — собрать связку

**Files:**
- Modify: `App/CollectionDemo/MessageViewController.swift`

- [ ] **Step 1: Заменить содержимое MessageViewController.swift**

```swift
//
//  MessageViewController.swift
//  CollectionDemo
//

import UIKit
import SnapKit
import CellExplosionKit

final class MessageViewController: UIViewController {

    private var dataSource: [Message] = demoMessages

    private lazy var deleteItem = UIBarButtonItem(
        image: UIImage(systemName: "arrow.down.message"),
        style: .plain,
        target: self,
        action: #selector(deleteHandler)
    )

    private lazy var deleteMiddleItem = UIBarButtonItem(
        image: UIImage(systemName: "scissors"),
        style: .plain,
        target: self,
        action: #selector(deleteMiddleHandler)
    )

    private lazy var deleteMultipleItem = UIBarButtonItem(
        image: UIImage(systemName: "rectangle.stack.badge.minus"),
        style: .plain,
        target: self,
        action: #selector(deleteMultipleHandler)
    )

    private let collapseController = CellCollapseLayoutController(configuration: .default)

    private lazy var messageCollectionView: MessageCollectionView = {
        let layout = MessageFlowLayout(collapseController: collapseController)
        let cv = MessageCollectionView(frame: .zero, collectionViewLayout: layout)
        cv.dataSource = self
        return cv
    }()

    private lazy var renderer = SpriteKitParticleRenderer(configuration: .default)

    private lazy var explosionCoordinator = CellExplosionCoordinator(
        collectionView: messageCollectionView,
        container: view,
        renderer: renderer,
        layoutController: collapseController,
        snapshotProvider: FlippedCellSnapshotProvider(),
        configuration: .default
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItems = [deleteItem, deleteMiddleItem, deleteMultipleItem]
        view.addSubview(messageCollectionView)
        messageCollectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        view.addSubview(renderer.view)
        renderer.view.frame = view.bounds
        renderer.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        _ = explosionCoordinator
    }

    @objc private func deleteHandler() {
        guard !dataSource.isEmpty else { return }
        delete(at: [IndexPath(item: 0, section: 0)])
    }

    @objc private func deleteMiddleHandler() {
        guard !dataSource.isEmpty else { return }
        delete(at: [IndexPath(item: dataSource.count / 2, section: 0)])
    }

    @objc private func deleteMultipleHandler() {
        guard dataSource.count >= 3 else { return }
        let indices = [0, dataSource.count / 2, dataSource.count - 1]
        delete(at: indices.map { IndexPath(item: $0, section: 0) })
    }

    private func delete(at indexPaths: [IndexPath]) {
        for path in indexPaths.sorted(by: { $0.item > $1.item }) {
            dataSource.remove(at: path.item)
        }
        messageCollectionView.performBatchUpdates {
            messageCollectionView.deleteItems(at: indexPaths)
        }
    }
}

extension MessageViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        dataSource.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: MessageCollectionCell.reuseIdentifier,
            for: indexPath
        ) as! MessageCollectionCell
        cell.configure(with: dataSource[indexPath.item])
        return cell
    }
}
```

- [ ] **Step 2: Build demo-проекта**

```bash
cd /Users/antonkorolev/Repository/collection-ios-ai
xcodebuild build -project App/CollectionDemo.xcodeproj \
  -scheme CollectionDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Ручной smoke-test в симуляторе**

В Xcode: `Cmd+R` (run on iPhone 17 simulator).

Проверить:
1. Кнопка `arrow.down.message` (удалить первое сообщение): первое сообщение коллапсится плавно (~0.3s), в момент когда оно становится тонким — на его месте взрываются частицы и разлетаются с гравитацией/демпингом/wobble.
2. Кнопка `scissors` (удалить из середины): то же самое для середины.
3. Кнопка `rectangle.stack.badge.minus` (удалить 3 одновременно): три ячейки коллапсятся параллельно, в каждой — взрыв частиц.
4. Эффект визуально совпадает с тем что было до миграции.

Если что-то не так — исправь и повтори Step 2-3.

- [ ] **Step 4: Коммит миграции**

```bash
cd /Users/antonkorolev/Repository/collection-ios-ai
git add -A App/CollectionDemo/
git status   # проверить что в diff только нужные файлы
git commit -m "refactor(CollectionDemo): migrate to CellExplosionKit package

- удалены ExplosionView.swift, CellExplosionAnimator.swift
- MessageFlowLayout: композиция CellCollapseLayoutController
- MessageCollectionCell: композиция CellShrinkController
- MessageViewController: сборка координатора + FlippedCellSnapshotProvider
- удаление через стандартный collectionView.deleteItems"
```

---

## Финальная проверка

- [ ] **Прогнать ВСЕ тесты пакета**

```bash
cd /Users/antonkorolev/Repository/collection-ios-ai/Packages/CellExplosionKit
xcodebuild test -scheme CellExplosionKit \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "(Test Suite|passed|failed)" | tail -20
```

Expected: все тесты passed. Минимум:
- ExplosionConfigurationTests: 2
- ParticlePhysicsTests: 6
- ParticleFactoryTests: 4
- CollapsibleLayoutAttributesTests: 3
- CellCollapseLayoutControllerTests: 5
- CellShrinkControllerTests: 5
- CellExplosionCoordinatorTests: 6
- **Итого: 31 теста**

- [ ] **Финальный ручной smoke-test demo-app**

Запустить в Xcode, проверить все три кнопки удаления.

- [ ] **Проверка git-состояния**

```bash
git log --oneline -20
git status
```

Expected: серия коммитов, по одному на задачу. Working tree clean.

---

## Что НЕ делается в этом плане (документируем явно)

- Insert/move анимация через эффект — out of scope, спека ограничивает delete.
- SwiftUI обёртка — не нужна (UIKit only).
- README.md в пакете — можно добавить отдельной маленькой задачей после merge, не блокирует функциональность.
- Снапшот-тесты реального `performBatchUpdates` — out of scope, проверяется ручным smoke-тестом demo.
