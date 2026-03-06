import SpriteKit

// MARK: - Z-Position Convention for UI Components
// All UI components follow: background at zPosition 0, content at zPosition 1+
// This prevents SpriteKit's undefined sibling render order from hiding text behind backgrounds.

// MARK: - Retro Font Helper
struct RetroFont {
    static let titleSize: CGFloat = 28
    static let headerSize: CGFloat = 20
    static let bodySize: CGFloat = 14
    static let smallSize: CGFloat = 11
    static let tinySize: CGFloat = 9

    static let fontName = "Courier-Bold"

    static func label(_ text: String, size: CGFloat = bodySize, color: UIColor = RetroPalette.textWhite) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: fontName)
        label.text = text
        label.fontSize = size
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.zPosition = 1  // Always above any sibling backgrounds
        return label
    }
}

// MARK: - Retro Button (with haptic feedback)
class RetroButton: SKNode {
    let background: SKSpriteNode
    let label: SKLabelNode
    var action: (() -> Void)?
    private var isPressed = false
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    init(text: String, width: CGFloat = 180, height: CGFloat = 44,
         color: UIColor = RetroPalette.midPanel, borderColor: UIColor = RetroPalette.accent,
         fontSize: CGFloat = RetroFont.bodySize) {

        let tex = PixelArt.buttonTexture(width: width, height: height, color: color, borderColor: borderColor)
        background = SKSpriteNode(texture: tex, size: CGSize(width: width, height: height))
        background.zPosition = 0

        label = RetroFont.label(text, size: fontSize)
        label.zPosition = 2  // Well above background

        super.init()

        isUserInteractionEnabled = true
        addChild(background)
        addChild(label)

        feedbackGenerator.prepare()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        isPressed = true
        feedbackGenerator.impactOccurred()
        run(SKAction.scale(to: 0.93, duration: 0.05))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isPressed else { return }
        isPressed = false

        let bounce = SKAction.sequence([
            SKAction.scale(to: 1.05, duration: 0.06),
            SKAction.scale(to: 1.0, duration: 0.08),
        ])
        run(bounce) {
            self.action?()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isPressed = false
        run(SKAction.scale(to: 1.0, duration: 0.05))
    }
}

// MARK: - Retro Panel
class RetroPanel: SKNode {
    let background: SKSpriteNode
    let titleLabel: SKLabelNode?

    init(width: CGFloat, height: CGFloat, title: String? = nil) {
        let tex = PixelArt.panelTexture(width: width, height: height)
        background = SKSpriteNode(texture: tex, size: CGSize(width: width, height: height))
        background.zPosition = 0

        if let title = title {
            titleLabel = RetroFont.label(title, size: RetroFont.headerSize, color: RetroPalette.gold)
            titleLabel?.position = CGPoint(x: 0, y: height / 2 - 20)
            titleLabel?.zPosition = 2
        } else {
            titleLabel = nil
        }

        super.init()

        addChild(background)
        if let tl = titleLabel { addChild(tl) }
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Retro Progress Bar
class RetroProgressBar: SKNode {
    private let bgNode: SKSpriteNode
    private let fillNode: SKSpriteNode
    private let barWidth: CGFloat
    private let barHeight: CGFloat

    var progress: CGFloat = 0 {
        didSet {
            let clamped = max(0, min(1, progress))
            fillNode.size.width = barWidth * clamped
            fillNode.position.x = -(barWidth - fillNode.size.width) / 2

            if clamped > 0.9 {
                fillNode.color = RetroPalette.textRed
            } else if clamped > 0.7 {
                fillNode.color = RetroPalette.textYellow
            } else {
                fillNode.color = RetroPalette.textGreen
            }
        }
    }

    init(width: CGFloat, height: CGFloat = 12) {
        barWidth = width
        barHeight = height

        bgNode = SKSpriteNode(color: UIColor(hex: "333333"), size: CGSize(width: width, height: height))
        bgNode.zPosition = 0
        fillNode = SKSpriteNode(color: RetroPalette.textGreen, size: CGSize(width: 0, height: height - 4))
        fillNode.zPosition = 1

        super.init()

        addChild(bgNode)
        addChild(fillNode)
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Star Rating Display
class StarRating: SKNode {
    init(rating: Int, maxRating: Int = 5) {
        super.init()

        let starSpacing: CGFloat = 16
        let totalWidth = CGFloat(maxRating) * starSpacing
        let startX = -totalWidth / 2 + starSpacing / 2

        for i in 0..<maxRating {
            let star = SKSpriteNode(texture: PixelArt.starTexture(filled: i < rating))
            star.position = CGPoint(x: startX + CGFloat(i) * starSpacing, y: 0)
            star.setScale(0.8)
            star.zPosition = 1
            addChild(star)
        }
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Retro Segmented Control
class RetroSegmentedControl: SKNode {
    private var buttons: [RetroButton] = []
    private(set) var selectedIndex: Int = 0
    var onSelectionChanged: ((Int) -> Void)?

    init(items: [String], width: CGFloat = 300, height: CGFloat = 32) {
        super.init()

        let buttonWidth = width / CGFloat(items.count)
        let startX = -width / 2 + buttonWidth / 2

        for (i, title) in items.enumerated() {
            let isSelected = i == 0
            let btn = RetroButton(
                text: title,
                width: buttonWidth - 4,
                height: height,
                color: isSelected ? RetroPalette.accent : UIColor(hex: "222233"),
                borderColor: isSelected ? RetroPalette.accent : UIColor(hex: "444466"),
                fontSize: RetroFont.smallSize
            )
            btn.position = CGPoint(x: startX + CGFloat(i) * buttonWidth, y: 0)
            let index = i
            btn.action = { [weak self] in
                self?.selectIndex(index)
            }
            addChild(btn)
            buttons.append(btn)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func selectIndex(_ index: Int) {
        guard index != selectedIndex, index < buttons.count else { return }
        selectedIndex = index

        for (i, btn) in buttons.enumerated() {
            let isSelected = i == index
            let color = isSelected ? RetroPalette.accent : UIColor(hex: "222233")
            let borderColor = isSelected ? RetroPalette.accent : UIColor(hex: "444466")
            let tex = PixelArt.buttonTexture(
                width: btn.background.size.width,
                height: btn.background.size.height,
                color: color,
                borderColor: borderColor
            )
            btn.background.texture = tex
            btn.label.fontColor = isSelected ? .white : RetroPalette.textGray
        }

        onSelectionChanged?(index)
    }
}

// MARK: - Retro List Row
class RetroListRow: SKNode {
    private let bg: SKSpriteNode
    private var leftLabel: SKLabelNode?
    private var rightLabel: SKLabelNode?
    let rowWidth: CGFloat
    let rowHeight: CGFloat

    init(width: CGFloat, height: CGFloat = 36) {
        rowWidth = width
        rowHeight = height
        bg = SKSpriteNode(color: UIColor(hex: "1A1A3E"), size: CGSize(width: width, height: height))
        bg.zPosition = 0

        super.init()

        addChild(bg)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setContent(left: String, right: String,
                    leftColor: UIColor = RetroPalette.textWhite,
                    rightColor: UIColor = RetroPalette.textGray) {
        leftLabel?.removeFromParent()
        rightLabel?.removeFromParent()

        let lbl = RetroFont.label(left, size: RetroFont.tinySize, color: leftColor)
        lbl.horizontalAlignmentMode = .left
        lbl.position = CGPoint(x: -rowWidth / 2 + 8, y: 0)
        lbl.zPosition = 2
        addChild(lbl)
        leftLabel = lbl

        let rbl = RetroFont.label(right, size: RetroFont.tinySize, color: rightColor)
        rbl.horizontalAlignmentMode = .right
        rbl.position = CGPoint(x: rowWidth / 2 - 8, y: 0)
        rbl.zPosition = 2
        addChild(rbl)
        rightLabel = rbl
    }

    func setAlternatingBackground(index: Int) {
        bg.color = index % 2 == 0
            ? UIColor(hex: "1A1A3E")
            : UIColor(hex: "16213E")
    }

    func setHighlighted(_ highlighted: Bool) {
        bg.color = highlighted ? UIColor(hex: "2A2A4E") : UIColor(hex: "1A1A3E")
    }
}

// MARK: - Confirm Dialog
class ConfirmDialog: SKNode {
    var onConfirm: (() -> Void)?
    var onCancel: (() -> Void)?

    init(title: String, message: String,
         confirmText: String = "CONFIRM", cancelText: String = "CANCEL") {

        super.init()

        zPosition = ZPos.overlay
        isUserInteractionEnabled = true

        // Dim background (covers any reasonable scene size)
        let dimBg = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.7),
                                 size: CGSize(width: 2000, height: 2000))
        dimBg.zPosition = 0
        addChild(dimBg)

        // Panel
        let panelWidth: CGFloat = 320
        let panelHeight: CGFloat = 180
        let panel = RetroPanel(width: panelWidth, height: panelHeight, title: title)
        panel.zPosition = 1
        addChild(panel)

        // Message (below the panel title)
        let msgLabel = RetroFont.label(message, size: RetroFont.smallSize, color: RetroPalette.textGray)
        msgLabel.position = CGPoint(x: 0, y: 15)
        msgLabel.numberOfLines = 0
        msgLabel.preferredMaxLayoutWidth = panelWidth - 40
        msgLabel.zPosition = 3
        addChild(msgLabel)

        // Confirm button
        let confirmBtn = RetroButton(text: confirmText, width: 120, height: 36,
                                     color: RetroPalette.accent, borderColor: RetroPalette.accent,
                                     fontSize: RetroFont.smallSize)
        confirmBtn.position = CGPoint(x: -70, y: -50)
        confirmBtn.zPosition = 3
        confirmBtn.action = { [weak self] in
            self?.onConfirm?()
            self?.dismiss()
        }
        addChild(confirmBtn)

        // Cancel button
        let cancelBtn = RetroButton(text: cancelText, width: 120, height: 36,
                                    color: UIColor(hex: "333344"), borderColor: UIColor(hex: "555577"),
                                    fontSize: RetroFont.smallSize)
        cancelBtn.position = CGPoint(x: 70, y: -50)
        cancelBtn.zPosition = 3
        cancelBtn.action = { [weak self] in
            self?.onCancel?()
            self?.dismiss()
        }
        addChild(cancelBtn)

        // Fade in
        alpha = 0
        run(SKAction.fadeIn(withDuration: 0.15))
    }

    required init?(coder: NSCoder) { fatalError() }

    private func dismiss() {
        run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.1),
            SKAction.removeFromParent(),
        ]))
    }

    // Block touches from falling through to the scene behind
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {}
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {}
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {}
}

// MARK: - Scroll Container (with momentum scrolling)
class ScrollContainer: SKNode {
    private let cropNode: SKCropNode
    private let contentNode: SKNode
    private let maskNode: SKSpriteNode
    let containerHeight: CGFloat
    let contentWidth: CGFloat
    private var contentHeight: CGFloat = 0
    private var scrollOffset: CGFloat = 0

    // Momentum scrolling state
    private var velocity: CGFloat = 0
    private var lastTouchY: CGFloat = 0
    private var lastTouchTime: TimeInterval = 0
    private var isDragging = false
    private let deceleration: CGFloat = 0.92
    private let minVelocity: CGFloat = 0.5

    init(width: CGFloat, height: CGFloat) {
        contentWidth = width
        containerHeight = height

        cropNode = SKCropNode()
        contentNode = SKNode()
        maskNode = SKSpriteNode(color: .white, size: CGSize(width: width, height: height))

        super.init()

        cropNode.maskNode = maskNode
        cropNode.addChild(contentNode)
        addChild(cropNode)

        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) { fatalError() }

    func addScrollContent(_ node: SKNode, at yPosition: CGFloat) {
        node.position.y = yPosition
        contentNode.addChild(node)
        contentHeight = max(contentHeight, abs(yPosition) + 50)
    }

    func setContentHeight(_ height: CGFloat) {
        contentHeight = height
    }

    func clearContent() {
        contentNode.removeAllChildren()
        contentHeight = 0
        scrollOffset = 0
        velocity = 0
        contentNode.position.y = 0
        removeAction(forKey: "momentum")
    }

    private func clampOffset() {
        let maxScroll = max(0, contentHeight - containerHeight)
        scrollOffset = max(-maxScroll, min(0, scrollOffset))
    }

    private func applyOffset() {
        contentNode.position.y = -scrollOffset
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        isDragging = true
        velocity = 0
        lastTouchY = touch.location(in: self).y
        lastTouchTime = CACurrentMediaTime()

        // Stop any in-flight momentum
        removeAction(forKey: "momentum")
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, isDragging else { return }
        let currentY = touch.location(in: self).y
        let dy = currentY - lastTouchY
        let now = CACurrentMediaTime()
        let dt = now - lastTouchTime

        scrollOffset += dy

        // Track velocity (normalized to roughly per-frame)
        if dt > 0 {
            velocity = dy / CGFloat(dt) * 0.016
        }

        lastTouchY = currentY
        lastTouchTime = now

        clampOffset()
        applyOffset()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDragging = false

        // Apply momentum if finger was moving
        if abs(velocity) > minVelocity {
            let momentumAction = SKAction.customAction(withDuration: 3.0) { [weak self] _, _ in
                guard let self = self, !self.isDragging else { return }
                self.velocity *= self.deceleration
                if abs(self.velocity) < self.minVelocity {
                    self.velocity = 0
                    self.removeAction(forKey: "momentum")
                    return
                }
                self.scrollOffset += self.velocity
                self.clampOffset()
                self.applyOffset()
            }
            run(momentumAction, withKey: "momentum")
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDragging = false
        velocity = 0
    }
}

// MARK: - Player Card (with trait badges)
class PlayerCard: SKNode {
    let player: Player
    private let cardWidth: CGFloat
    private let cardHeight: CGFloat

    init(player: Player, width: CGFloat = 200, teamColors: TeamColors? = nil) {
        self.player = player
        self.cardWidth = width
        self.cardHeight = 80
        super.init()

        let bg = SKSpriteNode(
            texture: PixelArt.panelTexture(width: width, height: cardHeight),
            size: CGSize(width: width, height: cardHeight)
        )
        bg.zPosition = 0
        addChild(bg)

        // Position badge
        let posBg = SKSpriteNode(color: positionColor(player.position), size: CGSize(width: 28, height: 16))
        posBg.position = CGPoint(x: -width / 2 + 24, y: cardHeight / 2 - 18)
        posBg.zPosition = 1
        addChild(posBg)

        let posLabel = RetroFont.label(player.position.shortName, size: RetroFont.tinySize)
        posLabel.position = posBg.position
        posLabel.zPosition = 2
        addChild(posLabel)

        // Name
        let nameLabel = RetroFont.label(player.shortName, size: RetroFont.bodySize)
        nameLabel.horizontalAlignmentMode = .left
        nameLabel.position = CGPoint(x: -width / 2 + 44, y: cardHeight / 2 - 18)
        nameLabel.zPosition = 2
        addChild(nameLabel)

        // Overall
        let ovrLabel = RetroFont.label("\(player.overall)", size: RetroFont.headerSize, color: overallColor(player.overall))
        ovrLabel.position = CGPoint(x: width / 2 - 24, y: cardHeight / 2 - 18)
        ovrLabel.zPosition = 2
        addChild(ovrLabel)

        // Stars
        let stars = StarRating(rating: player.starRating)
        stars.position = CGPoint(x: -10, y: -5)
        stars.setScale(0.7)
        stars.zPosition = 2
        addChild(stars)

        // Trait badges (small colored tags to the right of stars)
        if !player.traits.isEmpty {
            let traitStartX: CGFloat = width / 2 - 24
            for (i, trait) in player.traits.prefix(2).enumerated() {
                let traitColor = traitBadgeColor(trait)
                let badgeBg = SKSpriteNode(color: traitColor, size: CGSize(width: 52, height: 12))
                badgeBg.position = CGPoint(x: traitStartX - CGFloat(i) * 56, y: -5)
                badgeBg.zPosition = 1
                addChild(badgeBg)

                let traitLabel = RetroFont.label(trait.name.uppercased(), size: 7, color: .white)
                traitLabel.position = badgeBg.position
                traitLabel.zPosition = 2
                addChild(traitLabel)
            }
        }

        // Stats line
        let statsText: String
        if player.position.isGoalie {
            statsText = "REF:\(player.reflexes) POS:\(player.positioning) REB:\(player.reboundControl)"
        } else {
            statsText = "SPD:\(player.speed) SHT:\(player.shooting) PAS:\(player.passing)"
        }
        let statsLabel = RetroFont.label(statsText, size: RetroFont.tinySize, color: RetroPalette.textGray)
        statsLabel.position = CGPoint(x: 0, y: -24)
        statsLabel.zPosition = 2
        addChild(statsLabel)

        // Salary & Age
        let infoLabel = RetroFont.label("Age \(player.age) | \(player.salaryString)",
                                        size: RetroFont.tinySize, color: RetroPalette.textGray)
        infoLabel.position = CGPoint(x: 0, y: -36)
        infoLabel.zPosition = 2
        addChild(infoLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func positionColor(_ pos: Position) -> UIColor {
        if pos.isForward { return UIColor(hex: "2266AA") }
        if pos.isDefense { return UIColor(hex: "228844") }
        return UIColor(hex: "AA6622")
    }

    private func overallColor(_ ovr: Int) -> UIColor {
        switch ovr {
        case 85...99: return RetroPalette.gold
        case 75...84: return RetroPalette.textGreen
        case 65...74: return RetroPalette.textWhite
        default: return RetroPalette.textGray
        }
    }

    private func traitBadgeColor(_ trait: PlayerTrait) -> UIColor {
        switch trait {
        case .sniper: return UIColor(hex: "CC2222")
        case .playmaker: return UIColor(hex: "2266CC")
        case .enforcer: return UIColor(hex: "886622")
        case .speedster: return UIColor(hex: "22AA44")
        case .clutch: return UIColor(hex: "AA22AA")
        case .ironMan: return UIColor(hex: "666688")
        case .leader: return UIColor(hex: "CC8800")
        }
    }
}

// MARK: - Toast Message
class RetroToast: SKNode {
    init(message: String, color: UIColor = RetroPalette.accent) {
        super.init()

        let bg = SKSpriteNode(color: color.withAlphaComponent(0.9), size: CGSize(width: 400, height: 36))
        bg.zPosition = 0
        addChild(bg)

        let label = RetroFont.label(message, size: RetroFont.bodySize)
        label.zPosition = 2
        addChild(label)

        alpha = 0
        let fadeIn = SKAction.fadeIn(withDuration: 0.2)
        let wait = SKAction.wait(forDuration: 2.0)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()
        run(SKAction.sequence([fadeIn, wait, fadeOut, remove]))
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Back Button Helper
func makeBackButton(target: SKScene, action: @escaping () -> Void) -> RetroButton {
    let btn = RetroButton(text: "< BACK", width: 90, height: 32,
                          color: UIColor(hex: "333344"), borderColor: UIColor(hex: "555577"),
                          fontSize: RetroFont.smallSize)
    btn.zPosition = ZPos.hud
    btn.action = action
    return btn
}
