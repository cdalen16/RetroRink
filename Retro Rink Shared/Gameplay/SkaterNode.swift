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

    // MARK: - Pre-loaded Textures (left + right variants for direction)
    private var idleTextureRight: SKTexture!
    private var idleTextureLeft: SKTexture!
    // Skating animation frames
    private var skatingFramesRight: [SKTexture]?
    private var skatingFramesLeft: [SKTexture]?
    // Goalie textures
    private var goalieTextureRight: SKTexture?
    private var goalieTextureLeft: SKTexture?
    // Team colors (for on-demand frame generation)
    private let teamColorData: TeamColors

    // MARK: - State
    var hasPuck: Bool = false

    var isSelected: Bool = false {
        didSet { selectionRing?.isHidden = !isSelected }
    }

    var targetPosition: CGPoint?
    var currentSpeed: CGFloat = 0
    var isCharging: Bool = false   // body check charge in progress
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
        self.teamColorData = teamColors

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
            // Pre-load skating animation frames
            skatingFramesRight = PixelArt.skaterFrames(teamColors: teamColors, state: .skating, direction: .right)
            skatingFramesLeft  = PixelArt.skaterFrames(teamColors: teamColors, state: .skating, direction: .left)
        }

        // Shadow: dark semi-transparent ellipse underneath for depth
        shadowNode = SKShapeNode(ellipseOf: CGSize(width: 20, height: 8))
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
        sprite.setScale(player.position.isGoalie ? 0.65 : 0.55)
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

        // Physics body — goalies get a wider body and collide with puck to block shots
        let bodyRadius = player.position.isGoalie ? GameConfig.skaterRadius * 1.5 : GameConfig.skaterRadius
        let body = SKPhysicsBody(circleOfRadius: bodyRadius)
        body.categoryBitMask = PhysicsCategory.skater
        body.contactTestBitMask = PhysicsCategory.puck | PhysicsCategory.skater
        body.collisionBitMask = PhysicsCategory.boards | PhysicsCategory.skater | PhysicsCategory.puck
        body.linearDamping = 3.0
        body.angularDamping = 5.0
        body.mass = player.position.isGoalie ? 2.0 : 0.5
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

        // Remove any current animation and reset sprite transform
        sprite.removeAction(forKey: "anim")
        sprite.zRotation = 0
        sprite.position = .zero

        switch state {
        case .idle:
            sprite.texture = facingRight ? idleTextureRight : idleTextureLeft

        case .skating:
            // Texture-swapped skating animation with leg stride frames
            let frames = facingRight ? skatingFramesRight : skatingFramesLeft
            if let frames = frames, !frames.isEmpty {
                let animate = SKAction.animate(with: frames, timePerFrame: AnimationConfig.skateFrameDuration)
                sprite.run(SKAction.repeatForever(animate), withKey: "anim")
            } else {
                // Fallback bob for goalies (no skating frames)
                let bob = SKAction.sequence([
                    SKAction.moveBy(x: 0, y: 1.5, duration: 0.12),
                    SKAction.moveBy(x: 0, y: -1.5, duration: 0.12),
                ])
                sprite.run(SKAction.repeatForever(bob), withKey: "anim")
            }

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
            guard !facingRight else { return }
            facingRight = true
            if posType.isGoalie {
                sprite.texture = goalieTextureRight
            } else if animState == .skating, let frames = skatingFramesRight, !frames.isEmpty {
                // Swap to right-facing skating frames mid-animation
                sprite.removeAction(forKey: "anim")
                let animate = SKAction.animate(with: frames, timePerFrame: AnimationConfig.skateFrameDuration)
                sprite.run(SKAction.repeatForever(animate), withKey: "anim")
            } else {
                sprite.texture = idleTextureRight
            }
            sprite.xScale = abs(sprite.xScale)
        } else if dx < -5 {
            guard facingRight else { return }
            facingRight = false
            if posType.isGoalie {
                sprite.texture = goalieTextureLeft
            } else if animState == .skating, let frames = skatingFramesLeft, !frames.isEmpty {
                // Swap to left-facing skating frames mid-animation
                sprite.removeAction(forKey: "anim")
                let animate = SKAction.animate(with: frames, timePerFrame: AnimationConfig.skateFrameDuration)
                sprite.run(SKAction.repeatForever(animate), withKey: "anim")
            } else {
                sprite.texture = idleTextureLeft
            }
            sprite.xScale = abs(sprite.xScale)
        }
    }
}
