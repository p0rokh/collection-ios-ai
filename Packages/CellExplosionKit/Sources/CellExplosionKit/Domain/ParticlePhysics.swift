import Foundation
import CoreGraphics

/// Чистый физический интегратор для одного шага `Particle`.
///
/// `ParticlePhysics` — внутренняя утилита Domain-слоя; она не является частью
/// публичного API. Rendering-бэкенд вызывает `step(_:dt:configuration:)` один
/// раз за кадр дисплея для каждой живой частицы. Изоляция физики в Domain-слое
/// позволяет альтернативному renderer (например, на Metal) использовать ту же
/// модель движения без изменений в Rendering-слое.
enum ParticlePhysics {

    /// Продвигает `particle` на один временной шаг.
    ///
    /// Интегратор применяет синусоидальные силы wobble, гравитацию, затухание
    /// скорости, интегрирование позиции, вращение и затухание alpha — в таком порядке.
    ///
    /// - Parameters:
    ///   - particle: Частица, изменяемая на месте.
    ///   - dt: Прошедшее время с последнего кадра, в секундах. Должно быть ограничено
    ///     вызывающим кодом, чтобы избежать больших скачков после фонового режима.
    ///   - configuration: Физические константы (`gravity`, `damping` и др.),
    ///     взятые из активной `ExplosionConfiguration`.
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
