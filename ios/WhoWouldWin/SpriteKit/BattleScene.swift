import SpriteKit

class BattleScene: SKScene {
    let fighter1Animal: Animal
    let fighter2Animal: Animal
    var onAnimationComplete: (() -> Void)?

    private var sprite1: AnimalSprite!
    private var sprite2: AnimalSprite!
    private var healthFill1: SKShapeNode!
    private var healthFill2: SKShapeNode!
    private var healthBarFullWidth: CGFloat = 0
    private var battleResult: BattleResult?

    /// Prevents didMove(to:) from re-running full setup when SpriteView
    /// is removed/re-added during a phase transition (which would overwrite
    /// healthFill1/healthFill2 mid-animation).
    private var isSetUp = false

    /// Images pre-fetched before the SpriteView appears (during the 2-second intro).
    /// Applied immediately in setupSprites() if available.
    private var preloadedImage1: UIImage?
    private var preloadedImage2: UIImage?

    // MARK: - Init

    init(fighter1: Animal, fighter2: Animal, size: CGSize) {
        self.fighter1Animal = fighter1
        self.fighter2Animal = fighter2
        super.init(size: size)
        self.scaleMode = .aspectFill
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    // MARK: - Scene Setup

    override func didMove(to view: SKView) {
        // Guard against re-running setup when SpriteView is removed/re-added
        // during a SwiftUI phase transition (animating → revealing).
        guard !isSetUp else { return }
        isSetUp = true

        setupBackground()
        setupStars()
        setupGround()
        setupHealthBars()
        setupSprites()

        // Automatically start clash animation after a short delay
        let wait = SKAction.wait(forDuration: 0.5)
        let start = SKAction.run { [weak self] in
            self?.startClashAnimation()
        }
        run(SKAction.sequence([wait, start]))
    }

    // MARK: - Background

    private func setupBackground() {
        // Dark gradient arena: #0A0A1A to #1A0A2E
        // SKScene doesn't support gradients natively, so we use an SKSpriteNode with a gradient texture
        backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.16, alpha: 1) // #0A0A28 base

        let gradientNode = makeGradientNode(
            topColor: UIColor(red: 0.102, green: 0.039, blue: 0.18, alpha: 1),   // #1A0A2E
            bottomColor: UIColor(red: 0.039, green: 0.039, blue: 0.102, alpha: 1), // #0A0A1A
            size: size
        )
        gradientNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        gradientNode.zPosition = -10
        addChild(gradientNode)
    }

    private func makeGradientNode(topColor: UIColor, bottomColor: UIColor, size: CGSize) -> SKSpriteNode {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [topColor.cgColor, bottomColor.cgColor] as CFArray,
                locations: [0.0, 1.0]
            )!
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 0, y: size.height),
                options: []
            )
        }
        return SKSpriteNode(texture: SKTexture(image: img), size: size)
    }

    // MARK: - Stars

    private func setupStars() {
        for _ in 0..<30 {
            let radius = CGFloat.random(in: 0.8...2.0)
            let star = SKShapeNode(circleOfRadius: radius)
            star.fillColor = .white
            star.strokeColor = .clear
            star.alpha = CGFloat.random(in: 0.2...0.8)
            star.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: size.height * 0.3...size.height)
            )
            star.zPosition = -5
            addChild(star)

            // Twinkle: random fade in/out loop
            let fadeDuration = Double.random(in: 0.8...2.5)
            let fadeDelay = Double.random(in: 0...2.0)
            let minAlpha = CGFloat.random(in: 0.05...0.25)
            let maxAlpha = CGFloat.random(in: 0.6...1.0)

            let fadeOut = SKAction.fadeAlpha(to: minAlpha, duration: fadeDuration)
            let fadeIn = SKAction.fadeAlpha(to: maxAlpha, duration: fadeDuration)
            let twinkle = SKAction.repeatForever(
                SKAction.sequence([
                    SKAction.wait(forDuration: fadeDelay),
                    fadeOut,
                    fadeIn
                ])
            )
            star.run(twinkle)
        }
    }

    // MARK: - Ground Platform

    private func setupGround() {
        let groundY = size.height * 0.25

        // Main ground line
        let groundPath = CGMutablePath()
        groundPath.move(to: CGPoint(x: 0, y: groundY))
        groundPath.addLine(to: CGPoint(x: size.width, y: groundY))

        let ground = SKShapeNode(path: groundPath)
        ground.strokeColor = UIColor(red: 0.4, green: 0.2, blue: 0.9, alpha: 0.9)  // Neon purple
        ground.lineWidth = 2
        ground.zPosition = -2
        addChild(ground)

        // Glow layer (wider, more transparent line behind)
        let glowPath = CGMutablePath()
        glowPath.move(to: CGPoint(x: 0, y: groundY))
        glowPath.addLine(to: CGPoint(x: size.width, y: groundY))

        let glow = SKShapeNode(path: glowPath)
        glow.strokeColor = UIColor(red: 0.5, green: 0.3, blue: 1.0, alpha: 0.25)
        glow.lineWidth = 8
        glow.zPosition = -3
        addChild(glow)
    }

    // MARK: - Health Bars

    private func setupHealthBars() {
        let barWidth: CGFloat = size.width * 0.37
        let barHeight: CGFloat = 14
        let barY = size.height * 0.88
        let cornerRadius: CGFloat = 7
        let fillWidth = barWidth - 4
        let fillHeight = barHeight - 4
        let fillCorner = cornerRadius - 2

        // Store for use in animation
        healthBarFullWidth = fillWidth

        // Helper: left-aligned fill path at full width
        func fullFillPath() -> CGPath {
            UIBezierPath(
                roundedRect: CGRect(x: -fillWidth / 2, y: -fillHeight / 2, width: fillWidth, height: fillHeight),
                cornerRadius: fillCorner
            ).cgPath
        }

        // --- Fighter 1 (left) ---
        let bg1 = SKShapeNode(
            path: UIBezierPath(roundedRect: CGRect(x: -barWidth / 2, y: -barHeight / 2, width: barWidth, height: barHeight), cornerRadius: cornerRadius).cgPath
        )
        bg1.fillColor = UIColor(white: 0.1, alpha: 0.9)
        bg1.strokeColor = UIColor(white: 0.3, alpha: 0.5)
        bg1.lineWidth = 1
        bg1.position = CGPoint(x: size.width * 0.24, y: barY)
        bg1.zPosition = 5
        addChild(bg1)

        healthFill1 = SKShapeNode(path: fullFillPath())
        healthFill1.fillColor = UIColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 1)
        healthFill1.strokeColor = .clear
        healthFill1.position = CGPoint(x: size.width * 0.24, y: barY)
        healthFill1.zPosition = 6
        addChild(healthFill1)

        let name1 = SKLabelNode(text: fighter1Animal.name.uppercased())
        name1.fontName = "AvenirNext-Bold"
        name1.fontSize = 9
        name1.fontColor = .white
        name1.horizontalAlignmentMode = .center
        name1.position = CGPoint(x: size.width * 0.24, y: barY + barHeight / 2 + 4)
        name1.zPosition = 7
        addChild(name1)

        // --- Fighter 2 (right) ---
        let bg2 = SKShapeNode(
            path: UIBezierPath(roundedRect: CGRect(x: -barWidth / 2, y: -barHeight / 2, width: barWidth, height: barHeight), cornerRadius: cornerRadius).cgPath
        )
        bg2.fillColor = UIColor(white: 0.1, alpha: 0.9)
        bg2.strokeColor = UIColor(white: 0.3, alpha: 0.5)
        bg2.lineWidth = 1
        bg2.position = CGPoint(x: size.width * 0.76, y: barY)
        bg2.zPosition = 5
        addChild(bg2)

        healthFill2 = SKShapeNode(path: fullFillPath())
        healthFill2.fillColor = UIColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 1)
        healthFill2.strokeColor = .clear
        healthFill2.position = CGPoint(x: size.width * 0.76, y: barY)
        healthFill2.zPosition = 6
        addChild(healthFill2)

        let name2 = SKLabelNode(text: fighter2Animal.name.uppercased())
        name2.fontName = "AvenirNext-Bold"
        name2.fontSize = 9
        name2.fontColor = .white
        name2.horizontalAlignmentMode = .center
        name2.position = CGPoint(x: size.width * 0.76, y: barY + barHeight / 2 + 4)
        name2.zPosition = 7
        addChild(name2)
    }

    // MARK: - Sprites

    private func setupSprites() {
        sprite1 = AnimalSprite(animal: fighter1Animal)
        sprite1.position = CGPoint(x: size.width * 0.2, y: size.height * 0.45)
        sprite1.zPosition = 2
        addChild(sprite1)

        sprite2 = AnimalSprite(animal: fighter2Animal)
        sprite2.xScale = -sprite2.xScale  // Mirror to face left
        sprite2.position = CGPoint(x: size.width * 0.8, y: size.height * 0.45)
        sprite2.zPosition = 2
        addChild(sprite2)

        // Apply any images that were pre-fetched during the intro phase
        if let img = preloadedImage1 { sprite1.updateTexture(with: img) }
        if let img = preloadedImage2 { sprite2.updateTexture(with: img) }
    }

    // MARK: - Clash Animation (auto-runs, fires onAnimationComplete)

    func startClashAnimation() {
        let centerX = size.width / 2

        // Step 1: 0.3s drama pause (already handled by 0.5s scene delay, but keep as wait)
        let initialWait = SKAction.wait(forDuration: 0.3)

        // Step 2: Both sprites charge toward center
        let charge1 = SKAction.moveTo(x: centerX - 40, duration: 0.7)
        charge1.timingMode = .easeIn
        let charge2 = SKAction.moveTo(x: centerX + 40, duration: 0.7)
        charge2.timingMode = .easeIn

        // Step 3: Camera shake on the scene itself
        let shakeSequence = SKAction.sequence([
            SKAction.moveBy(x: 12, y: 0, duration: 0.04),
            SKAction.moveBy(x: -24, y: 0, duration: 0.04),
            SKAction.moveBy(x: 20, y: 0, duration: 0.04),
            SKAction.moveBy(x: -20, y: 0, duration: 0.04),
            SKAction.moveBy(x: 14, y: 0, duration: 0.04),
            SKAction.moveBy(x: -14, y: 3, duration: 0.04),
            SKAction.moveBy(x: 10, y: -6, duration: 0.04),
            SKAction.moveBy(x: -10, y: 3, duration: 0.04),
            SKAction.moveBy(x: 0, y: 0, duration: 0.04)  // return to origin (net zero)
        ])

        // Step 4 & 5: Explosion + white flash
        let spawnExplosionAndFlash = SKAction.run { [weak self] in
            guard let self = self else { return }

            // Explosion
            let explosion = PixelExplosion.makeEmitter()
            explosion.position = CGPoint(x: self.size.width / 2, y: self.size.height * 0.45)
            explosion.zPosition = 10
            self.addChild(explosion)
            explosion.run(SKAction.sequence([
                SKAction.wait(forDuration: 1.2),
                SKAction.removeFromParent()
            ]))

            // White flash overlay
            let flash = SKSpriteNode(color: .white, size: self.size)
            flash.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2)
            flash.zPosition = 20
            flash.alpha = 0
            self.addChild(flash)
            flash.run(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.85, duration: 0.06),
                SKAction.fadeAlpha(to: 0.0, duration: 0.18),
                SKAction.removeFromParent()
            ]))
        }

        // Step 6: Sprites push back out
        let pushBack1 = SKAction.moveBy(x: -80, y: 0, duration: 0.4)
        pushBack1.timingMode = .easeOut
        let pushBack2 = SKAction.moveBy(x: 80, y: 0, duration: 0.4)
        pushBack2.timingMode = .easeOut

        // Step 7: Final wait before callback
        let finalWait = SKAction.wait(forDuration: 0.5)

        // Compose the full sequence on `self` (the scene node)
        let clashSequence = SKAction.sequence([
            initialWait,
            SKAction.group([
                SKAction.run { [weak self] in
                    self?.sprite1.run(charge1)
                    self?.sprite2.run(charge2)
                },
                SKAction.wait(forDuration: 0.7)  // wait for charge to complete
            ]),
            SKAction.group([shakeSequence, spawnExplosionAndFlash]),
            SKAction.run { [weak self] in
                self?.sprite1.run(pushBack1)
                self?.sprite2.run(pushBack2)
            },
            SKAction.wait(forDuration: 0.4),  // wait for push-back
            finalWait,
            SKAction.run { [weak self] in
                self?.onAnimationComplete?()
            }
        ])

        run(clashSequence, withKey: "clashAnimation")
    }

    // MARK: - Custom Image Override

    /// Replaces a fighter's emoji texture with a real downloaded UIImage.
    /// Safe to call before the SpriteView appears — the image is stored and
    /// applied in setupSprites() if the sprites aren't created yet.
    func setFighterImage(_ image: UIImage, forFighter slot: Int) {
        switch slot {
        case 1:
            preloadedImage1 = image
            sprite1?.updateTexture(with: image)
        case 2:
            preloadedImage2 = image
            sprite2?.updateTexture(with: image)
        default: break
        }
    }

    // MARK: - Rematch Reset

    func reset() {
        preloadedImage1 = nil
        preloadedImage2 = nil
        removeAllChildren()
        removeAllActions()
        battleResult = nil
        setupBackground()
        setupStars()
        setupGround()
        setupHealthBars()
        setupSprites()
        // Mark as set up so didMove won't run the setup a second time
        // if SpriteView triggers a re-presentation after reset.
        isSetUp = true
        let wait = SKAction.wait(forDuration: 0.5)
        let start = SKAction.run { [weak self] in
            self?.startClashAnimation()
        }
        run(SKAction.sequence([wait, start]))
    }

    // MARK: - Battle Result (victory/defeat poses + HP drain)

    func setBattleResult(_ result: BattleResult) {
        self.battleResult = result

        let fighter1Wins = result.winner == fighter1Animal.id
        let isDraw = result.winner == "draw"

        // Drain health bars
        drainHealthBars(result: result, fighter1Wins: fighter1Wins, isDraw: isDraw)

        // Victory / defeat poses
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            if isDraw {
                self.sprite1.playVictory()
                self.sprite2.playVictory()
            } else if fighter1Wins {
                self.sprite1.playVictory()
                self.sprite2.playDefeat()
            } else {
                self.sprite2.playVictory()
                self.sprite1.playDefeat()
            }

            // Fade sprites out so they don't ghost through the results panel
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.fadeOutSprites()
            }
        }
    }

    private func fadeOutSprites() {
        let fade = SKAction.fadeOut(withDuration: 0.6)
        sprite1?.run(fade)
        sprite2?.run(fade)
    }

    private func drainHealthBars(result: BattleResult, fighter1Wins: Bool, isDraw: Bool) {
        let fullWidth = healthBarFullWidth
        let winnerPct = isDraw ? 0.55 : CGFloat(result.winnerHealthPercent) / 100.0
        let loserPct  = isDraw ? 0.45 : CGFloat(result.loserHealthPercent)  / 100.0

        let winnerFill = fighter1Wins || isDraw ? healthFill1! : healthFill2!
        let loserFill  = fighter1Wins || isDraw ? healthFill2! : healthFill1!

        animateHealthBar(winnerFill, toPercent: winnerPct, fullWidth: fullWidth, duration: 1.0, isLoser: false)
        animateHealthBar(loserFill,  toPercent: loserPct,  fullWidth: fullWidth, duration: 1.4, isLoser: true)
    }

    private func animateHealthBar(_ fillNode: SKShapeNode, toPercent: CGFloat,
                                   fullWidth: CGFloat, duration: TimeInterval, isLoser: Bool) {
        let targetWidth = max(2, fullWidth * toPercent)
        let startWidth = fullWidth  // always starts full
        let fillHeight: CGFloat = 10
        let cornerRadius: CGFloat = 5

        let action = SKAction.customAction(withDuration: duration) { node, elapsed in
            guard let shape = node as? SKShapeNode else { return }
            let progress = min(1.0, CGFloat(elapsed) / CGFloat(duration))
            let currentWidth = startWidth + (targetWidth - startWidth) * progress

            // Rebuild the path left-aligned
            let rect = CGRect(x: -fullWidth / 2, y: -fillHeight / 2, width: currentWidth, height: fillHeight)
            shape.path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).cgPath

            // Color transition for loser: green → yellow → red
            if isLoser {
                if progress < 0.5 {
                    let t = progress * 2
                    shape.fillColor = UIColor(
                        red: CGFloat(t),
                        green: 1.0 - CGFloat(t) * 0.5,
                        blue: 0,
                        alpha: 1
                    )
                } else {
                    let t = (progress - 0.5) * 2
                    shape.fillColor = UIColor(
                        red: 1.0,
                        green: CGFloat(0.5 - t * 0.5),
                        blue: 0,
                        alpha: 1
                    )
                }
            }
        }
        fillNode.run(action)
    }
}
