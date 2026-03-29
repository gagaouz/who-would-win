import SpriteKit
import UIKit

/// Renders an animal as a large emoji sprite with idle bob + battle animations.
class AnimalSprite: SKNode {

    let animal: Animal
    private var spriteNode: SKSpriteNode!
    private var shadowNode: SKSpriteNode!

    // Size in SpriteKit points for the emoji sprite
    private var spriteSize: CGFloat {
        switch animal.size {
        case 5:  return 110
        case 4:  return 95
        case 3:  return 80
        case 2:  return 68
        default: return 58
        }
    }

    init(animal: Animal) {
        self.animal = animal
        super.init()
        setupSprite()
        startIdleAnimation()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupSprite() {
        // Ground shadow (ellipse under feet)
        let shadowSize = CGSize(width: spriteSize * 0.75, height: spriteSize * 0.18)
        let shadowTex  = Self.ovalTexture(size: shadowSize, color: UIColor.black.withAlphaComponent(0.35))
        shadowNode = SKSpriteNode(texture: shadowTex, size: shadowSize)
        shadowNode.position = CGPoint(x: 0, y: -(spriteSize * 0.44))
        addChild(shadowNode)

        // Emoji sprite
        let tex = Self.emojiTexture(animal.emoji, points: spriteSize)
        spriteNode = SKSpriteNode(texture: tex,
                                  size: CGSize(width: spriteSize, height: spriteSize))
        addChild(spriteNode)
    }

    // MARK: - Emoji → SKTexture

    /// Renders an emoji string into an SKTexture at the given logical size (2× for retina).
    static func emojiTexture(_ emoji: String, points: CGFloat) -> SKTexture {
        let scale: CGFloat = 3           // render 3× for crisp retina/ProMotion
        let px = points * scale
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: px, height: px))
        let img = renderer.image { _ in
            let fontSize = px * 0.82
            let attr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: fontSize)]
            let s  = emoji as NSString
            let sz = s.size(withAttributes: attr)
            s.draw(at: CGPoint(x: (px - sz.width) / 2,
                               y: (px - sz.height) / 2),
                   withAttributes: attr)
        }
        let tex = SKTexture(image: img)
        tex.filteringMode = .linear
        return tex
    }

    /// Creates a soft oval texture for the ground shadow.
    static func ovalTexture(size: CGSize, color: UIColor) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            color.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: img)
    }

    // MARK: - Idle Animation (gentle bob)

    func startIdleAnimation() {
        let bobUp   = SKAction.moveBy(x: 0, y: 4,  duration: 0.9)
        let bobDown = SKAction.moveBy(x: 0, y: -4, duration: 0.9)
        bobUp.timingMode   = .easeInEaseOut
        bobDown.timingMode = .easeInEaseOut
        let bob = SKAction.sequence([bobUp, bobDown])
        spriteNode.run(SKAction.repeatForever(bob))

        // Shadow pulses opposite
        let shrink = SKAction.scaleX(to: 0.85, duration: 0.9)
        let grow   = SKAction.scaleX(to: 1.00, duration: 0.9)
        shrink.timingMode = .easeInEaseOut
        grow.timingMode   = .easeInEaseOut
        shadowNode.run(SKAction.repeatForever(SKAction.sequence([shrink, grow])))
    }

    // MARK: - Battle Animations

    var onAnimationComplete: (() -> Void)?

    func playClash(completion: @escaping () -> Void) {
        // Quick shake left-right then settle
        let shake = SKAction.sequence([
            SKAction.moveBy(x:  10, y: 0, duration: 0.07),
            SKAction.moveBy(x: -20, y: 0, duration: 0.07),
            SKAction.moveBy(x:  20, y: 0, duration: 0.07),
            SKAction.moveBy(x: -10, y: 0, duration: 0.07),
        ])
        let scale  = SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.1),
            SKAction.scale(to: 1.00, duration: 0.15),
        ])
        spriteNode.run(SKAction.group([shake, scale])) { completion() }
    }

    func playVictory() {
        spriteNode.removeAllActions()
        shadowNode.removeAllActions()
        let jump  = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 22, duration: 0.22),
            SKAction.moveBy(x: 0, y: -22, duration: 0.18),
        ])
        jump.timingMode = .easeInEaseOut
        let scale = SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.2),
            SKAction.scale(to: 1.0, duration: 0.2),
        ])
        spriteNode.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.group([jump, scale]),
            SKAction.wait(forDuration: 0.4),
        ])))
    }

    func playDefeat() {
        spriteNode.removeAllActions()
        shadowNode.removeAllActions()
        // Tip over and fade slightly
        let tip  = SKAction.rotate(toAngle: -.pi / 2, duration: 0.4)
        let fade = SKAction.fadeAlpha(to: 0.45, duration: 0.4)
        tip.timingMode  = .easeIn
        fade.timingMode = .easeIn
        spriteNode.run(SKAction.group([tip, fade]))
        shadowNode.run(SKAction.fadeAlpha(to: 0.15, duration: 0.4))
    }

    // MARK: - Texture override

    /// Call this to override the emoji with a real image (e.g. AI-generated)
    func updateTexture(with image: UIImage) {
        let tex = SKTexture(image: image)
        tex.filteringMode = .linear
        spriteNode.texture = tex
    }

    // MARK: - Battle result

    func setBattleResult(_ result: BattleResult, isWinner: Bool) {
        if isWinner { playVictory() } else { playDefeat() }
    }
}
