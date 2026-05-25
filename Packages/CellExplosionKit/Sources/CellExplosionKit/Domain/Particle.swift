import CoreGraphics

/// A single renderable particle in the explosion effect.
///
/// `Particle` is a pure value type that lives in the Domain layer and carries the
/// complete physical state needed by any rendering backend. Each field is updated
/// every frame by `ParticlePhysics.step(_:dt:configuration:)`; the renderer reads
/// the result and maps it to a visual node.
///
/// Particles are created in bulk by `ParticleFactory.makeParticles(from:scale:origin:configuration:)`
/// and passed to `ParticleRenderer.addParticles(_:)`. Consumers rarely need to
/// construct `Particle` directly unless writing a custom renderer or factory.
public struct Particle {
    /// Horizontal position in the renderer's coordinate space, in points.
    public var x: CGFloat
    /// Vertical position in the renderer's coordinate space, in points.
    public var y: CGFloat
    /// Horizontal velocity, in points per second.
    public var vx: CGFloat
    /// Vertical velocity, in points per second.
    public var vy: CGFloat
    /// The particle's base color, sampled from the cell snapshot.
    public var color: CGColor
    /// Width and height of the square particle sprite, in points.
    public var size: CGFloat
    /// Current rotation angle, in radians.
    public var rotation: CGFloat
    /// Rotational velocity, in radians per second.
    public var vRotation: CGFloat
    /// Current opacity in the range `[0, 1]`. Reaches 0 when the particle should be removed.
    public var alpha: CGFloat
    /// Rate at which `alpha` decreases per second. Derived from the particle's random lifetime.
    public var alphaDecay: CGFloat
    /// Total elapsed time since the particle was spawned, in seconds. Used to drive wobble.
    public var age: CGFloat
    /// Wobble amplitude along the X axis, in points.
    public var wAmpX: CGFloat
    /// Wobble amplitude along the Y axis, in points.
    public var wAmpY: CGFloat
    /// Wobble frequency along the X axis, in Hz.
    public var wFreqX: CGFloat
    /// Wobble frequency along the Y axis, in Hz.
    public var wFreqY: CGFloat
    /// Initial phase offset for the X-axis wobble oscillator, in radians.
    public var wPhaseX: CGFloat
    /// Initial phase offset for the Y-axis wobble oscillator, in radians.
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
