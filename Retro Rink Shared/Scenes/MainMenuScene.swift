import SpriteKit

// MARK: - Main Menu Scene
class MainMenuScene: BaseScene {

    private var confirmDialog: ConfirmDialog?

    override func didMove(to view: SKView) {
        backgroundColor = RetroPalette.background
        super.didMove(to: view)

        setupBackground()
        setupTitle()
        setupMiniRink()
        setupMenu()
        setupSnowflakes()
    }

    // MARK: - Background

    private func setupBackground() {
        let w = size.width
        let h = size.height
        // Layered gradient-style background
        let colors: [(UIColor, CGFloat)] = [
            (UIColor(hex: "0A0A1E"), -h / 2),
            (UIColor(hex: "121230"), -h / 4),
            (UIColor(hex: "1A1A3E"), 0),
            (UIColor(hex: "121230"), h / 4),
        ]
        for (color, y) in colors {
            let stripe = SKSpriteNode(color: color, size: CGSize(width: w, height: h / 4))
            stripe.position = CGPoint(x: 0, y: y)
            stripe.zPosition = -1
            addChild(stripe)
        }
    }

    // MARK: - Title

    private func setupTitle() {
        // Main title
        let title = RetroFont.label("RETRO  RINK", size: 42, color: .white)
        title.position = CGPoint(x: 0, y: 100)
        title.zPosition = 10
        addChild(title)

        // Glow shadow behind title
        let glow = RetroFont.label("RETRO  RINK", size: 42, color: RetroPalette.accent)
        glow.position = CGPoint(x: 1, y: 99)
        glow.alpha = 0.4
        glow.zPosition = 9
        addChild(glow)

        // Tagline
        let tagline = RetroFont.label("ICE HOCKEY MANAGEMENT", size: RetroFont.smallSize, color: RetroPalette.textGray)
        tagline.position = CGPoint(x: 0, y: 70)
        addChild(tagline)

        // Pulsing animation on title
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.02, duration: 1.5),
            SKAction.scale(to: 1.0, duration: 1.5),
        ])
        title.run(SKAction.repeatForever(pulse))
    }

    // MARK: - Mini Rink Decoration

    private func setupMiniRink() {
        let rinkNode = SKNode()
        rinkNode.position = CGPoint(x: 0, y: -130)
        addChild(rinkNode)

        // Rink outline
        let rink = SKShapeNode(rectOf: CGSize(width: 120, height: 60), cornerRadius: 10)
        rink.strokeColor = UIColor.white.withAlphaComponent(0.15)
        rink.lineWidth = 1.5
        rink.fillColor = UIColor.white.withAlphaComponent(0.03)
        rink.isAntialiased = false
        rinkNode.addChild(rink)

        // Center red line
        let centerLine = SKSpriteNode(color: RetroPalette.redLine.withAlphaComponent(0.2),
                                      size: CGSize(width: 1, height: 56))
        rinkNode.addChild(centerLine)

        // Center dot
        let centerDot = SKShapeNode(circleOfRadius: 3)
        centerDot.fillColor = RetroPalette.blueLine.withAlphaComponent(0.3)
        centerDot.strokeColor = .clear
        rinkNode.addChild(centerDot)

        // Blue lines
        let leftBlueLine = SKSpriteNode(color: RetroPalette.blueLine.withAlphaComponent(0.15),
                                        size: CGSize(width: 1, height: 50))
        leftBlueLine.position = CGPoint(x: -30, y: 0)
        rinkNode.addChild(leftBlueLine)

        let rightBlueLine = SKSpriteNode(color: RetroPalette.blueLine.withAlphaComponent(0.15),
                                         size: CGSize(width: 1, height: 50))
        rightBlueLine.position = CGPoint(x: 30, y: 0)
        rinkNode.addChild(rightBlueLine)

        // Animated puck dot orbiting the rink
        let puck = SKShapeNode(circleOfRadius: 2)
        puck.fillColor = .white
        puck.strokeColor = .clear
        puck.alpha = 0.6
        rinkNode.addChild(puck)

        // Create an oval path for the puck to follow
        let path = CGMutablePath()
        path.addEllipse(in: CGRect(x: -45, y: -20, width: 90, height: 40))
        let followPath = SKAction.follow(path, asOffset: false, orientToPath: false, duration: 4.0)
        puck.run(SKAction.repeatForever(followPath))
    }

    // MARK: - Menu Buttons

    private func setupMenu() {
        let hasGame = GameManager.shared.hasActiveGame

        if hasGame {
            // Continue button (primary)
            let continueBtn = RetroButton(text: "CONTINUE", width: 220, height: 48,
                                          color: RetroPalette.midPanel, borderColor: RetroPalette.accent,
                                          fontSize: RetroFont.headerSize)
            continueBtn.position = CGPoint(x: 0, y: 10)
            continueBtn.action = { [weak self] in
                self?.continueGame()
            }
            addChild(continueBtn)

            // New Game (secondary, smaller)
            let newBtn = RetroButton(text: "NEW GAME", width: 180, height: 38,
                                     color: UIColor(hex: "333344"), borderColor: UIColor(hex: "555577"))
            newBtn.position = CGPoint(x: 0, y: -40)
            newBtn.action = { [weak self] in
                self?.promptNewGame()
            }
            addChild(newBtn)
        } else {
            // New Game (primary, no save exists)
            let newBtn = RetroButton(text: "NEW GAME", width: 220, height: 48,
                                     color: RetroPalette.midPanel, borderColor: RetroPalette.accent,
                                     fontSize: RetroFont.headerSize)
            newBtn.position = CGPoint(x: 0, y: 0)
            newBtn.action = { [weak self] in
                self?.startNewGame()
            }
            addChild(newBtn)
        }

        // Version label
        let version = RetroFont.label("v1.0", size: RetroFont.tinySize, color: UIColor(hex: "444444"))
        version.position = CGPoint(x: safeRight - 22, y: safeBottom + 7)
        addChild(version)
    }

    // MARK: - Snowflake / Ice Particle Decorations

    private func setupSnowflakes() {
        let halfW = size.width / 2
        let halfH = size.height / 2

        for _ in 0..<25 {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...2))
            particle.fillColor = .white
            particle.strokeColor = .clear
            particle.alpha = CGFloat.random(in: 0.1...0.3)
            particle.position = CGPoint(
                x: CGFloat.random(in: -halfW...halfW),
                y: CGFloat.random(in: -halfH...halfH)
            )
            addChild(particle)

            let duration = Double.random(in: 3...8)
            let drift = SKAction.moveBy(x: CGFloat.random(in: -30...30),
                                        y: CGFloat.random(in: -50...(-20)),
                                        duration: duration)
            let fade = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.05, duration: duration),
                SKAction.fadeAlpha(to: 0.3, duration: 0.5),
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
