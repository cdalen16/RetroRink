import SpriteKit

// MARK: - Hockey Rink Node (Top-Down View, 1200x600)
class RinkNode: SKNode {

    let rinkWidth: CGFloat
    let rinkHeight: CGFloat
    let cornerRadius: CGFloat = 40

    // MARK: - Key Positions (relative to rink center at 0,0)
    var leftGoalCenter: CGPoint { CGPoint(x: -rinkWidth / 2 + GameConfig.goalDepth / 2, y: 0) }
    var rightGoalCenter: CGPoint { CGPoint(x: rinkWidth / 2 - GameConfig.goalDepth / 2, y: 0) }
    var centerIce: CGPoint { .zero }

    var leftGoalMouth: CGPoint { CGPoint(x: -rinkWidth / 2 + GameConfig.goalDepth + 12, y: 0) }
    var rightGoalMouth: CGPoint { CGPoint(x: rinkWidth / 2 - GameConfig.goalDepth - 12, y: 0) }

    // Faceoff dots: center + 4 zone dots
    var faceoffDots: [CGPoint] {
        let dx: CGFloat = rinkWidth * 0.3
        let dy: CGFloat = rinkHeight * 0.28
        return [
            centerIce,
            CGPoint(x: -dx, y:  dy), CGPoint(x: -dx, y: -dy),
            CGPoint(x:  dx, y:  dy), CGPoint(x:  dx, y: -dy),
        ]
    }

    // MARK: - Init
    init(width: CGFloat = GameConfig.rinkWidth, height: CGFloat = GameConfig.rinkHeight) {
        rinkWidth = width
        rinkHeight = height
        super.init()
        buildRink()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Build
    private func buildRink() {
        drawIceSurface()
        drawRinkLines()
        drawCenterCircle()
        drawFaceoffCircles()
        drawGoalLines()
        drawGoals()
        drawCreases()
        drawBoards()
        setupPhysicsBoundary()
    }

    // MARK: - Ice Surface (tiled 64x64 tiles)
    private func drawIceSurface() {
        let tileSize: CGFloat = 64
        let tilesX = Int(ceil(rinkWidth / tileSize))
        let tilesY = Int(ceil(rinkHeight / tileSize))
        let startX = -rinkWidth / 2 + tileSize / 2
        let startY = -rinkHeight / 2 + tileSize / 2

        // Generate one ice tile texture and reuse it
        let tileTex = PixelArt.iceTexture(width: tileSize, height: tileSize)

        for row in 0..<tilesY {
            for col in 0..<tilesX {
                let tile = SKSpriteNode(texture: tileTex, size: CGSize(width: tileSize, height: tileSize))
                tile.position = CGPoint(
                    x: startX + CGFloat(col) * tileSize,
                    y: startY + CGFloat(row) * tileSize
                )
                tile.zPosition = ZPos.ice
                addChild(tile)
            }
        }
    }

    // MARK: - Lines
    private func drawRinkLines() {
        // Center red line (4pt wide)
        let centerLine = SKSpriteNode(
            color: RetroPalette.redLine,
            size: CGSize(width: 4, height: rinkHeight - 20)
        )
        centerLine.zPosition = ZPos.rinkLines
        centerLine.alpha = 0.7
        addChild(centerLine)

        // Blue lines at +/- rinkWidth * 0.22 (6pt wide)
        let blueLineX = rinkWidth * 0.22
        for x in [-blueLineX, blueLineX] {
            let blueLine = SKSpriteNode(
                color: RetroPalette.blueLine,
                size: CGSize(width: 6, height: rinkHeight - 20)
            )
            blueLine.position = CGPoint(x: x, y: 0)
            blueLine.zPosition = ZPos.rinkLines
            blueLine.alpha = 0.7
            addChild(blueLine)
        }
    }

    // MARK: - Center Circle & Dot
    private func drawCenterCircle() {
        // Center circle: blue, radius 50, 3pt line width
        let centerCircle = SKShapeNode(circleOfRadius: 50)
        centerCircle.strokeColor = RetroPalette.blueLine.withAlphaComponent(0.6)
        centerCircle.lineWidth = 3
        centerCircle.fillColor = .clear
        centerCircle.zPosition = ZPos.rinkLines
        centerCircle.isAntialiased = false
        addChild(centerCircle)

        // Center dot: blue, radius 6
        let centerDot = SKShapeNode(circleOfRadius: 6)
        centerDot.fillColor = RetroPalette.blueLine
        centerDot.strokeColor = .clear
        centerDot.zPosition = ZPos.rinkLines
        addChild(centerDot)
    }

    // MARK: - Faceoff Circles (4 zone circles)
    private func drawFaceoffCircles() {
        let dx: CGFloat = rinkWidth * 0.3
        let dy: CGFloat = rinkHeight * 0.28
        let positions = [
            CGPoint(x: -dx, y:  dy),
            CGPoint(x: -dx, y: -dy),
            CGPoint(x:  dx, y:  dy),
            CGPoint(x:  dx, y: -dy),
        ]

        for pos in positions {
            // Red circle, radius 36
            let circle = SKShapeNode(circleOfRadius: 36)
            circle.strokeColor = RetroPalette.redLine.withAlphaComponent(0.5)
            circle.lineWidth = 2
            circle.fillColor = .clear
            circle.position = pos
            circle.zPosition = ZPos.rinkLines
            circle.isAntialiased = false
            addChild(circle)

            // Red center dot, radius 4
            let dot = SKShapeNode(circleOfRadius: 4)
            dot.fillColor = RetroPalette.redLine
            dot.strokeColor = .clear
            dot.position = pos
            dot.zPosition = ZPos.rinkLines
            addChild(dot)

            // Hash marks: 4 short lines around each circle
            let hashLength: CGFloat = 8
            let hashOffset: CGFloat = 38 // just outside the circle
            let hashPositions: [(CGFloat, CGFloat, Bool)] = [
                ( hashOffset,  10, true),   // right-top (vertical)
                ( hashOffset, -10, true),   // right-bottom (vertical)
                (-hashOffset,  10, true),   // left-top (vertical)
                (-hashOffset, -10, true),   // left-bottom (vertical)
            ]
            for (hx, hy, vertical) in hashPositions {
                let hashSize: CGSize = vertical
                    ? CGSize(width: 2, height: hashLength)
                    : CGSize(width: hashLength, height: 2)
                let hash = SKSpriteNode(color: RetroPalette.redLine.withAlphaComponent(0.5), size: hashSize)
                hash.position = CGPoint(x: pos.x + hx, y: pos.y + hy)
                hash.zPosition = ZPos.rinkLines
                addChild(hash)
            }
        }
    }

    // MARK: - Goal Lines
    private func drawGoalLines() {
        // Goal lines at +/- (rinkWidth/2 - 40), red, 4pt wide
        let goalLineXOffset = rinkWidth / 2 - 40
        for x in [-goalLineXOffset, goalLineXOffset] {
            let goalLine = SKSpriteNode(
                color: RetroPalette.redLine.withAlphaComponent(0.6),
                size: CGSize(width: 4, height: rinkHeight - 40)
            )
            goalLine.position = CGPoint(x: x, y: 0)
            goalLine.zPosition = ZPos.rinkLines
            addChild(goalLine)
        }
    }

    // MARK: - Goals
    private func drawGoals() {
        // Left goal: at -(rinkWidth/2 - goalDepth/2), net texture is goalDepth x goalWidth (30x60)
        drawGoal(
            at: CGPoint(x: -rinkWidth / 2 + GameConfig.goalDepth / 2, y: 0),
            facingRight: true,
            name: "leftGoal"
        )
        // Right goal: at +(rinkWidth/2 - goalDepth/2)
        drawGoal(
            at: CGPoint(x: rinkWidth / 2 - GameConfig.goalDepth / 2, y: 0),
            facingRight: false,
            name: "rightGoal"
        )
    }

    private func drawGoal(at pos: CGPoint, facingRight: Bool, name: String) {
        let goalWidth = GameConfig.goalWidth
        let goalDepth = GameConfig.goalDepth

        // Visual net sprite
        let goalNode = SKSpriteNode(
            texture: PixelArt.goalNetTexture(),
            size: CGSize(width: goalDepth, height: goalWidth)
        )
        goalNode.position = pos
        goalNode.zPosition = ZPos.rinkLines + 0.5
        if !facingRight {
            goalNode.xScale = -1
        }
        addChild(goalNode)

        // Goal physics trigger zone (slightly inside the net)
        let triggerNode = SKNode()
        triggerNode.position = CGPoint(
            x: pos.x + (facingRight ? goalDepth * 0.3 : -goalDepth * 0.3),
            y: pos.y
        )
        triggerNode.physicsBody = SKPhysicsBody(
            rectangleOf: CGSize(width: goalDepth * 0.5, height: goalWidth * 0.8)
        )
        triggerNode.physicsBody?.isDynamic = false
        triggerNode.physicsBody?.categoryBitMask = PhysicsCategory.goal
        triggerNode.physicsBody?.contactTestBitMask = PhysicsCategory.puck
        triggerNode.physicsBody?.collisionBitMask = PhysicsCategory.none
        triggerNode.name = name
        addChild(triggerNode)
    }

    // MARK: - Creases (blue semi-transparent semi-circle)
    private func drawCreases() {
        // Left crease in front of left goal
        let leftCreaseX = -rinkWidth / 2 + GameConfig.goalDepth + 12
        drawCrease(at: CGPoint(x: leftCreaseX, y: 0), openingToRight: true)

        // Right crease in front of right goal
        let rightCreaseX = rinkWidth / 2 - GameConfig.goalDepth - 12
        drawCrease(at: CGPoint(x: rightCreaseX, y: 0), openingToRight: false)
    }

    private func drawCrease(at pos: CGPoint, openingToRight: Bool) {
        let radius = GameConfig.creaseRadius

        // Semi-circle crease
        let path = UIBezierPath()
        if openingToRight {
            // Semi-circle opening to the right (from goal mouth)
            path.addArc(
                withCenter: .zero,
                radius: radius,
                startAngle: -.pi / 2,
                endAngle: .pi / 2,
                clockwise: true
            )
            path.close()
        } else {
            // Semi-circle opening to the left
            path.addArc(
                withCenter: .zero,
                radius: radius,
                startAngle: .pi / 2,
                endAngle: -.pi / 2,
                clockwise: true
            )
            path.close()
        }

        let crease = SKShapeNode(path: path.cgPath)
        crease.fillColor = UIColor(hex: "AACCFF").withAlphaComponent(0.25)
        crease.strokeColor = RetroPalette.blueLine.withAlphaComponent(0.4)
        crease.lineWidth = 2
        crease.position = pos
        crease.zPosition = ZPos.rinkLines
        crease.isAntialiased = false
        addChild(crease)

        // Crease physics body (for goalie interference detection)
        let creaseBody = SKNode()
        creaseBody.position = pos
        creaseBody.physicsBody = SKPhysicsBody(circleOfRadius: radius)
        creaseBody.physicsBody?.isDynamic = false
        creaseBody.physicsBody?.categoryBitMask = PhysicsCategory.goalCrease
        creaseBody.physicsBody?.contactTestBitMask = PhysicsCategory.skater
        creaseBody.physicsBody?.collisionBitMask = PhysicsCategory.none
        creaseBody.name = openingToRight ? "leftCrease" : "rightCrease"
        addChild(creaseBody)
    }

    // MARK: - Boards (white dasher boards with yellow kickplate, rounded corners)
    private func drawBoards() {
        let boardThickness: CGFloat = kPixelSize * 2  // 6pt
        let hw = rinkWidth / 2
        let hh = rinkHeight / 2
        let boardColor = RetroPalette.boardsWhite
        let kickplateColor = UIColor(hex: "DDAA22")

        // Top board
        let topBoard = SKSpriteNode(
            color: boardColor,
            size: CGSize(width: rinkWidth - cornerRadius * 2, height: boardThickness)
        )
        topBoard.position = CGPoint(x: 0, y: hh)
        topBoard.zPosition = ZPos.rinkLines + 1
        addChild(topBoard)

        let topKick = SKSpriteNode(
            color: kickplateColor,
            size: CGSize(width: rinkWidth - cornerRadius * 2, height: boardThickness * 0.5)
        )
        topKick.position = CGPoint(x: 0, y: hh - boardThickness * 0.5)
        topKick.zPosition = ZPos.rinkLines + 1
        addChild(topKick)

        // Bottom board
        let bottomBoard = SKSpriteNode(
            color: boardColor,
            size: CGSize(width: rinkWidth - cornerRadius * 2, height: boardThickness)
        )
        bottomBoard.position = CGPoint(x: 0, y: -hh)
        bottomBoard.zPosition = ZPos.rinkLines + 1
        addChild(bottomBoard)

        let bottomKick = SKSpriteNode(
            color: kickplateColor,
            size: CGSize(width: rinkWidth - cornerRadius * 2, height: boardThickness * 0.5)
        )
        bottomKick.position = CGPoint(x: 0, y: -hh + boardThickness * 0.5)
        bottomKick.zPosition = ZPos.rinkLines + 1
        addChild(bottomKick)

        // Left board
        let leftBoard = SKSpriteNode(
            color: boardColor,
            size: CGSize(width: boardThickness, height: rinkHeight - cornerRadius * 2)
        )
        leftBoard.position = CGPoint(x: -hw, y: 0)
        leftBoard.zPosition = ZPos.rinkLines + 1
        addChild(leftBoard)

        // Right board
        let rightBoard = SKSpriteNode(
            color: boardColor,
            size: CGSize(width: boardThickness, height: rinkHeight - cornerRadius * 2)
        )
        rightBoard.position = CGPoint(x: hw, y: 0)
        rightBoard.zPosition = ZPos.rinkLines + 1
        addChild(rightBoard)

        // Corner arcs (white board arcs at each corner)
        let corners: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (-hw + cornerRadius,  hh - cornerRadius, .pi / 2,     .pi),         // top-left
            ( hw - cornerRadius,  hh - cornerRadius, 0,           .pi / 2),      // top-right
            (-hw + cornerRadius, -hh + cornerRadius, .pi,         .pi * 1.5),    // bottom-left
            ( hw - cornerRadius, -hh + cornerRadius, .pi * 1.5,   .pi * 2),      // bottom-right
        ]

        for (cx, cy, start, end) in corners {
            let arc = SKShapeNode()
            let path = UIBezierPath(
                arcCenter: CGPoint(x: cx, y: cy),
                radius: cornerRadius,
                startAngle: start,
                endAngle: end,
                clockwise: true
            )
            arc.path = path.cgPath
            arc.strokeColor = boardColor
            arc.lineWidth = boardThickness
            arc.fillColor = .clear
            arc.zPosition = ZPos.rinkLines + 1
            arc.isAntialiased = false
            addChild(arc)

            // Kickplate inner arc
            let kickArc = SKShapeNode()
            let kickPath = UIBezierPath(
                arcCenter: CGPoint(x: cx, y: cy),
                radius: cornerRadius - boardThickness * 0.5,
                startAngle: start,
                endAngle: end,
                clockwise: true
            )
            kickArc.path = kickPath.cgPath
            kickArc.strokeColor = kickplateColor
            kickArc.lineWidth = boardThickness * 0.5
            kickArc.fillColor = .clear
            kickArc.zPosition = ZPos.rinkLines + 1.1
            kickArc.isAntialiased = false
            addChild(kickArc)
        }
    }

    // MARK: - Physics Boundary (rounded rectangle edge loop, inset from visual boards)
    private func setupPhysicsBoundary() {
        let inset: CGFloat = 8
        let hw = rinkWidth / 2 - inset
        let hh = rinkHeight / 2 - inset
        let cr = cornerRadius - inset / 2

        let path = UIBezierPath()
        path.move(to: CGPoint(x: -hw + cr, y: hh))
        path.addLine(to: CGPoint(x: hw - cr, y: hh))
        path.addArc(withCenter: CGPoint(x: hw - cr, y: hh - cr),
                     radius: cr, startAngle: .pi / 2, endAngle: 0, clockwise: false)
        path.addLine(to: CGPoint(x: hw, y: -hh + cr))
        path.addArc(withCenter: CGPoint(x: hw - cr, y: -hh + cr),
                     radius: cr, startAngle: 0, endAngle: -.pi / 2, clockwise: false)
        path.addLine(to: CGPoint(x: -hw + cr, y: -hh))
        path.addArc(withCenter: CGPoint(x: -hw + cr, y: -hh + cr),
                     radius: cr, startAngle: -.pi / 2, endAngle: .pi, clockwise: false)
        path.addLine(to: CGPoint(x: -hw, y: hh - cr))
        path.addArc(withCenter: CGPoint(x: -hw + cr, y: hh - cr),
                     radius: cr, startAngle: .pi, endAngle: .pi / 2, clockwise: false)
        path.close()

        let boundary = SKPhysicsBody(edgeLoopFrom: path.cgPath)
        boundary.categoryBitMask = PhysicsCategory.boards
        boundary.restitution = 0.6
        boundary.friction = 0.3
        self.physicsBody = boundary
    }

    // MARK: - Zone Helpers
    func offensiveZoneRight() -> CGRect {
        let blueLineX = rinkWidth * 0.22
        return CGRect(
            x: blueLineX,
            y: -rinkHeight / 2,
            width: rinkWidth / 2 - blueLineX,
            height: rinkHeight
        )
    }

    func offensiveZoneLeft() -> CGRect {
        let blueLineX = rinkWidth * 0.22
        return CGRect(
            x: -rinkWidth / 2,
            y: -rinkHeight / 2,
            width: rinkWidth / 2 - blueLineX,
            height: rinkHeight
        )
    }
}
