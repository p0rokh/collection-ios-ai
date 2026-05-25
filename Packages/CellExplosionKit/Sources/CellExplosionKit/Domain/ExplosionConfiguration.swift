import Foundation
import CoreGraphics

/// Настраиваемые параметры, управляющие анимациями взрыва частиц и коллапса высоты.
///
/// `ExplosionConfiguration` живёт в Domain-слое и используется всеми остальными
/// слоями: `ParticleFactory` применяет её при создании частиц, `ParticlePhysics`
/// использует каждый кадр для их эволюции, `CellCollapseLayoutController`
/// использует `collapseDuration`, а `CellExplosionCoordinator` — `burstThreshold`.
///
/// Начните с `.default`, воспроизводящего настройки референсного демо, и при
/// необходимости корректируйте отдельные поля. Изменения применяются к следующему
/// пакету взрывов; анимации в процессе всегда завершаются с той конфигурацией,
/// которая была активна в момент их запуска.
public struct ExplosionConfiguration {
    /// Длина стороны квадрата каждой частицы, в логических точках. Меньшие значения
    /// дают более мелкие взрывы, но увеличивают количество частиц.
    public var chunkSize: CGFloat
    /// Базовая скорость запуска частиц, в точках в секунду.
    public var speed: CGFloat
    /// Ускорение, применяемое к вертикальной скорости каждую секунду, в точках в секунду².
    /// Отрицательные значения тянут частицы вверх (Y-down конвенция UIKit).
    public var gravity: CGFloat
    /// Множитель скорости за кадр в диапазоне `(0, 1)`. Значения близкие к 1 позволяют
    /// частицам лететь дальше перед остановкой; низкие значения быстро гасят импульс.
    public var damping: CGFloat
    /// Дополнительное смещение вверх, добавляемое к начальной вертикальной скорости каждой
    /// частицы, в точках в секунду. Создаёт характерный «выстрел» вверх при взрыве.
    public var upBias: CGFloat
    /// Максимальное смещение wobble по каждой оси, в точках.
    public var wobbleAmplitude: CGFloat
    /// Базовая частота осцилляции wobble, в Гц. Для каждой частицы она случайно
    /// варьируется в диапазоне ±50 %, чтобы избежать эффекта однородной волны.
    public var wobbleFrequency: CGFloat
    /// Диапазон случайного времени жизни частицы, в секундах. Меньшие значения
    /// ускоряют рассеивание взрыва; `alphaDecay` вычисляется из выбранного значения.
    public var lifetimeRange: ClosedRange<CGFloat>
    /// Продолжительность анимации коллапса высоты ячейки, в секундах.
    public var collapseDuration: TimeInterval
    /// Остаточная видимая высота сворачивающейся ячейки в точках, при достижении которой
    /// запускается взрыв частиц. Меньшие значения задерживают взрыв до почти полного
    /// исчезновения ячейки; большие значения запускают его раньше, когда ячейка ещё хорошо видна.
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

    /// Референсная конфигурация, используемая в демо-проекте CellExplosionKit.
    ///
    /// Используйте её как базу и настраивайте отдельные свойства под визуальный
    /// стиль вашего приложения.
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
