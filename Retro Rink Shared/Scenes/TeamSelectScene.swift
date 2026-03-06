import SpriteKit

// MARK: - Team Selection Scene
class TeamSelectScene: BaseScene {

    private var teamNodes: [SKNode] = []
    private var selectedIndex: Int = -1
    private var difficultyIndex: Int = 1 // default Pro

    private var confirmButton: RetroButton!
    private var infoPanelNode: SKNode?
    private var difficultyButtons: [RetroButton] = []
    private var jerseyPreview: SKSpriteNode?

    override func didMove(to view: SKView) {
        backgroundColor = RetroPalette.background
        super.didMove(to: view)

        setupHeader()
        setupTeamGrid()
        setupInfoPanel()
        setupDifficulty()
        setupConfirm()
        setupBackButton()
    }

    // MARK: - Header

    private func setupHeader() {
        let title = RetroFont.label("CHOOSE YOUR TEAM", size: RetroFont.headerSize, color: RetroPalette.gold)
        title.position = CGPoint(x: 0, y: safeTop - 20)
        addChild(title)
    }

    // MARK: - Team Grid (4x4)

    private func setupTeamGrid() {
        let cols = 4
        let rows = 4
        let cellWidth: CGFloat = 68
        let cellHeight: CGFloat = 60
        let gridWidth = CGFloat(cols) * cellWidth
        let gridHeight = CGFloat(rows) * cellHeight
        let gridCenterX: CGFloat = -safeWidth / 4 // shift grid to the left
        let startX = gridCenterX - gridWidth / 2 + cellWidth / 2
        let startY: CGFloat = safeTop - 60

        for i in 0..<GameConfig.totalTeams {
            let col = i % cols
            let row = i / cols

            let data = TeamData.allTeams[i]
            let node = SKNode()
            node.position = CGPoint(
                x: startX + CGFloat(col) * cellWidth,
                y: startY - CGFloat(row) * cellHeight
            )
            node.name = "team_\(i)"

            // Team color swatch
            let swatch = SKSpriteNode(
                texture: PixelArt.buttonTexture(width: 56, height: 42,
                                                color: data.colors.primaryColor,
                                                borderColor: data.colors.secondaryColor),
                size: CGSize(width: 56, height: 42)
            )
            swatch.name = "team_\(i)"
            node.addChild(swatch)

            // Team abbreviation
            let abbr = RetroFont.label(data.abbr, size: RetroFont.smallSize, color: data.colors.secondaryColor)
            abbr.position = CGPoint(x: 0, y: -28)
            abbr.name = "team_\(i)"
            node.addChild(abbr)

            // Selection ring (hidden by default)
            let ring = SKShapeNode(rectOf: CGSize(width: 62, height: 48), cornerRadius: 2)
            ring.strokeColor = RetroPalette.gold
            ring.lineWidth = 2
            ring.glowWidth = 3
            ring.fillColor = .clear
            ring.name = "ring_\(i)"
            ring.isHidden = true
            ring.isAntialiased = false
            node.addChild(ring)

            addChild(node)
            teamNodes.append(node)
        }
    }

    // MARK: - Info Panel (right side)

    private func setupInfoPanel() {
        // Placeholder panel shown on the right; updated when a team is selected
        let panelX: CGFloat = safeWidth / 4 + 20
        let panel = RetroPanel(width: 220, height: 260)
        panel.position = CGPoint(x: panelX, y: 10)
        addChild(panel)

        let placeholder = RetroFont.label("TAP A TEAM", size: RetroFont.bodySize, color: RetroPalette.textGray)
        placeholder.position = CGPoint(x: panelX, y: 10)
        placeholder.name = "infoPlaceholder"
        addChild(placeholder)
    }

    private func updateInfoPanel(for index: Int) {
        // Remove old info nodes
        infoPanelNode?.removeFromParent()
        childNode(withName: "infoPlaceholder")?.removeFromParent()

        let data = TeamData.allTeams[index]
        let team = TeamData.createTeam(index: index)
        let panelX: CGFloat = safeWidth / 4 + 20

        let info = SKNode()
        info.position = CGPoint(x: panelX, y: 0)

        // City
        let cityLabel = RetroFont.label(data.city.uppercased(), size: RetroFont.smallSize, color: RetroPalette.textGray)
        cityLabel.position = CGPoint(x: 0, y: 100)
        info.addChild(cityLabel)

        // Team name
        let nameLabel = RetroFont.label(data.name.uppercased(), size: RetroFont.headerSize, color: data.colors.primaryColor)
        nameLabel.position = CGPoint(x: 0, y: 80)
        info.addChild(nameLabel)

        // OVR
        let ovrLabel = RetroFont.label("OVR \(team.teamOverall)", size: RetroFont.bodySize, color: RetroPalette.textGreen)
        ovrLabel.position = CGPoint(x: 0, y: 58)
        info.addChild(ovrLabel)

        // Jersey preview
        jerseyPreview?.removeFromParent()
        let jersey = SKSpriteNode(texture: PixelArt.skaterTexture(teamColors: data.colors))
        jersey.setScale(3.0)
        jersey.position = CGPoint(x: 0, y: 28)
        info.addChild(jersey)
        jerseyPreview = jersey

        // Top 3 star players
        let sortedRoster = team.roster.sorted { $0.overall > $1.overall }
        let starPlayers = Array(sortedRoster.prefix(3))

        let starsTitle = RetroFont.label("TOP PLAYERS", size: RetroFont.tinySize, color: RetroPalette.gold)
        starsTitle.position = CGPoint(x: 0, y: -5)
        info.addChild(starsTitle)

        for (i, player) in starPlayers.enumerated() {
            let y: CGFloat = -22 - CGFloat(i) * 16
            let posText = player.position.shortName
            let text = "\(posText) \(player.shortName)"
            let pLabel = RetroFont.label(text, size: RetroFont.tinySize, color: .white)
            pLabel.horizontalAlignmentMode = .left
            pLabel.position = CGPoint(x: -90, y: y)
            info.addChild(pLabel)

            let oLabel = RetroFont.label("\(player.overall)", size: RetroFont.tinySize, color: overallColor(player.overall))
            oLabel.horizontalAlignmentMode = .right
            oLabel.position = CGPoint(x: 90, y: y)
            info.addChild(oLabel)
        }

        addChild(info)
        infoPanelNode = info
    }

    // MARK: - Difficulty Selector

    private func setupDifficulty() {
        let diffTitle = RetroFont.label("DIFFICULTY", size: RetroFont.tinySize, color: RetroPalette.textGray)
        diffTitle.position = CGPoint(x: 0, y: safeBottom + 72)
        addChild(diffTitle)

        let difficulties = Difficulty.allCases
        let btnWidth: CGFloat = 90
        let spacing: CGFloat = 6
        let totalWidth = CGFloat(difficulties.count) * btnWidth + CGFloat(difficulties.count - 1) * spacing
        let startX = -totalWidth / 2 + btnWidth / 2

        for (i, diff) in difficulties.enumerated() {
            let isSelected = i == difficultyIndex
            let btn = RetroButton(
                text: diff.name.uppercased(),
                width: btnWidth,
                height: 28,
                color: isSelected ? RetroPalette.midPanel : UIColor(hex: "222233"),
                borderColor: isSelected ? RetroPalette.accent : UIColor(hex: "444466"),
                fontSize: RetroFont.tinySize
            )
            btn.position = CGPoint(x: startX + CGFloat(i) * (btnWidth + spacing), y: safeBottom + 48)
            let index = i
            btn.action = { [weak self] in
                self?.selectDifficulty(index)
            }
            addChild(btn)
            difficultyButtons.append(btn)
        }
    }

    private func selectDifficulty(_ index: Int) {
        difficultyIndex = index

        // Update button visuals
        for (i, btn) in difficultyButtons.enumerated() {
            let isSelected = i == index
            let color = isSelected ? RetroPalette.midPanel : UIColor(hex: "222233")
            let borderColor = isSelected ? RetroPalette.accent : UIColor(hex: "444466")
            let tex = PixelArt.buttonTexture(width: btn.background.size.width,
                                             height: btn.background.size.height,
                                             color: color, borderColor: borderColor)
            btn.background.texture = tex
            btn.label.fontColor = isSelected ? .white : RetroPalette.textGray
        }
    }

    // MARK: - Confirm & Back

    private func setupConfirm() {
        confirmButton = RetroButton(text: "START SEASON", width: 200, height: 44,
                                    color: RetroPalette.midPanel, borderColor: RetroPalette.accent)
        confirmButton.position = CGPoint(x: 0, y: safeBottom + 18)
        confirmButton.alpha = 0.3
        confirmButton.isUserInteractionEnabled = false
        confirmButton.action = { [weak self] in self?.confirmSelection() }
        addChild(confirmButton)
    }

    private func setupBackButton() {
        let back = makeBackButton(target: self) { [weak self] in
            guard let view = self?.view else { return }
            GameManager.transition(from: view, toSceneType: MainMenuScene.self)
        }
        back.position = CGPoint(x: safeLeft + 52, y: safeTop - 20)
        addChild(back)
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let tapped = nodes(at: location)

        for node in tapped {
            if let name = node.name, name.hasPrefix("team_") {
                let indexStr = name.replacingOccurrences(of: "team_", with: "")
                if let index = Int(indexStr) {
                    selectTeam(index)
                    return
                }
            }
        }
    }

    private func selectTeam(_ index: Int) {
        // Deselect previous
        if selectedIndex >= 0 {
            teamNodes[selectedIndex].childNode(withName: "ring_\(selectedIndex)")?.isHidden = true
        }

        selectedIndex = index
        teamNodes[index].childNode(withName: "ring_\(index)")?.isHidden = false

        // Update info panel
        updateInfoPanel(for: index)

        // Enable confirm
        confirmButton.alpha = 1.0
        confirmButton.isUserInteractionEnabled = true

        // Bounce animation
        let node = teamNodes[index]
        node.run(SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.1),
            SKAction.scale(to: 1.0, duration: 0.1),
        ]))
    }

    // MARK: - Confirm Selection

    private func confirmSelection() {
        guard selectedIndex >= 0 else { return }

        let difficulty = Difficulty.allCases[difficultyIndex]
        GameManager.shared.startNewGame(teamIndex: selectedIndex, difficulty: difficulty)

        guard let view = view else { return }
        GameManager.pixelTransition(from: view, toSceneType: HubScene.self)
    }

    // MARK: - Helpers

    private func overallColor(_ ovr: Int) -> UIColor {
        switch ovr {
        case 85...99: return RetroPalette.gold
        case 75...84: return RetroPalette.textGreen
        case 65...74: return RetroPalette.textWhite
        default: return RetroPalette.textGray
        }
    }
}
