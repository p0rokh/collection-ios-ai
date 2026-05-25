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
