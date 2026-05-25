import UIKit
import SpriteKit

/// Реализация `ParticleRenderer` по умолчанию, основанная на полноэкранном `SKView`.
///
/// `SpriteKitParticleRenderer` живёт в Rendering-слое и зависит только от
/// Domain-типов (`Particle`, `ExplosionConfiguration`). Он оборачивает `SKView`,
/// которому принадлежит `SpriteKitParticleScene`; та запускает игровой цикл
/// SpriteKit и вызывает `ParticlePhysics.step` каждый кадр.
///
/// **Настройка:** Добавьте `renderer.view` в иерархию видов как дочерний элемент
/// рядом с collection view, растянутый на весь контейнер:
/// ```swift
/// let renderer = SpriteKitParticleRenderer(configuration: .default)
/// renderer.view.frame = view.bounds
/// view.addSubview(renderer.view)
/// ```
/// Координатор автоматически вызывает `bringSubviewToFront` перед каждым взрывом,
/// поэтому порядок добавления не важен.
public final class SpriteKitParticleRenderer: ParticleRenderer {

    private let skView: SKView
    private let scene: SpriteKitParticleScene

    /// Прозрачный `SKView`, отображающий симуляцию частиц.
    ///
    /// Добавьте его в контейнерный вид и растяните на весь экран. Вид
    /// неинтерактивен (`isUserInteractionEnabled = false`) и не перехватывает
    /// касания collection view под ним.
    public var view: UIView { skView }

    /// Создаёт renderer с заданными параметрами взрыва.
    ///
    /// - Parameter configuration: Управляет физическими константами игрового
    ///   цикла SpriteKit. Передайте `.default`, чтобы соответствовать настройкам
    ///   референсного демо.
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

    /// Передаёт `particles` в нижележащий `SpriteKitParticleScene`.
    ///
    /// Размер сцены обновляется из текущих bounds `SKView` перед добавлением узлов,
    /// чтобы преобразование координат UIKit → SpriteKit по оси Y всегда основывалось
    /// на актуальной высоте рендеринга.
    public func addParticles(_ particles: [Particle]) {
        // Синхронизируем размер сцены с текущими bounds SKView перед добавлением
        // узлов, чтобы переворот по оси Y (UIKit Y-down → SpriteKit Y-up)
        // использовал корректную высоту.
        scene.size = skView.bounds.size
        scene.addParticles(particles)
    }
}
