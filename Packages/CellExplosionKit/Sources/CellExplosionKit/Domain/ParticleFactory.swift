import Foundation
import CoreGraphics

/// Преобразует растеризованный snapshot ячейки в массив значений `Particle`.
///
/// `ParticleFactory` — внутренняя утилита Domain-слоя; она не является частью
/// публичного API. `CellExplosionCoordinator` вызывает
/// `makeParticles(from:scale:origin:configuration:)` один раз за взрыв,
/// передавая обрезанный нижний срез snapshot-изображения ячейки.
/// Factory разбивает изображение на непересекающиеся квадраты `chunkSize × chunkSize`
/// и порождает одну частицу на каждый непрозрачный блок.
enum ParticleFactory {

    /// Создаёт частицу для каждого непрозрачного блока в `cgImage`.
    ///
    /// Изображение растеризуется в CPU-доступный пиксельный буфер один раз за вызов.
    /// Каждый блок `chunkSize × chunkSize` представлен цветом центрального пикселя,
    /// а не средним значением — центральная выборка быстра, избегает проблем смешения
    /// на антиалиасированных краях и визуально неотличима при типичных размерах блоков,
    /// используемых в этом пакете.
    ///
    /// - Parameters:
    ///   - cgImage: Исходное изображение, как правило — нижний обрез snapshot ячейки.
    ///   - scale: Масштабный коэффициент экрана для перевода между пиксельными и точечными координатами.
    ///   - origin: Верхний левый угол изображения в координатном пространстве контейнера, в точках.
    ///   - configuration: Предоставляет `chunkSize`, `speed`, `upBias`, `wobbleAmplitude`,
    ///     `wobbleFrequency` и `lifetimeRange` для создаваемых частиц.
    /// - Returns: По одной `Particle` на каждый непрозрачный блок. Прозрачные блоки
    ///   (alpha ≤ 30/255) пропускаются, чтобы не порождать невидимые частицы-призраки
    ///   на краях изображения.
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
                // Берём центральный пиксель каждого блока вместо усреднения всех
                // пикселей в тайле. Это быстро и визуально эквивалентно при малых
                // размерах блоков, используемых в этом пакете.
                let cx = min(px + chunkPixels / 2, width - 1)
                let cy = min(py + chunkPixels / 2, height - 1)
                let i = (cy * width + cx) * 4
                let a = pixelData[i + 3]
                // Пропускаем почти прозрачные пиксели (alpha ≤ 30/255), чтобы не
                // порождать невидимые частицы-призраки вдоль антиалиасированных краёв.
                if a > 30 {
                    let jitter: CGFloat = 0.08
                    let r = max(0, min(1, CGFloat(pixelData[i]) / 255 + CGFloat.random(in: -jitter...jitter)))
                    let g = max(0, min(1, CGFloat(pixelData[i + 1]) / 255 + CGFloat.random(in: -jitter...jitter)))
                    let b = max(0, min(1, CGFloat(pixelData[i + 2]) / 255 + CGFloat.random(in: -jitter...jitter)))
                    let alpha = CGFloat(a) / 255
                    let color = CGColor(srgbRed: r, green: g, blue: b, alpha: alpha)
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
