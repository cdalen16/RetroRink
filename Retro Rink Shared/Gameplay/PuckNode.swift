import SpriteKit

// MARK: - Puck Node with Fading Dot Trail
class PuckNode: SKNode {

    let sprite: SKSpriteNode

    // Trail: 8 fading dot nodes instead of SKEmitterNode
    private var trailDots: [SKShapeNode] = []
    private var trailPositions: [CGPoint] = []
    private let trailCount = 8

    // Carrier state
    var carriedBy: SkaterNode?
    var isLoose: Bool { carriedBy == nil }

    // Shot tracking (for physics-based resolution in update loop)
    var hasBeenShot: Bool = false
    var timeSinceShot: TimeInterval = 0
    private var shotPower: CGFloat = 0

    // Pass tracking (for proximity-based arrival in update loop)
    var isPass: Bool = false
    var passTargetID: UUID?
    var timeSincePass: TimeInterval = 0
    private let passArrivalRadius: CGFloat = 20
    private let passTimeout: TimeInterval = 2.0
    private let normalDamping: CGFloat = 1.5
    private let passDamping: CGFloat = 0.3

    // MARK: - Init
    override init() {
        sprite = SKSpriteNode(texture: PixelArt.puckTexture())
        super.init()

        sprite.zPosition = ZPos.puck
        addChild(sprite)

        // Physics body
        let body = SKPhysicsBody(circleOfRadius: GameConfig.puckRadius)
        body.categoryBitMask = PhysicsCategory.puck
        body.contactTestBitMask = PhysicsCategory.goal | PhysicsCategory.skater | PhysicsCategory.boards
        body.collisionBitMask = PhysicsCategory.boards | PhysicsCategory.skater
        body.linearDamping = 1.5
        body.angularDamping = 2.0
        body.mass = 0.05
        body.restitution = 0.7
        body.friction = 0.2
        body.allowsRotation = true
        body.usesPreciseCollisionDetection = true  // prevents fast puck from tunneling through goalie
        self.physicsBody = body

        setupTrailDots()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Trail Setup (fading dot array)
    private func setupTrailDots() {
        for i in 0..<trailCount {
            let dot = SKShapeNode(circleOfRadius: 2)
            dot.fillColor = .white
            dot.strokeColor = .clear
            dot.alpha = CGFloat(trailCount - i) / CGFloat(trailCount) * 0.4
            dot.zPosition = ZPos.puck - 0.5
            dot.isHidden = true
            addChild(dot)
            trailDots.append(dot)
            trailPositions.append(.zero)
        }
    }

    // MARK: - Carrier Management
    func attachTo(_ skater: SkaterNode) {
        // Restore previous carrier's puck collision
        if let prev = carriedBy {
            prev.physicsBody?.collisionBitMask |= PhysicsCategory.puck
        }
        carriedBy = skater
        skater.hasPuck = true
        // Disable puck collision for the carrier so they can move freely
        skater.physicsBody?.collisionBitMask &= ~PhysicsCategory.puck
        physicsBody?.velocity = .zero
        physicsBody?.isDynamic = false
        hasBeenShot = false
        timeSinceShot = 0
        shotPower = 0
        clearPassState()

        // Hide trail when carried
        for dot in trailDots { dot.isHidden = true }
    }

    func detach() {
        // Restore carrier's puck collision
        carriedBy?.physicsBody?.collisionBitMask |= PhysicsCategory.puck
        carriedBy?.hasPuck = false
        carriedBy = nil
        physicsBody?.isDynamic = true
    }

    // MARK: - Position Update (called each frame)
    func updatePosition() {
        guard let carrier = carriedBy else { return }

        // Position puck at the stick blade location (front-bottom of the side-angle sprite)
        // The stick blade extends forward (in facing direction) and slightly below center
        let directionMultiplier: CGFloat
        if abs(carrier.physicsBody?.velocity.dx ?? 0) > 10 {
            directionMultiplier = (carrier.physicsBody?.velocity.dx ?? 0) >= 0 ? 1 : -1
        } else {
            directionMultiplier = carrier.teamIndex == 0 ? 1 : -1
        }
        // Stick blade is ~10px forward and ~6px below center of the sprite
        let offsetX = directionMultiplier * 10
        let offsetY: CGFloat = -6
        self.position = CGPoint(x: carrier.position.x + offsetX, y: carrier.position.y + offsetY)
    }

    // MARK: - Trail Update (for loose/shot puck)
    func updateTrail() {
        guard isLoose else { return }

        let vel = physicsBody?.velocity ?? .zero
        let speed = hypot(vel.dx, vel.dy)

        if speed > 30 {
            let worldPos = self.position

            // Shift positions down the array
            for i in stride(from: trailCount - 1, through: 1, by: -1) {
                trailPositions[i] = trailPositions[i - 1]
            }
            // Store current world position at the head
            trailPositions[0] = worldPos

            // Update dot positions and visibility
            // Trail dots are children of this node (which is at worldPos),
            // so we convert past world positions to local coords by subtracting current worldPos.
            for i in 0..<trailCount {
                if i == 0 {
                    trailDots[i].isHidden = true
                    continue
                }
                if trailPositions[i] == .zero {
                    trailDots[i].isHidden = true
                } else {
                    trailDots[i].isHidden = false
                    trailDots[i].position = CGPoint(
                        x: trailPositions[i].x - worldPos.x,
                        y: trailPositions[i].y - worldPos.y
                    )
                    trailDots[i].alpha = CGFloat(trailCount - i) / CGFloat(trailCount) * 0.35
                }
            }
        } else {
            // Too slow, hide trail
            for dot in trailDots { dot.isHidden = true }
        }
    }

    // MARK: - Shooting
    func shoot(toward target: CGPoint, power: CGFloat) {
        let carrier = carriedBy
        detach()

        let dx = target.x - position.x
        let dy = target.y - position.y
        let dist = hypot(dx, dy)
        guard dist > 0 else { return }

        let speed = min(power, GameConfig.shotSpeedMax)
        let vx = (dx / dist) * speed
        let vy = (dy / dist) * speed

        physicsBody?.velocity = CGVector(dx: vx, dy: vy)

        // Mark as shot for update()-based resolution
        hasBeenShot = true
        timeSinceShot = 0
        shotPower = power

        carrier?.playShootAnimation()

        // Puck flash effect
        let flash = SKAction.sequence([
            SKAction.scale(to: 1.5, duration: 0.05),
            SKAction.scale(to: 1.0, duration: 0.1),
        ])
        sprite.run(flash)

        // Reset trail positions for fresh trail
        for i in 0..<trailCount { trailPositions[i] = self.position }
    }

    func pass(toward target: CGPoint, targetID: UUID) {
        detach()

        let dx = target.x - position.x
        let dy = target.y - position.y
        let dist = hypot(dx, dy)
        guard dist > 0 else { return }

        let speed = GameConfig.passSpeed
        let vx = (dx / dist) * speed
        let vy = (dy / dist) * speed

        physicsBody?.velocity = CGVector(dx: vx, dy: vy)

        // Reduce damping so puck actually travels visibly
        physicsBody?.linearDamping = passDamping

        // Mark as pass for proximity-based arrival in update()
        isPass = true
        passTargetID = targetID
        timeSincePass = 0
        hasBeenShot = false

        // Reset trail positions
        for i in 0..<trailCount { trailPositions[i] = self.position }
    }

    /// Check if the puck has arrived at the pass target. Returns the target skater if arrived.
    func checkPassArrival(skaters: [SkaterNode]) -> SkaterNode? {
        guard isPass, let targetID = passTargetID else { return nil }

        // Find target skater
        guard let target = skaters.first(where: { $0.playerID == targetID }) else {
            clearPassState()
            return nil
        }

        let dist = position.distance(to: target.position)
        if dist <= passArrivalRadius {
            clearPassState()
            return target
        }

        // Timeout — treat as loose puck
        if timeSincePass >= passTimeout {
            clearPassState()
            return nil
        }

        return nil
    }

    func clearPassState() {
        isPass = false
        passTargetID = nil
        timeSincePass = 0
        physicsBody?.linearDamping = normalDamping
    }

    // MARK: - Goal Effect
    func goalEffect() {
        let flash = SKSpriteNode(color: .white, size: CGSize(width: 60, height: 60))
        flash.position = .zero  // relative to puck's current parent
        flash.zPosition = ZPos.effects
        flash.alpha = 0.8
        parent?.addChild(flash)
        flash.position = self.position

        let expand = SKAction.scale(to: 3.0, duration: 0.3)
        let fade = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()
        flash.run(SKAction.sequence([SKAction.group([expand, fade]), remove]))
    }

    // MARK: - Reset
    func resetToCenter() {
        detach()
        clearPassState()
        position = .zero
        physicsBody?.velocity = .zero
        hasBeenShot = false
        timeSinceShot = 0
        shotPower = 0
        for dot in trailDots { dot.isHidden = true }
        for i in 0..<trailCount { trailPositions[i] = .zero }
    }

    // MARK: - Frame Update
    func update(dt: TimeInterval) {
        if hasBeenShot {
            timeSinceShot += dt
        }
        if isPass {
            timeSincePass += dt
        }
        if isLoose {
            updateTrail()
        }
    }
}
