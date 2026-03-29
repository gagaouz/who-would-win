import SpriteKit

class PixelExplosion {
    /// Creates an SKEmitterNode configured entirely in code (no .sks file).
    /// - Particles are small squares (4x4 pt) represented as rectangles
    /// - Colors: bright yellow, orange, red
    /// - Burst outward in all directions
    /// - Lifetime: 0.8 seconds
    /// - 40-60 particles
    static func makeEmitter() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 80
        emitter.numParticlesToEmit = 50
        emitter.particleLifetime = 0.8
        emitter.particleLifetimeRange = 0.3
        emitter.particleSpeed = 200
        emitter.particleSpeedRange = 150
        emitter.emissionAngle = 0
        emitter.emissionAngleRange = .pi * 2
        emitter.particleAlpha = 1.0
        emitter.particleAlphaRange = 0.0
        emitter.particleAlphaSpeed = -1.5
        emitter.particleScale = 0.08
        emitter.particleScaleRange = 0.04
        emitter.particleColor = .yellow
        emitter.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [UIColor.yellow, UIColor.orange, UIColor.red],
            times: [0, 0.4, 0.8]
        )
        // Use a small square texture
        let size = CGSize(width: 8, height: 8)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        emitter.particleTexture = SKTexture(image: img)
        return emitter
    }
}
