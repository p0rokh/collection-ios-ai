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
