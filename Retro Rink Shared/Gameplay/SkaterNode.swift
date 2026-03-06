import SpriteKit

// MARK: - Skater Node (On-Ice Player with Animation State Machine)
class SkaterNode: SKNode {

    let playerID: UUID
    let posType: Position   // avoid collision with SKNode.position
    let teamIndex: Int      // 0 = home, 1 = away
    var playerStats: Player

    // MARK: - Animation State
    enum AnimState {
        case idle, skating, shooting, celebrating, deking, hit
    }
    var animState: AnimState = .idle

    // MARK: - Visual Nodes
    let sprite: SKSpriteNode
    private var shadowNode: SKShapeNode
    private var selectionRing: SKShapeNode?
    private var numberLabel: SKLabelNode
    private var puckIndicator: SKShapeNode?

    // MARK: - Pre-loaded Textures (left + right variants for direction)
    private var idleTextureRight: SKTexture!
    private var idleTextureLeft: SKTexture!
    // Goalie textures
    private var goalieTextureRight: SKTexture?
    private var goalieTextureLeft: SKTexture?

    // MARK: - State
    var hasPuck: Bool = false {
        didSet { puckIndicator?.isHidden = !hasPuck }
    }

    var isSelected: Bool = false {
        didSet { selectionRing?.isHidden = !isSelected }
    }

    var targetPosition: CGPoint?
    var currentSpeed: CGFloat = 0
    var maxSpeed: CGFloat {
        CGFloat(playerStats.speed) * 2.0 + 60
    }

    private var facingRight: Bool = true

    // MARK: - Init
    init(player: Player, teamColors: TeamColors, teamIndex: Int) {
        self.playerID = player.id
        self.posType = player.position
        self.teamIndex = teamIndex
        self.playerStats = player

        // Pre-load textures for both directions
        if player.position.isGoalie {
            let texRight = PixelArt.goalieTexture(teamColors: teamColors, direction: .right)
            let texLeft  = PixelArt.goalieTexture(teamColors: teamColors, direction: .left)
            goalieTextureRight = texRight
            goalieTextureLeft  = texLeft
            idleTextureRight = texRight
            idleTextureLeft  = texLeft
            sprite = SKSpriteNode(texture: teamIndex == 0 ? texRight : texLeft)
        } else {
            idleTextureRight = PixelArt.skaterTexture(teamColors: teamColors, direction: .right)
            idleTextureLeft  = PixelArt.skaterTexture(teamColors: teamColors, direction: .left)
            sprite = SKSpriteNode(texture: teamIndex == 0 ? idleTextureRight : idleTextureLeft)
        }

        // Shadow: dark semi-transparent ellipse underneath for depth
        shadowNode = SKShapeNode(ellipseOf: CGSize(width: 22, height: 10))
        shadowNode.fillColor = UIColor.black.withAlphaComponent(0.25)
        shadowNode.strokeColor = .clear

        // Jersey number
        numberLabel = RetroFont.label(
            "\(player.jerseyNumber)",
            size: RetroFont.tinySize,
            color: .white
        )

        super.init()

        // Set initial facing direction
        facingRight = (teamIndex == 0)

        // Shadow
        shadowNode.position = CGPoint(x: 0, y: -sprite.size.height / 2 + 2)
        shadowNode.zPosition = ZPos.shadow
        addChild(shadowNode)

        // Sprite
        sprite.zPosition = ZPos.skater
        sprite.setScale(player.position.isGoalie ? 1.0 : 0.9)
        addChild(sprite)

        // Number label
        numberLabel.position = CGPoint(x: 0, y: -sprite.size.height / 2 - 8)
        numberLabel.zPosition = ZPos.skater + 1
        addChild(numberLabel)

        // Selection ring
        let ring = SKShapeNode(circleOfRadius: GameConfig.skaterRadius + 4)
        ring.strokeColor = RetroPalette.gold
        ring.lineWidth = 2
        ring.fillColor = .clear
        ring.glowWidth = 2
        ring.zPosition = ZPos.skater - 0.5
        ring.isHidden = true
        ring.isAntialiased = false
        addChild(ring)
        selectionRing = ring

        // Puck possession indicator (small white dot)
        let puckDot = SKShapeNode(circleOfRadius: 3)
        puckDot.fillColor = .white
        puckDot.strokeColor = .clear
        puckDot.zPosition = ZPos.skater + 0.5
        puckDot.position = CGPoint(x: teamIndex == 0 ? 12 : -12, y: -4)
        puckDot.isHidden = true
        addChild(puckDot)
        puckIndicator = puckDot

        // Physics body
        let body = SKPhysicsBody(circleOfRadius: GameConfig.skaterRadius)
        body.categoryBitMask = PhysicsCategory.skater
        body.contactTestBitMask = PhysicsCategory.puck | PhysicsCategory.skater
        body.collisionBitMask = PhysicsCategory.boards | PhysicsCategory.skater
        body.linearDamping = 3.0
        body.angularDamping = 5.0
        body.mass = 0.5
        body.allowsRotation = false
        self.physicsBody = body
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Movement
    func moveToward(_ target: CGPoint, speed moveSpeed: CGFloat? = nil) {
        let spd = moveSpeed ?? maxSpeed
        let dx = target.x - self.position.x
        let dy = target.y - self.position.y
        let dist = hypot(dx, dy)
        guard dist > 2 else { return }

        let nx = dx / dist
        let ny = dy / dist

        physicsBody?.velocity = CGVector(dx: nx * spd, dy: ny * spd)
        currentSpeed = spd

        // Update facing direction
        updateDirection(dx: dx)

        // Trigger skating animation if not already in it
        if animState != .skating && animState != .shooting && animState != .deking {
            setAnimState(.skating)
        }
    }

    func stopMoving() {
        physicsBody?.velocity = .zero
        currentSpeed = 0
        targetPosition = nil
        if animState == .skating {
            setAnimState(.idle)
        }
    }

    func deke(direction angle: CGFloat) {
        // Lateral impulse based on angle
        let impulseStrength: CGFloat = 80
        let dx = cos(angle) * impulseStrength
        let dy = sin(angle) * impulseStrength
        physicsBody?.applyImpulse(CGVector(dx: dx, dy: dy))

        setAnimState(.deking)

        // Return to skating after deke animation completes
        let dekeDuration: TimeInterval = 0.35
        run(SKAction.wait(forDuration: dekeDuration)) { [weak self] in
            guard let self = self else { return }
            if self.animState == .deking {
                self.setAnimState(.skating)
            }
        }
    }

    // MARK: - Animation State Machine
    func setAnimState(_ state: AnimState) {
        guard state != animState else { return }
        animState = state

        // Remove any current animation
        sprite.removeAction(forKey: "anim")

        switch state {
        case .idle:
            sprite.texture = facingRight ? idleTextureRight : idleTextureLeft

        case .skating:
            // Subtle bob animation to simulate skating stride
            let bob = SKAction.sequence([
                SKAction.moveBy(x: 0, y: 1.5, duration: 0.12),
                SKAction.moveBy(x: 0, y: -1.5, duration: 0.12),
            ])
            sprite.run(SKAction.repeatForever(bob), withKey: "anim")

        case .shooting:
            // Wind-up and strike rotation
            let windUp  = SKAction.rotate(byAngle: -0.3, duration: 0.1)
            let strike  = SKAction.rotate(byAngle: 0.5, duration: 0.05)
            let recover = SKAction.rotate(toAngle: 0, duration: 0.15)
            sprite.run(SKAction.sequence([windUp, strike, recover]), withKey: "anim")

        case .celebrating:
            // Jump + flash
            let jump = SKAction.sequence([
                SKAction.moveBy(x: 0, y: 8, duration: 0.15),
                SKAction.moveBy(x: 0, y: -8, duration: 0.15),
            ])
            let flash = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.5, duration: 0.1),
                SKAction.fadeAlpha(to: 1.0, duration: 0.1),
            ])
            let celebrate = SKAction.group([
                SKAction.repeat(jump, count: 3),
                SKAction.repeat(flash, count: 4),
            ])
            sprite.run(celebrate, withKey: "anim")

        case .deking:
            // Quick lateral sway
            let sway = SKAction.sequence([
                SKAction.moveBy(x: facingRight ? -4 : 4, y: 0, duration: 0.08),
                SKAction.moveBy(x: facingRight ? 8 : -8, y: 0, duration: 0.12),
                SKAction.moveBy(x: facingRight ? -4 : 4, y: 0, duration: 0.08),
            ])
            sprite.run(sway, withKey: "anim")

        case .hit:
            // Shake on hit, then return to idle
            let shake = SKAction.sequence([
                SKAction.moveBy(x: -3, y: 0, duration: 0.05),
                SKAction.moveBy(x: 6, y: 0, duration: 0.05),
                SKAction.moveBy(x: -3, y: 0, duration: 0.05),
                SKAction.run { [weak self] in
                    if self?.animState == .hit {
                        self?.animState = .idle
                    }
                },
            ])
            sprite.run(shake, withKey: "anim")
        }
    }

    // MARK: - Convenience Animation Methods
    func playShootAnimation() {
        setAnimState(.shooting)
    }

    func playCelebration() {
        setAnimState(.celebrating)
    }

    func playHitAnimation() {
        setAnimState(.hit)
    }

    // MARK: - Pass Target Indicator
    func showPassTarget() {
        guard childNode(withName: "passTarget") == nil else { return }

        let targetNode = SKNode()
        targetNode.name = "passTarget"
        targetNode.zPosition = ZPos.effects

        // Pulsing green circle around the skater (highly visible)
        let ring = SKShapeNode(circleOfRadius: GameConfig.skaterRadius + 10)
        ring.strokeColor = RetroPalette.textGreen
        ring.lineWidth = 2.5
        ring.fillColor = RetroPalette.textGreen.withAlphaComponent(0.12)
        ring.glowWidth = 3
        ring.isAntialiased = false
        ring.name = "passRing"
        targetNode.addChild(ring)

        // Pulsing animation
        let pulseOut = SKAction.group([
            SKAction.scale(to: 1.2, duration: 0.5),
            SKAction.fadeAlpha(to: 0.5, duration: 0.5),
        ])
        let pulseIn = SKAction.group([
            SKAction.scale(to: 0.9, duration: 0.5),
            SKAction.fadeAlpha(to: 1.0, duration: 0.5),
        ])
        ring.run(SKAction.repeatForever(SKAction.sequence([pulseOut, pulseIn])))

        // Down-pointing arrow above the skater
        let arrow = SKSpriteNode(texture: PixelArt.arrowTexture(color: RetroPalette.textGreen))
        arrow.position = CGPoint(x: 0, y: sprite.size.height / 2 + 14)
        arrow.setScale(1.3)
        targetNode.addChild(arrow)

        let bounce = SKAction.sequence([
            SKAction.moveBy(x: 0, y: -5, duration: 0.3),
            SKAction.moveBy(x: 0, y: 5, duration: 0.3),
        ])
        arrow.run(SKAction.repeatForever(bounce))

        addChild(targetNode)
    }

    func hidePassTarget() {
        childNode(withName: "passTarget")?.removeFromParent()
    }

    // MARK: - Direction
    private func updateDirection(dx: CGFloat) {
        if dx > 5 {
            facingRight = true
            sprite.texture = posType.isGoalie ? goalieTextureRight : idleTextureRight
            sprite.xScale = abs(sprite.xScale)
        } else if dx < -5 {
            facingRight = false
            sprite.texture = posType.isGoalie ? goalieTextureLeft : idleTextureLeft
            sprite.xScale = abs(sprite.xScale)
        }
    }
}
