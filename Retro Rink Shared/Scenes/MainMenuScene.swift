import SpriteKit

// MARK: - Main Menu Scene
class MainMenuScene: BaseScene {

    private var confirmDialog: ConfirmDialog?

    override func didMove(to view: SKView) {
        backgroundColor = RetroPalette.background
        super.didMove(to: view)

        setupBackground()
        setupIceTexture()
        setupTitle()
        setupMiniRink()
        setupMenu()
        setupSnowflakes()
    }

    // MARK: - Background

    private func setupBackground() {
        let w = size.width
        let h = size.height

        // Solid dark background
        let bg = SKSpriteNode(color: UIColor(hex: "0E0E1A"), size: CGSize(width: w, height: h))
        bg.zPosition = -2
        addChild(bg)
    }

    // MARK: - Ice Texture Background Effect

    private func setupIceTexture() {
        // Removed ice sheen streaks and scan lines for a cleaner background
    }

    // MARK: - Title

    private func setupTitle() {
        let titleNode = SKNode()
        titleNode.position = CGPoint(x: 0, y: 105)
        titleNode.zPosition = 10
        addChild(titleNode)

        // Drop shadow (offset down-right)
        let shadow = RetroFont.label("RETRO  RINK", size: 42, color: UIColor.black)
        shadow.position = CGPoint(x: 2, y: -2)
        shadow.alpha = 0.6
        shadow.zPosition = 0
        titleNode.addChild(shadow)

        // Accent glow behind title (wider spread)
        let glow2 = RetroFont.label("RETRO  RINK", size: 42, color: RetroPalette.accent)
        glow2.position = CGPoint(x: -1, y: 1)
        glow2.alpha = 0.25
        glow2.zPosition = 1
        titleNode.addChild(glow2)

        let glow = RetroFont.label("RETRO  RINK", size: 42, color: RetroPalette.accent)
        glow.position = CGPoint(x: 1, y: -1)
        glow.alpha = 0.3
        glow.zPosition = 2
        titleNode.addChild(glow)

        // Main title (white, on top)
        let title = RetroFont.label("RETRO  RINK", size: 42, color: .white)
        title.position = .zero
        title.zPosition = 3
        titleNode.addChild(title)

        // Pulsing animation on entire title group
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.02, duration: 1.5),
            SKAction.scale(to: 1.0, duration: 1.5),
        ])
        titleNode.run(SKAction.repeatForever(pulse))

        // Decorative horizontal lines flanking the title
        let lineWidth: CGFloat = 60
        let lineY: CGFloat = 0
        let titleHalfWidth: CGFloat = 175 // approximate half-width of title text

        for side in [-1.0, 1.0] {
            let lineX = CGFloat(side) * (titleHalfWidth + lineWidth / 2 + 10)
            let line = SKSpriteNode(color: RetroPalette.accent.withAlphaComponent(0.4),
                                    size: CGSize(width: lineWidth, height: 2))
            line.position = CGPoint(x: lineX, y: lineY)
            line.zPosition = 1
            titleNode.addChild(line)

            // Small diamond at line end
            let dot = SKSpriteNode(color: RetroPalette.accent.withAlphaComponent(0.5),
                                   size: CGSize(width: 4, height: 4))
            dot.position = CGPoint(x: lineX - CGFloat(side) * (lineWidth / 2 + 4), y: lineY)
            dot.zRotation = .pi / 4
            dot.zPosition = 1
            titleNode.addChild(dot)
        }

        // Tagline with subtle styling
        let tagline = RetroFont.label("ICE  HOCKEY  MANAGEMENT", size: RetroFont.smallSize, color: RetroPalette.textGray)
        tagline.position = CGPoint(x: 0, y: 72)
        tagline.zPosition = 10
        addChild(tagline)

        // Tagline underline accent
        let tagUnderline = SKSpriteNode(color: RetroPalette.accent.withAlphaComponent(0.2),
                                        size: CGSize(width: 200, height: 1))
        tagUnderline.position = CGPoint(x: 0, y: 64)
        tagUnderline.zPosition = 10
        addChild(tagUnderline)
    }

    // MARK: - Mini Rink Decoration

    private func setupMiniRink() {
        let rinkNode = SKNode()
        rinkNode.position = CGPoint(x: 0, y: -140)
        rinkNode.zPosition = 5
        addChild(rinkNode)

        // Rink ice fill (subtle)
        let iceFill = SKShapeNode(rectOf: CGSize(width: 150, height: 75), cornerRadius: 14)
        iceFill.fillColor = UIColor.white.withAlphaComponent(0.04)
        iceFill.strokeColor = .clear
        iceFill.isAntialiased = false
        rinkNode.addChild(iceFill)

        // Rink outline (brighter than before)
        let rink = SKShapeNode(rectOf: CGSize(width: 150, height: 75), cornerRadius: 14)
        rink.strokeColor = UIColor.white.withAlphaComponent(0.25)
        rink.lineWidth = 2
        rink.fillColor = .clear
        rink.isAntialiased = false
        rinkNode.addChild(rink)

        // Center red line
        let centerLine = SKSpriteNode(color: RetroPalette.redLine.withAlphaComponent(0.3),
                                      size: CGSize(width: 2, height: 68))
        rinkNode.addChild(centerLine)

        // Center circle
        let centerCircle = SKShapeNode(circleOfRadius: 12)
        centerCircle.strokeColor = RetroPalette.blueLine.withAlphaComponent(0.25)
        centerCircle.lineWidth = 1
        centerCircle.fillColor = .clear
        centerCircle.isAntialiased = false
        rinkNode.addChild(centerCircle)

        // Center dot
        let centerDot = SKShapeNode(circleOfRadius: 3)
        centerDot.fillColor = RetroPalette.blueLine.withAlphaComponent(0.4)
        centerDot.strokeColor = .clear
        rinkNode.addChild(centerDot)

        // Blue lines
        for xPos: CGFloat in [-38, 38] {
            let blueLine = SKSpriteNode(color: RetroPalette.blueLine.withAlphaComponent(0.25),
                                        size: CGSize(width: 2, height: 64))
            blueLine.position = CGPoint(x: xPos, y: 0)
            rinkNode.addChild(blueLine)
        }

        // Goal creases (small arcs at each end)
        for side: CGFloat in [-1, 1] {
            let crease = SKShapeNode(circleOfRadius: 8)
            crease.strokeColor = RetroPalette.redLine.withAlphaComponent(0.2)
            crease.lineWidth = 1
            crease.fillColor = RetroPalette.redLine.withAlphaComponent(0.05)
            crease.isAntialiased = false
            crease.position = CGPoint(x: side * 65, y: 0)
            rinkNode.addChild(crease)

            // Goal line
            let goalLine = SKSpriteNode(color: RetroPalette.redLine.withAlphaComponent(0.2),
                                        size: CGSize(width: 1, height: 20))
            goalLine.position = CGPoint(x: side * 62, y: 0)
            rinkNode.addChild(goalLine)
        }

        // Faceoff dots (4 corners)
        for (fx, fy) in [(-30.0, 22.0), (30.0, 22.0), (-30.0, -22.0), (30.0, -22.0)] {
            let dot = SKShapeNode(circleOfRadius: 2)
            dot.fillColor = RetroPalette.redLine.withAlphaComponent(0.3)
            dot.strokeColor = .clear
            dot.position = CGPoint(x: fx, y: fy)
            rinkNode.addChild(dot)
        }

        // Animated puck dot orbiting the rink
        let puck = SKShapeNode(circleOfRadius: 2.5)
        puck.fillColor = .white
        puck.strokeColor = .clear
        puck.alpha = 0.7
        puck.glowWidth = 1.0
        rinkNode.addChild(puck)

        // Puck trail
        let trail = SKShapeNode(circleOfRadius: 1.5)
        trail.fillColor = .white
        trail.strokeColor = .clear
        trail.alpha = 0.3
        rinkNode.addChild(trail)

        let path = CGMutablePath()
        path.addEllipse(in: CGRect(x: -55, y: -25, width: 110, height: 50))
        let followPath = SKAction.follow(path, asOffset: false, orientToPath: false, duration: 4.0)
        puck.run(SKAction.repeatForever(followPath))

        // Trail follows with slight delay
        let trailPath = SKAction.sequence([
            SKAction.wait(forDuration: 0.15),
            SKAction.repeatForever(SKAction.follow(path, asOffset: false, orientToPath: false, duration: 4.0))
        ])
        trail.run(trailPath)
    }

    // MARK: - Menu Buttons

    private func setupMenu() {
        let hasGame = GameManager.shared.hasActiveGame

        if hasGame {
            // Continue button (primary)
            let continueBtn = RetroButton(text: "CONTINUE", width: 240, height: 50,
                                          color: RetroPalette.midPanel, borderColor: RetroPalette.accent,
                                          fontSize: RetroFont.headerSize)
            continueBtn.position = CGPoint(x: 0, y: 15)
            continueBtn.zPosition = 10
            continueBtn.action = { [weak self] in
                self?.continueGame()
            }
            addChild(continueBtn)

            // New Game (secondary, smaller)
            let newBtn = RetroButton(text: "NEW GAME", width: 180, height: 38,
                                     color: UIColor(hex: "222233"), borderColor: UIColor(hex: "444466"))
            newBtn.position = CGPoint(x: 0, y: -42)
            newBtn.zPosition = 10
            newBtn.action = { [weak self] in
                self?.promptNewGame()
            }
            addChild(newBtn)
        } else {
            // New Game (primary, no save exists)
            let newBtn = RetroButton(text: "NEW GAME", width: 240, height: 50,
                                     color: RetroPalette.midPanel, borderColor: RetroPalette.accent,
                                     fontSize: RetroFont.headerSize)
            newBtn.position = CGPoint(x: 0, y: 5)
            newBtn.zPosition = 10
            newBtn.action = { [weak self] in
                self?.startNewGame()
            }
            addChild(newBtn)
        }

        // Version label
        let version = RetroFont.label("v1.0", size: RetroFont.tinySize, color: UIColor(hex: "333344"))
        version.position = CGPoint(x: safeRight - 22, y: safeBottom + 7)
        version.zPosition = 10
        addChild(version)
    }

    // MARK: - Snowflake / Ice Particle Decorations

    private func setupSnowflakes() {
        let halfW = size.width / 2
        let halfH = size.height / 2

        for _ in 0..<30 {
            let radius = CGFloat.random(in: 0.5...2.0)
            let particle = SKShapeNode(circleOfRadius: radius)
            particle.fillColor = .white
            particle.strokeColor = .clear
            particle.alpha = CGFloat.random(in: 0.05...0.25)
            particle.position = CGPoint(
                x: CGFloat.random(in: -halfW...halfW),
                y: CGFloat.random(in: -halfH...halfH)
            )
            particle.zPosition = 0
            addChild(particle)

            let duration = Double.random(in: 4...10)
            let drift = SKAction.moveBy(x: CGFloat.random(in: -40...40),
                                        y: CGFloat.random(in: -60...(-25)),
                                        duration: duration)
            let fade = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.02, duration: duration),
                SKAction.fadeAlpha(to: CGFloat.random(in: 0.1...0.25), duration: 0.5),
            ])

            let reset = SKAction.run { [halfW, halfH] in
                particle.position = CGPoint(
                    x: CGFloat.random(in: -halfW...halfW),
                    y: halfH + 10
                )
            }

            particle.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.group([drift, fade]),
                reset,
            ])))
        }
    }

    // MARK: - Navigation

    private func continueGame() {
        guard let view = view else { return }
        GameManager.transition(from: view, toSceneType: HubScene.self)
    }

    private func promptNewGame() {
        // Show confirm dialog when a save already exists
        let dialog = ConfirmDialog(
            title: "NEW GAME",
            message: "This will overwrite your\ncurrent save data.",
            confirmText: "START NEW",
            cancelText: "CANCEL"
        )
        dialog.onConfirm = { [weak self] in
            self?.confirmDialog = nil
            self?.startNewGame()
        }
        dialog.onCancel = { [weak self] in
            self?.confirmDialog = nil
        }
        confirmDialog = dialog
        addChild(dialog)
    }

    private func startNewGame() {
        if GameManager.shared.hasActiveGame {
            GameManager.shared.deleteSave()
        }
        guard let view = view else { return }
        GameManager.transition(from: view, toSceneType: TeamSelectScene.self)
    }
}
