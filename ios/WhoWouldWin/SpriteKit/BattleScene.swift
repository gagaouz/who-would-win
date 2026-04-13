import SpriteKit

class BattleScene: SKScene {
    let fighter1Animal: Animal
    let fighter2Animal: Animal
    var onAnimationComplete: (() -> Void)?

    private var sprite1: AnimalSprite!
    private var sprite2: AnimalSprite!

    // Health bar fill nodes
    private var healthFill1: SKShapeNode!
    private var healthFill2: SKShapeNode!
    private var healthBarFullWidth: CGFloat = 0

    // HP state — randomised per battle
    private var maxHP1: CGFloat = 80
    private var maxHP2: CGFloat = 80
    private var currentHP1: CGFloat = 80
    private var currentHP2: CGFloat = 80
    private var barPct1: CGFloat = 1.0   // tracks bar's current rendered %
    private var barPct2: CGFloat = 1.0

    private var hpLabel1: SKLabelNode!
    private var hpLabel2: SKLabelNode!

    private var battleResult: BattleResult?

    /// Prevents didMove(to:) from re-running full setup on phase transitions.
    private var isSetUp = false

    /// Images pre-fetched during the intro phase.
    private var preloadedImage1: UIImage?
    private var preloadedImage2: UIImage?

    // MARK: - Init

    let environment: BattleEnvironment

    init(fighter1: Animal, fighter2: Animal, size: CGSize, environment: BattleEnvironment = .grassland) {
        self.fighter1Animal = fighter1
        self.fighter2Animal = fighter2
        self.environment = environment
        super.init(size: size)
        self.scaleMode = .aspectFill
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    // MARK: - Scene Setup

    override func didMove(to view: SKView) {
        beginBattle()
    }

    /// Idempotent setup + animation start. Safe to call from both didMove(to:)
    /// and BattleView's phase-change handler — the isSetUp guard prevents double-firing.
    func beginBattle() {
        guard !isSetUp else { return }
        isSetUp = true

        setupBackground()
        setupStars()
        setupArenaFloor()
        setupEnvironmentElements()
        setupFighterGlows()
        setupGround()
        setupHealthBars()
        setupSprites()

        let wait = SKAction.wait(forDuration: 0.5)
        let start = SKAction.run { [weak self] in self?.startMultiHitAnimation() }
        run(SKAction.sequence([wait, start]))
    }

    // MARK: - Background

    private func setupBackground() {
        let topUI = UIColor(environment.bgTop)
        let bottomUI = UIColor(environment.bgBottom)
        backgroundColor = topUI

        let gradientNode = makeGradientNode(
            topColor:    topUI,
            bottomColor: bottomUI,
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
        // Night/storm/volcano get many bright stars; sky/ocean/grassland get few or none
        let count: Int
        switch environment {
        case .night:   count = 55
        case .storm:   count = 15
        case .volcano: count = 20
        case .arctic:  count = 22
        case .desert:  count = 18
        case .jungle:  count = 8
        case .sky:     count = 6
        default:       count = 14
        }
        for _ in 0..<count {
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

            let fadeDuration = Double.random(in: 0.8...2.5)
            let fadeDelay    = Double.random(in: 0...2.0)
            let minAlpha     = CGFloat.random(in: 0.05...0.25)
            let maxAlpha     = CGFloat.random(in: 0.6...1.0)

            star.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.wait(forDuration: fadeDelay),
                SKAction.fadeAlpha(to: minAlpha, duration: fadeDuration),
                SKAction.fadeAlpha(to: maxAlpha, duration: fadeDuration)
            ])))
        }
    }

    // MARK: - Ground

    private func setupGround() {
        let groundY = size.height * 0.25
        let accentUI = UIColor(environment.accentColor)

        let ground = SKShapeNode()
        let groundPath = CGMutablePath()
        groundPath.move(to: CGPoint(x: 0, y: groundY))
        groundPath.addLine(to: CGPoint(x: size.width, y: groundY))
        ground.path = groundPath
        ground.strokeColor = accentUI.withAlphaComponent(0.9)
        ground.lineWidth = 2
        ground.zPosition = -2
        addChild(ground)

        let glow = SKShapeNode()
        glow.path = groundPath
        glow.strokeColor = accentUI.withAlphaComponent(0.3)
        glow.lineWidth = 8
        glow.zPosition = -3
        addChild(glow)
    }

    // MARK: - Arena Floor

    private func setupArenaFloor() {
        let accentUI = UIColor(environment.accentColor)
        let bgBottomUI = UIColor(environment.bgBottom)

        // Tiled hex-dot grid on the floor area for depth
        let floorY = size.height * 0.25
        let cols = 14, rows = 3
        let spacingX: CGFloat = size.width / CGFloat(cols)
        let spacingY: CGFloat = 18
        for row in 0..<rows {
            for col in 0..<cols {
                let offsetX: CGFloat = row % 2 == 0 ? 0 : spacingX / 2
                let x = CGFloat(col) * spacingX + offsetX + spacingX / 2
                let y = floorY - CGFloat(row + 1) * spacingY
                guard y > 0 else { continue }
                let dot = SKShapeNode(circleOfRadius: 1.2)
                dot.fillColor = accentUI.withAlphaComponent(CGFloat.random(in: 0.10...0.25))
                dot.strokeColor = .clear
                dot.position = CGPoint(x: x, y: y)
                dot.zPosition = -4
                addChild(dot)
            }
        }

        // Faint crowd silhouette band at very bottom
        let bandHeight: CGFloat = size.height * 0.12
        let crowdNode = makeGradientNode(
            topColor:    bgBottomUI.withAlphaComponent(0.0),
            bottomColor: bgBottomUI.withAlphaComponent(0.7),
            size: CGSize(width: size.width, height: bandHeight)
        )
        crowdNode.position = CGPoint(x: size.width / 2, y: bandHeight / 2)
        crowdNode.zPosition = -4
        addChild(crowdNode)

        // Scattered crowd bumps
        for i in 0..<22 {
            let cx = CGFloat(i) * (size.width / 22) + CGFloat.random(in: 0...12)
            let ch = CGFloat.random(in: 6...18)
            let bump = SKShapeNode(rectOf: CGSize(width: CGFloat.random(in: 5...14), height: ch),
                                   cornerRadius: 3)
            bump.fillColor = accentUI.withAlphaComponent(CGFloat.random(in: 0.20...0.45))
            bump.strokeColor = .clear
            bump.position = CGPoint(x: cx, y: ch / 2)
            bump.zPosition = -3
            addChild(bump)
        }
    }

    // MARK: - Per-Environment Elements

    private func setupEnvironmentElements() {
        switch environment {
        case .ocean:   setupOceanWaves()
        case .sky:     setupSkyClouds()
        case .arctic:  setupArcticSnow()
        case .desert:  setupDesertDunes()
        case .jungle:  setupJungleVines()
        case .volcano: setupVolcanoEmbers()
        case .night:   setupNightMoon()
        case .storm:   setupStormRain()
        case .grassland: break
        }
    }

    private func setupOceanWaves() {
        for i in 0..<3 {
            let waveY = size.height * 0.18 - CGFloat(i) * 14
            let wave = SKShapeNode()
            let path = CGMutablePath()
            let segments = 8
            let segW = size.width / CGFloat(segments)
            path.move(to: CGPoint(x: 0, y: waveY))
            for s in 0...segments {
                let px = CGFloat(s) * segW
                let py = waveY + (s % 2 == 0 ? 6 : -6)
                path.addLine(to: CGPoint(x: px, y: py))
            }
            wave.path = path
            wave.strokeColor = UIColor(environment.accentColor).withAlphaComponent(0.25 - CGFloat(i) * 0.06)
            wave.lineWidth = 1.5
            wave.zPosition = -2
            addChild(wave)
            let shift = SKAction.repeatForever(SKAction.sequence([
                SKAction.moveBy(x: 12, y: 0, duration: 1.4),
                SKAction.moveBy(x: -12, y: 0, duration: 1.4)
            ]))
            wave.run(shift)
        }
    }

    private func setupSkyClouds() {
        let cloudPositions: [(CGFloat, CGFloat, CGFloat)] = [
            (size.width * 0.15, size.height * 0.72, 1.0),
            (size.width * 0.65, size.height * 0.80, 0.7),
            (size.width * 0.88, size.height * 0.65, 0.55),
        ]
        for (cx, cy, scale) in cloudPositions {
            let cloud = makeCloudNode(scale: scale)
            cloud.position = CGPoint(x: cx, y: cy)
            cloud.zPosition = -2
            addChild(cloud)
            let drift = SKAction.repeatForever(SKAction.sequence([
                SKAction.moveBy(x: 18, y: 0, duration: 5.0),
                SKAction.moveBy(x: -18, y: 0, duration: 5.0)
            ]))
            cloud.run(drift)
        }
    }

    private func makeCloudNode(scale: CGFloat) -> SKNode {
        let node = SKNode()
        let radii: [(CGFloat, CGFloat, CGFloat)] = [(0, 0, 18), (-16, -4, 13), (16, -4, 13), (-8, 8, 10), (8, 8, 10)]
        for (dx, dy, r) in radii {
            let blob = SKShapeNode(circleOfRadius: r * scale)
            blob.fillColor = UIColor.white.withAlphaComponent(0.10)
            blob.strokeColor = UIColor.white.withAlphaComponent(0.06)
            blob.lineWidth = 0.5
            blob.position = CGPoint(x: dx * scale, y: dy * scale)
            node.addChild(blob)
        }
        return node
    }

    private func setupArcticSnow() {
        for _ in 0..<40 {
            let flake = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.8...2.2))
            flake.fillColor = UIColor.white.withAlphaComponent(CGFloat.random(in: 0.4...0.85))
            flake.strokeColor = .clear
            flake.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )
            flake.zPosition = -2
            addChild(flake)
            let fallDist = CGFloat.random(in: 40...100)
            let dur = Double.random(in: 3.0...6.0)
            let delay = Double.random(in: 0...4.0)
            flake.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.moveBy(x: CGFloat.random(in: -10...10), y: -fallDist, duration: dur),
                SKAction.moveBy(x: 0, y: fallDist + size.height * 0.1, duration: 0)
            ])))
        }
    }

    private func setupDesertDunes() {
        let duneColor = UIColor(environment.accentColor).withAlphaComponent(0.18)
        let dune = SKShapeNode()
        let path = CGMutablePath()
        let baseY = size.height * 0.25
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: baseY * 0.7))
        path.addQuadCurve(to: CGPoint(x: size.width * 0.5, y: baseY * 0.85),
                          control: CGPoint(x: size.width * 0.25, y: baseY * 1.1))
        path.addQuadCurve(to: CGPoint(x: size.width, y: baseY * 0.65),
                          control: CGPoint(x: size.width * 0.75, y: baseY * 1.0))
        path.addLine(to: CGPoint(x: size.width, y: 0))
        path.closeSubpath()
        dune.path = path
        dune.fillColor = duneColor
        dune.strokeColor = .clear
        dune.zPosition = -3
        addChild(dune)
    }

    private func setupJungleVines() {
        let vineColor = UIColor(environment.accentColor).withAlphaComponent(0.22)
        for side in [0, 1] {
            let startX: CGFloat = side == 0 ? 0 : size.width
            for i in 0..<3 {
                let vine = SKShapeNode()
                let path = CGMutablePath()
                let topY = size.height * (0.55 + CGFloat(i) * 0.08)
                let offsetX: CGFloat = side == 0 ? CGFloat(i * 10) : -CGFloat(i * 10)
                path.move(to: CGPoint(x: startX + offsetX, y: topY))
                for seg in 1...5 {
                    let py = topY - CGFloat(seg) * 30
                    let px = startX + offsetX + (side == 0 ? CGFloat(seg % 2 == 0 ? 8 : -4) : CGFloat(seg % 2 == 0 ? -8 : 4))
                    path.addLine(to: CGPoint(x: px, y: py))
                }
                vine.path = path
                vine.strokeColor = vineColor
                vine.lineWidth = 1.5
                vine.zPosition = -2
                addChild(vine)
            }
        }
    }

    private func setupVolcanoEmbers() {
        for _ in 0..<18 {
            let ember = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.0...2.5))
            ember.fillColor = UIColor(red: 1.0, green: CGFloat.random(in: 0.3...0.7), blue: 0, alpha: 0.8)
            ember.strokeColor = .clear
            let startX = CGFloat.random(in: size.width * 0.3...size.width * 0.7)
            let startY = CGFloat.random(in: 0...size.height * 0.2)
            ember.position = CGPoint(x: startX, y: startY)
            ember.zPosition = 1
            addChild(ember)
            let riseY = CGFloat.random(in: 80...200)
            let dur = Double.random(in: 1.5...3.5)
            let delay = Double.random(in: 0...3.0)
            ember.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.group([
                    SKAction.moveBy(x: CGFloat.random(in: -20...20), y: riseY, duration: dur),
                    SKAction.sequence([
                        SKAction.fadeAlpha(to: 1.0, duration: dur * 0.3),
                        SKAction.fadeAlpha(to: 0.0, duration: dur * 0.7)
                    ])
                ]),
                SKAction.move(to: CGPoint(x: startX, y: startY), duration: 0),
                SKAction.fadeAlpha(to: 0.8, duration: 0)
            ])))
        }
    }

    private func setupNightMoon() {
        let moon = SKShapeNode(circleOfRadius: 22)
        moon.fillColor = UIColor(white: 0.95, alpha: 0.85)
        moon.strokeColor = UIColor(white: 1.0, alpha: 0.3)
        moon.lineWidth = 2
        moon.position = CGPoint(x: size.width * 0.82, y: size.height * 0.78)
        moon.zPosition = -4
        addChild(moon)
        // Moon glow
        let moonGlow = makeGlowNode(color: UIColor(white: 0.9, alpha: 0.15), radius: 50)
        moonGlow.position = moon.position
        moonGlow.zPosition = -5
        addChild(moonGlow)
        moon.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.7, duration: 3.0),
            SKAction.fadeAlpha(to: 0.85, duration: 3.0)
        ])))
    }

    private func setupStormRain() {
        for _ in 0..<35 {
            let rain = SKShapeNode()
            let path = CGMutablePath()
            let len = CGFloat.random(in: 12...22)
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: -len * 0.3, y: -len))
            rain.path = path
            rain.strokeColor = UIColor(white: 0.75, alpha: CGFloat.random(in: 0.25...0.5))
            rain.lineWidth = 0.8
            let startX = CGFloat.random(in: 0...size.width)
            let startY = CGFloat.random(in: size.height * 0.25...size.height)
            rain.position = CGPoint(x: startX, y: startY)
            rain.zPosition = 1
            addChild(rain)
            let fallDist = CGFloat.random(in: 60...130)
            let dur = Double.random(in: 0.5...1.0)
            let delay = Double.random(in: 0...1.5)
            rain.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.moveBy(x: -fallDist * 0.3, y: -fallDist, duration: dur),
                SKAction.move(to: CGPoint(x: startX, y: startY), duration: 0)
            ])))
        }
    }

    // MARK: - Fighter Glows

    private func setupFighterGlows() {
        // Orange bloom behind fighter 1
        let glow1 = makeGlowNode(color: UIColor(red: 1.0, green: 0.34, blue: 0.13, alpha: 0.22),
                                 radius: size.width * 0.32)
        glow1.position = CGPoint(x: size.width * 0.22, y: size.height * 0.45)
        glow1.zPosition = 0
        addChild(glow1)

        // Cyan bloom behind fighter 2
        let glow2 = makeGlowNode(color: UIColor(red: 0.0, green: 0.81, blue: 0.81, alpha: 0.18),
                                 radius: size.width * 0.32)
        glow2.position = CGPoint(x: size.width * 0.78, y: size.height * 0.45)
        glow2.zPosition = 0
        addChild(glow2)

        // Pulse each glow
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.55, duration: 0.9),
            SKAction.fadeAlpha(to: 1.0,  duration: 0.9)
        ])
        glow1.run(SKAction.repeatForever(pulse))
        let pulse2 = SKAction.sequence([
            SKAction.wait(forDuration: 0.45),
            SKAction.fadeAlpha(to: 0.55, duration: 0.9),
            SKAction.fadeAlpha(to: 1.0,  duration: 0.9)
        ])
        glow2.run(SKAction.repeatForever(pulse2))
    }

    private func makeGlowNode(color: UIColor, radius: CGFloat) -> SKSpriteNode {
        let diameter = Int(radius * 2)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
        let img = renderer.image { ctx in
            let center = CGPoint(x: radius, y: radius)
            let colors = [color.cgColor, color.withAlphaComponent(0).cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: colors, locations: [0, 1])!
            ctx.cgContext.drawRadialGradient(gradient,
                startCenter: center, startRadius: 0,
                endCenter: center,   endRadius: radius,
                options: [])
        }
        return SKSpriteNode(texture: SKTexture(image: img),
                            size: CGSize(width: diameter, height: diameter))
    }

    // MARK: - Health Bars

    private func setupHealthBars() {
        // Randomise HP pools per battle
        maxHP1 = CGFloat(Int.random(in: 70...100))
        maxHP2 = CGFloat(Int.random(in: 70...100))
        currentHP1 = maxHP1
        currentHP2 = maxHP2
        barPct1 = 1.0
        barPct2 = 1.0

        let barWidth:   CGFloat = size.width * 0.37
        let barHeight:  CGFloat = 14
        let barY:       CGFloat = size.height * 0.75
        let cornerRadius: CGFloat = 7
        let fillWidth   = barWidth - 4
        let fillHeight: CGFloat = 10
        let fillCorner: CGFloat = 5
        healthBarFullWidth = fillWidth

        func fullPath() -> CGPath {
            UIBezierPath(
                roundedRect: CGRect(x: -fillWidth / 2, y: -fillHeight / 2,
                                    width: fillWidth, height: fillHeight),
                cornerRadius: fillCorner
            ).cgPath
        }

        func bgPath() -> CGPath {
            UIBezierPath(
                roundedRect: CGRect(x: -barWidth / 2, y: -barHeight / 2,
                                    width: barWidth, height: barHeight),
                cornerRadius: cornerRadius
            ).cgPath
        }

        // --- Fighter 1 (left) ---
        let bg1 = SKShapeNode(path: bgPath())
        bg1.fillColor = UIColor(white: 0.1, alpha: 0.9)
        bg1.strokeColor = UIColor(white: 0.3, alpha: 0.5)
        bg1.lineWidth = 1
        bg1.position = CGPoint(x: size.width * 0.24, y: barY)
        bg1.zPosition = 5
        addChild(bg1)

        healthFill1 = SKShapeNode(path: fullPath())
        healthFill1.fillColor = hpColor(percent: 1.0)
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

        hpLabel1 = SKLabelNode(text: "\(Int(currentHP1))/\(Int(maxHP1)) HP")
        hpLabel1.fontName = "AvenirNext-Bold"
        hpLabel1.fontSize = 8
        hpLabel1.fontColor = UIColor.white.withAlphaComponent(0.65)
        hpLabel1.horizontalAlignmentMode = .center
        hpLabel1.position = CGPoint(x: size.width * 0.24, y: barY - barHeight / 2 - 10)
        hpLabel1.zPosition = 7
        addChild(hpLabel1)

        // --- Fighter 2 (right) ---
        let bg2 = SKShapeNode(path: bgPath())
        bg2.fillColor = UIColor(white: 0.1, alpha: 0.9)
        bg2.strokeColor = UIColor(white: 0.3, alpha: 0.5)
        bg2.lineWidth = 1
        bg2.position = CGPoint(x: size.width * 0.76, y: barY)
        bg2.zPosition = 5
        addChild(bg2)

        healthFill2 = SKShapeNode(path: fullPath())
        healthFill2.fillColor = hpColor(percent: 1.0)
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

        hpLabel2 = SKLabelNode(text: "\(Int(currentHP2))/\(Int(maxHP2)) HP")
        hpLabel2.fontName = "AvenirNext-Bold"
        hpLabel2.fontSize = 8
        hpLabel2.fontColor = UIColor.white.withAlphaComponent(0.65)
        hpLabel2.horizontalAlignmentMode = .center
        hpLabel2.position = CGPoint(x: size.width * 0.76, y: barY - barHeight / 2 - 10)
        hpLabel2.zPosition = 7
        addChild(hpLabel2)
    }

    // MARK: - Sprites

    private func setupSprites() {
        sprite1 = AnimalSprite(animal: fighter1Animal)
        sprite1.position = CGPoint(x: size.width * 0.2, y: size.height * 0.45)
        sprite1.zPosition = 2
        addChild(sprite1)

        sprite2 = AnimalSprite(animal: fighter2Animal)
        sprite2.xScale = -sprite2.xScale
        sprite2.position = CGPoint(x: size.width * 0.8, y: size.height * 0.45)
        sprite2.zPosition = 2
        addChild(sprite2)

        if let img = preloadedImage1 { sprite1.updateTexture(with: img) }
        if let img = preloadedImage2 { sprite2.updateTexture(with: img) }
    }

    // MARK: - Multi-Hit Battle Animation

    /// 6 alternating rounds: F1, F2, F1, F2, F1, F2.
    /// Neither fighter dominates — the final HP bars (set by setBattleResult) show who won.
    func startMultiHitAnimation() {
        runAlternatingHit(round: 1, total: 6)
    }

    private func runAlternatingHit(round: Int, total: Int) {
        let attackerIndex = round % 2 == 1 ? 1 : 2          // odd=F1, even=F2
        let hitNumber     = Int(ceil(Double(round) / 2.0))   // 1,1,2,2,3,3

        performHit(attackerIndex: attackerIndex, hitNumber: hitNumber) { [weak self] in
            guard let self else { return }
            if round < total {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                    self.runAlternatingHit(round: round + 1, total: total)
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    self.onAnimationComplete?()
                }
            }
        }
    }

    /// Plays one hit: attacker lunges, impact fires, defender recoils, HP updates.
    private func performHit(attackerIndex: Int, hitNumber: Int, completion: @escaping () -> Void) {
        let attacker = attackerIndex == 1 ? sprite1! : sprite2!
        let defender = attackerIndex == 1 ? sprite2! : sprite1!
        // direction that attacker faces: +1 = right (F1), -1 = left (F2)
        let attackDir: CGFloat = attackerIndex == 1 ? 1.0 : -1.0

        // Attacker lunge
        let lunge    = SKAction.moveBy(x: attackDir * 58, y: 0, duration: 0.20)
        lunge.timingMode = .easeIn
        let pullBack = SKAction.moveBy(x: -attackDir * 58, y: 0, duration: 0.26)
        pullBack.timingMode = .easeOut
        attacker.run(SKAction.sequence([lunge, pullBack]))

        // Impact fires when lunge reaches defender
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) { [weak self] in
            guard let self else { return }

            // Critical hit: ~14% chance
            let isCritical = Int.random(in: 0...6) == 0
            let baseDmg = isCritical ? Int.random(in: 18...28) : Int.random(in: 8...20)
            let damage = CGFloat(baseDmg)

            if attackerIndex == 1 {
                let oldPct = self.barPct2
                self.currentHP2 = max(0, self.currentHP2 - damage)
                let newPct = self.currentHP2 / self.maxHP2
                self.barPct2 = newPct
                self.animateHPBar(fillNode: self.healthFill2,
                                  label: self.hpLabel2,
                                  oldPct: oldPct, newPct: newPct,
                                  maxHP: self.maxHP2, currentHP: self.currentHP2)
                self.showDamageFloat(damage: baseDmg,
                                     near: defender.position,
                                     isCritical: isCritical)
            } else {
                let oldPct = self.barPct1
                self.currentHP1 = max(0, self.currentHP1 - damage)
                let newPct = self.currentHP1 / self.maxHP1
                self.barPct1 = newPct
                self.animateHPBar(fillNode: self.healthFill1,
                                  label: self.hpLabel1,
                                  oldPct: oldPct, newPct: newPct,
                                  maxHP: self.maxHP1, currentHP: self.currentHP1)
                self.showDamageFloat(damage: baseDmg,
                                     near: defender.position,
                                     isCritical: isCritical)
            }

            // Defender recoils away from attacker
            defender.playRecoil(direction: attackDir)

            // Screen shake
            self.miniShake()

            // Haptic feedback
            if isCritical {
                HapticsService.shared.heavy()
            } else if hitNumber == 3 {
                HapticsService.shared.medium()
            } else {
                HapticsService.shared.tap()
            }
        }

        // Callback after lunge + pull-back completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) {
            completion()
        }
    }

    // MARK: - HP Bar Helpers

    private func hpColor(percent: CGFloat) -> UIColor {
        switch percent {
        case 0.75...: return UIColor(red: 0.20, green: 0.90, blue: 0.30, alpha: 1)  // Green
        case 0.50..<0.75: return UIColor(red: 0.85, green: 0.90, blue: 0.10, alpha: 1)  // Yellow
        case 0.25..<0.50: return UIColor(red: 1.00, green: 0.50, blue: 0.10, alpha: 1)  // Orange
        default: return UIColor(red: 1.00, green: 0.18, blue: 0.18, alpha: 1)  // Red
        }
    }

    private func animateHPBar(fillNode: SKShapeNode,
                               label: SKLabelNode?,
                               oldPct: CGFloat,
                               newPct: CGFloat,
                               maxHP: CGFloat,
                               currentHP: CGFloat,
                               duration: TimeInterval = 0.35) {
        let targetPct = max(0, min(1, newPct))
        let startPct  = max(0, min(1, oldPct))
        let fullWidth = healthBarFullWidth
        let fillH: CGFloat = 10
        let fillR: CGFloat = 5

        fillNode.run(SKAction.customAction(withDuration: duration) { [weak self] node, elapsed in
            guard let self, let shape = node as? SKShapeNode else { return }
            let t      = min(1.0, CGFloat(elapsed) / CGFloat(duration))
            let smooth = t * t * (3 - 2 * t)  // smoothstep
            let pct    = startPct + (targetPct - startPct) * smooth
            let w      = max(2, fullWidth * pct)
            let rect   = CGRect(x: -fullWidth / 2, y: -fillH / 2, width: w, height: fillH)
            shape.path      = UIBezierPath(roundedRect: rect, cornerRadius: fillR).cgPath
            shape.fillColor = self.hpColor(percent: pct)
        })

        // Blink when critically low
        if targetPct < 0.25 {
            fillNode.removeAction(forKey: "hpBlink")
            fillNode.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.35, duration: 0.28),
                SKAction.fadeAlpha(to: 1.00, duration: 0.28)
            ])), withKey: "hpBlink")
        } else {
            fillNode.removeAction(forKey: "hpBlink")
            fillNode.alpha = 1.0
        }

        label?.text = "\(Int(max(0, currentHP)))/\(Int(maxHP)) HP"
    }

    // MARK: - Damage Float Numbers

    private func showDamageFloat(damage: Int, near position: CGPoint, isCritical: Bool) {
        let label = SKLabelNode(text: isCritical ? "💥 \(damage)!" : "-\(damage)")
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = isCritical ? 22 : 17
        label.fontColor = isCritical
            ? UIColor(red: 1.0, green: 0.82, blue: 0.0, alpha: 1)  // gold for crits
            : UIColor(red: 1.0, green: 0.28, blue: 0.28, alpha: 1) // red normal
        label.position = CGPoint(x: position.x + CGFloat.random(in: -15...15),
                                 y: position.y + 55)
        label.zPosition = 15
        label.setScale(isCritical ? 0.4 : 0.6)
        label.alpha = 0
        addChild(label)

        let popIn = SKAction.group([
            SKAction.fadeIn(withDuration: 0.08),
            SKAction.scale(to: isCritical ? 1.2 : 1.0, duration: 0.12)
        ])
        let floatUp = SKAction.moveBy(x: 0, y: 30, duration: 0.65)
        floatUp.timingMode = .easeOut
        let fadeOut = SKAction.sequence([
            SKAction.wait(forDuration: 0.30),
            SKAction.fadeOut(withDuration: 0.40)
        ])
        label.run(SKAction.sequence([
            popIn,
            SKAction.group([floatUp, fadeOut]),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Screen Shake (mini per-hit)

    private func miniShake() {
        removeAction(forKey: "miniShake")
        run(SKAction.sequence([
            SKAction.moveBy(x:  8, y:  2, duration: 0.04),
            SKAction.moveBy(x: -12, y: -3, duration: 0.04),
            SKAction.moveBy(x:  8, y:  2, duration: 0.04),
            SKAction.moveBy(x: -4, y: -1, duration: 0.03),
        ]), withKey: "miniShake")
    }

    // MARK: - Custom Image Override

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
        isSetUp = false   // didMove(to:) will re-initialize when SpriteView reappears
    }

    // MARK: - Battle Result (victory/defeat poses + final HP)

    func setBattleResult(_ result: BattleResult) {
        self.battleResult = result

        let fighter1Wins = result.winner == fighter1Animal.id
        let isDraw       = result.winner == "draw"

        // Smoothly settle HP bars to the API-specified final values
        finalizeHealthBars(result: result, fighter1Wins: fighter1Wins, isDraw: isDraw)

        // Victory / defeat poses after a short pause
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
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

            // Sprites stay visible so kids can peek at them by dragging the results panel down
        }
    }

    private func finalizeHealthBars(result: BattleResult, fighter1Wins: Bool, isDraw: Bool) {
        let winnerPct = isDraw ? 0.55 : CGFloat(result.winnerHealthPercent) / 100.0
        let loserPct  = isDraw ? 0.45 : CGFloat(result.loserHealthPercent)  / 100.0

        if fighter1Wins || isDraw {
            animateHPBar(fillNode: healthFill1, label: hpLabel1,
                         oldPct: barPct1, newPct: winnerPct,
                         maxHP: maxHP1, currentHP: maxHP1 * winnerPct, duration: 0.5)
            animateHPBar(fillNode: healthFill2, label: hpLabel2,
                         oldPct: barPct2, newPct: loserPct,
                         maxHP: maxHP2, currentHP: maxHP2 * loserPct, duration: 0.8)
            barPct1 = winnerPct; barPct2 = loserPct
        } else {
            animateHPBar(fillNode: healthFill2, label: hpLabel2,
                         oldPct: barPct2, newPct: winnerPct,
                         maxHP: maxHP2, currentHP: maxHP2 * winnerPct, duration: 0.5)
            animateHPBar(fillNode: healthFill1, label: hpLabel1,
                         oldPct: barPct1, newPct: loserPct,
                         maxHP: maxHP1, currentHP: maxHP1 * loserPct, duration: 0.8)
            barPct2 = winnerPct; barPct1 = loserPct
        }
    }

}
