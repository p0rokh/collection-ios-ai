import UIKit

public protocol ParticleRenderer: AnyObject {
    var view: UIView { get }
    func addParticles(_ particles: [Particle])
}
