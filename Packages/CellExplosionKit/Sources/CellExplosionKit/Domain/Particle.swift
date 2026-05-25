import CoreGraphics

/// Единичная отображаемая частица эффекта взрыва.
///
/// `Particle` — чистый тип-значение, живущий в Domain-слое и несущий полное
/// физическое состояние, необходимое любому rendering-бэкенду. Каждое поле
/// обновляется каждый кадр в `ParticlePhysics.step(_:dt:configuration:)`;
/// renderer читает результат и отображает его в визуальный узел.
///
/// Частицы создаются пачкой в `ParticleFactory.makeParticles(from:scale:origin:configuration:)`
/// и передаются в `ParticleRenderer.addParticles(_:)`. Потребителям редко
/// нужно создавать `Particle` напрямую — разве что при написании custom
/// renderer или factory.
public struct Particle {
    /// Горизонтальная позиция в координатном пространстве renderer, в точках.
    public var x: CGFloat
    /// Вертикальная позиция в координатном пространстве renderer, в точках.
    public var y: CGFloat
    /// Горизонтальная скорость, в точках в секунду.
    public var vx: CGFloat
    /// Вертикальная скорость, в точках в секунду.
    public var vy: CGFloat
    /// Базовый цвет частицы, взятый из snapshot ячейки.
    public var color: CGColor
    /// Ширина и высота квадратного спрайта частицы, в точках.
    public var size: CGFloat
    /// Текущий угол вращения, в радианах.
    public var rotation: CGFloat
    /// Угловая скорость, в радианах в секунду.
    public var vRotation: CGFloat
    /// Текущая прозрачность в диапазоне `[0, 1]`. Достигает 0, когда частицу следует удалить.
    public var alpha: CGFloat
    /// Скорость уменьшения `alpha` в секунду. Вычисляется из случайного времени жизни частицы.
    public var alphaDecay: CGFloat
    /// Суммарное прошедшее время с момента появления частицы, в секундах. Используется для wobble.
    public var age: CGFloat
    /// Амплитуда wobble по оси X, в точках.
    public var wAmpX: CGFloat
    /// Амплитуда wobble по оси Y, в точках.
    public var wAmpY: CGFloat
    /// Частота wobble по оси X, в Гц.
    public var wFreqX: CGFloat
    /// Частота wobble по оси Y, в Гц.
    public var wFreqY: CGFloat
    /// Начальное смещение фазы осциллятора wobble по оси X, в радианах.
    public var wPhaseX: CGFloat
    /// Начальное смещение фазы осциллятора wobble по оси Y, в радианах.
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
