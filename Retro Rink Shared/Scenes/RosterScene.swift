import SpriteKit

// MARK: - Roster Management Scene
class RosterScene: BaseScene {

    private let gm = GameManager.shared
    private var scrollContainer: ScrollContainer!
    private var filterControl: RetroSegmentedControl!
    private var sortControl: RetroSegmentedControl!

    private var expandedPlayerID: UUID? = nil
    private var expandedPanel: SKNode? = nil

    // Current filter/sort
    private enum PositionFilter: Int {
        case all = 0, forward, defense, goalie
    }

    private enum SortOption: Int {
        case overall = 0, position, salary, age
    }

    private var currentFilter: PositionFilter = .all
    private var currentSort: SortOption = .overall

    override func didMove(to view: SKView) {
        backgroundColor = RetroPalette.background
        super.didMove(to: view)

        setupHeader()
        setupFilters()
        setupScrollContainer()
        setupBackButton()

        buildPlayerList()
    }

    // MARK: - Header

    private func setupHeader() {
        guard let league = gm.league else { return }
        let team = league.playerTeam

        // Team name + ROSTER
        let title = RetroFont.label("\(team.fullName.uppercased()) ROSTER",
                                    size: RetroFont.headerSize, color: team.colors.primaryColor)
        title.position = CGPoint(x: 40, y: safeTop - 20)
        addChild(title)

        // Cap info bar
        let capBarWidth: CGFloat = 200
        let capBar = RetroProgressBar(width: capBarWidth, height: 10)
        capBar.position = CGPoint(x: safeRight - capBarWidth / 2 - 20, y: safeTop - 14)
        capBar.progress = CGFloat(team.capUsagePercent)
        addChild(capBar)

        let capText = "$\(team.totalSalary / 1_000_000)M / $\(GameConfig.salaryCap / 1_000_000)M  |  Space: $\(team.capSpace / 1_000_000)M"
        let capLabel = RetroFont.label(capText, size: RetroFont.tinySize, color: RetroPalette.textGray)
        capLabel.position = CGPoint(x: safeRight - capBarWidth / 2 - 20, y: safeTop - 28)
        addChild(capLabel)
    }

    // MARK: - Filters

    private func setupFilters() {
        let filterY = safeTop - 48
        let filterWidth: CGFloat = min(200, safeWidth * 0.28)
        let sortWidth: CGFloat = min(200, safeWidth * 0.28)

        // Position filter
        filterControl = RetroSegmentedControl(items: ["ALL", "FWD", "DEF", "G"], width: filterWidth, height: 26)
        filterControl.position = CGPoint(x: safeLeft + filterWidth / 2 + 14, y: filterY)
        filterControl.onSelectionChanged = { [weak self] index in
            self?.currentFilter = PositionFilter(rawValue: index) ?? .all
            self?.buildPlayerList()
        }
        addChild(filterControl)

        // Sort options
        sortControl = RetroSegmentedControl(items: ["OVR", "POS", "SAL", "AGE"], width: sortWidth, height: 26)
        sortControl.position = CGPoint(x: safeRight - sortWidth / 2 - 14, y: filterY)
        sortControl.onSelectionChanged = { [weak self] index in
            self?.currentSort = SortOption(rawValue: index) ?? .overall
            self?.buildPlayerList()
        }
        addChild(sortControl)
    }

    // MARK: - Scroll Container

    private func setupScrollContainer() {
        let scrollHeight = safeHeight - 80
        let scrollWidth = safeWidth - 20
        scrollContainer = ScrollContainer(width: scrollWidth, height: scrollHeight)
        scrollContainer.position = CGPoint(x: 0, y: -10)
        addChild(scrollContainer)
    }

    // MARK: - Build Player List

    private func buildPlayerList() {
        scrollContainer.clearContent()
        expandedPanel?.removeFromParent()
        expandedPanel = nil

        guard let league = gm.league else { return }
        var players = league.playerTeam.roster

        // Apply position filter
        switch currentFilter {
        case .all: break
        case .forward: players = players.filter { $0.position.isForward }
        case .defense: players = players.filter { $0.position.isDefense }
        case .goalie: players = players.filter { $0.position.isGoalie }
        }

        // Apply sort
        switch currentSort {
        case .overall: players.sort { $0.overall > $1.overall }
        case .position: players.sort { $0.position.rawValue < $1.position.rawValue }
        case .salary: players.sort { $0.salary > $1.salary }
        case .age: players.sort { $0.age < $1.age }
        }

        // Two-column layout
        let cardWidth: CGFloat = (scrollContainer.contentWidth - 16) / 2
        let cardHeight: CGFloat = 85
        let spacing: CGFloat = 6
        let cols = 2
        let halfCardWidth = cardWidth / 2 + spacing / 2

        for (i, player) in players.enumerated() {
            let col = i % cols
            let row = i / cols

            let card = PlayerCard(player: player, width: cardWidth,
                                  teamColors: league.playerTeam.colors)

            let xOffset: CGFloat = col == 0 ? -halfCardWidth : halfCardWidth
            let yPos = -(CGFloat(row) * (cardHeight + spacing))
            card.position.x = xOffset

            card.isUserInteractionEnabled = true
            card.name = "playerCard_\(player.id.uuidString)"

            scrollContainer.addScrollContent(card, at: yPos)
        }

        // Set total content height
        let totalRows = (players.count + cols - 1) / cols
        let totalHeight = CGFloat(totalRows) * (cardHeight + spacing) + 50
        scrollContainer.setContentHeight(totalHeight)
    }

    // MARK: - Touch Handling (card tap to expand)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let tapped = nodes(at: location)

        for node in tapped {
            if let card = findPlayerCard(in: node) {
                toggleExpanded(for: card.player)
                return
            }
        }

        // Tap elsewhere closes expanded panel
        if expandedPanel != nil {
            closeExpanded()
        }
    }

    private func findPlayerCard(in node: SKNode) -> PlayerCard? {
        if let card = node as? PlayerCard { return card }
        if let parent = node.parent { return findPlayerCard(in: parent) }
        return nil
    }

    private func toggleExpanded(for player: Player) {
        if expandedPlayerID == player.id {
            closeExpanded()
        } else {
            showExpanded(for: player)
        }
    }

    // MARK: - Expanded Player Detail

    private func showExpanded(for player: Player) {
        closeExpanded()

        expandedPlayerID = player.id
        let panelWidth: CGFloat = 320
        let panelHeight: CGFloat = 220
        let detail = SKNode()
        detail.zPosition = ZPos.overlay

        // Dim background
        let dim = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.6),
                               size: CGSize(width: 2000, height: 2000))
        dim.zPosition = -1
        detail.addChild(dim)

        // Panel
        let panel = RetroPanel(width: panelWidth, height: panelHeight)
        detail.addChild(panel)

        var y: CGFloat = panelHeight / 2 - 22

        // Player name + position + OVR
        let posColor = positionColor(player.position)
        let posBg = SKSpriteNode(color: posColor, size: CGSize(width: 28, height: 16))
        posBg.position = CGPoint(x: -panelWidth / 2 + 24, y: y)
        posBg.zPosition = 1
        detail.addChild(posBg)

        let posLabel = RetroFont.label(player.position.shortName, size: RetroFont.tinySize)
        posLabel.position = posBg.position
        posLabel.zPosition = 2
        detail.addChild(posLabel)

        let nameLabel = RetroFont.label(player.fullName, size: RetroFont.bodySize, color: .white)
        nameLabel.horizontalAlignmentMode = .left
        nameLabel.position = CGPoint(x: -panelWidth / 2 + 44, y: y)
        nameLabel.zPosition = 2
        detail.addChild(nameLabel)

        let ovrLabel = RetroFont.label("\(player.overall) OVR", size: RetroFont.bodySize, color: overallColor(player.overall))
        ovrLabel.horizontalAlignmentMode = .right
        ovrLabel.position = CGPoint(x: panelWidth / 2 - 12, y: y)
        ovrLabel.zPosition = 2
        detail.addChild(ovrLabel)

        // Stars
        y -= 20
        let stars = StarRating(rating: player.starRating)
        stars.setScale(0.8)
        stars.position = CGPoint(x: -panelWidth / 4, y: y)
        stars.zPosition = 2
        detail.addChild(stars)

        // Age, Jersey, Contract
        let infoText = "#\(player.jerseyNumber) | Age \(player.age) | \(player.salaryString) (\(player.contractYears)yr)"
        let infoLabel = RetroFont.label(infoText, size: RetroFont.tinySize, color: RetroPalette.textGray)
        infoLabel.position = CGPoint(x: panelWidth / 4 + 10, y: y)
        infoLabel.zPosition = 2
        detail.addChild(infoLabel)

        // Full stats
        y -= 22
        if player.position.isGoalie {
            let stats = [
                ("REF", player.reflexes), ("POS", player.positioning), ("REB", player.reboundControl),
                ("AWR", player.awareness), ("SPD", player.speed),
            ]
            layoutStats(stats, in: detail, panelWidth: panelWidth, y: &y)
        } else {
            let stats = [
                ("SPD", player.speed), ("SHT", player.shooting), ("PAS", player.passing),
                ("HND", player.puckHandling), ("CHK", player.checking), ("AWR", player.awareness),
            ]
            layoutStats(stats, in: detail, panelWidth: panelWidth, y: &y)
        }

        // Season stats
        y -= 18
        let seasonText: String
        if player.position.isGoalie {
            let svPct = player.goalieSavePercentage
            let gaa = player.goalieGAA
            seasonText = "GP:\(player.seasonGamesPlayed)  SV%:\(String(format: "%.3f", svPct))  GAA:\(String(format: "%.2f", gaa))  SO:\(player.seasonShutouts)"
        } else {
            seasonText = "GP:\(player.seasonGamesPlayed)  G:\(player.seasonGoals)  A:\(player.seasonAssists)  PTS:\(player.points)  +/-:\(player.seasonPlusMinus)"
        }
        let seasonLabel = RetroFont.label(seasonText, size: RetroFont.tinySize, color: RetroPalette.textGray)
        seasonLabel.position = CGPoint(x: 0, y: y)
        seasonLabel.zPosition = 2
        detail.addChild(seasonLabel)

        // Traits
        if !player.traits.isEmpty {
            y -= 18
            for (i, trait) in player.traits.enumerated() {
                let traitColor = traitBadgeColor(trait)
                let badgeBg = SKSpriteNode(color: traitColor, size: CGSize(width: 70, height: 14))
                let xPos = -CGFloat(player.traits.count - 1) * 38 + CGFloat(i) * 76
                badgeBg.position = CGPoint(x: xPos, y: y)
                badgeBg.zPosition = 1
                detail.addChild(badgeBg)

                let traitLabel = RetroFont.label(trait.name.uppercased(), size: 7, color: .white)
                traitLabel.position = badgeBg.position
                traitLabel.zPosition = 2
                detail.addChild(traitLabel)
            }
        }

        // Cut player button
        y -= 24
        guard let league = gm.league else { return }
        let canCut = league.playerTeam.roster.count > GameConfig.minRosterSize
        let cutBtn = RetroButton(text: "CUT PLAYER", width: 120, height: 30,
                                 color: canCut ? UIColor(hex: "442222") : UIColor(hex: "333333"),
                                 borderColor: canCut ? RetroPalette.textRed : UIColor(hex: "555555"),
                                 fontSize: RetroFont.tinySize)
        cutBtn.position = CGPoint(x: 0, y: y)
        cutBtn.zPosition = 2
        if canCut {
            let playerID = player.id
            cutBtn.action = { [weak self] in
                self?.promptCutPlayer(id: playerID, name: player.shortName)
            }
        } else {
            cutBtn.isUserInteractionEnabled = false
            cutBtn.alpha = 0.5
        }
        detail.addChild(cutBtn)

        // Close button
        let closeBtn = RetroButton(text: "X", width: 28, height: 28,
                                   color: UIColor(hex: "333344"), borderColor: UIColor(hex: "555577"),
                                   fontSize: RetroFont.smallSize)
        closeBtn.position = CGPoint(x: panelWidth / 2 - 20, y: panelHeight / 2 - 20)
        closeBtn.zPosition = 2
        closeBtn.action = { [weak self] in self?.closeExpanded() }
        detail.addChild(closeBtn)

        detail.isUserInteractionEnabled = true
        addChild(detail)
        expandedPanel = detail

        // Fade in
        detail.alpha = 0
        detail.run(SKAction.fadeIn(withDuration: 0.12))
    }

    private func layoutStats(_ stats: [(String, Int)], in parent: SKNode, panelWidth: CGFloat, y: inout CGFloat) {
        let perRow = 3
        let colSpacing = (panelWidth - 24) / CGFloat(perRow)
        let startX = -panelWidth / 2 + 16

        for (i, (label, value)) in stats.enumerated() {
            let col = i % perRow
            let row = i / perRow
            let xPos = startX + CGFloat(col) * colSpacing + colSpacing / 2
            let yPos = y - CGFloat(row) * 16

            let color = statColor(value)
            let statLabel = RetroFont.label("\(label): \(value)", size: RetroFont.tinySize, color: color)
            statLabel.position = CGPoint(x: xPos, y: yPos)
            parent.addChild(statLabel)
        }

        let rows = (stats.count + perRow - 1) / perRow
        y -= CGFloat(rows) * 16
    }

    private func closeExpanded() {
        expandedPanel?.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.08),
            SKAction.removeFromParent(),
        ]))
        expandedPanel = nil
        expandedPlayerID = nil
    }

    // MARK: - Cut Player

    private func promptCutPlayer(id: UUID, name: String) {
        closeExpanded()

        let dialog = ConfirmDialog(
            title: "CUT PLAYER",
            message: "Release \(name) from the roster?",
            confirmText: "CUT",
            cancelText: "CANCEL"
        )
        dialog.onConfirm = { [weak self] in
            self?.cutPlayer(id: id)
        }
        dialog.onCancel = { }
        addChild(dialog)
    }

    private func cutPlayer(id: UUID) {
        gm.league.playerTeam.removePlayer(id: id)
        gm.save()
        buildPlayerList()

        let toast = RetroToast(message: "Player released")
        toast.position = CGPoint(x: 0, y: safeBottom + 30)
        addChild(toast)
    }

    // MARK: - Back Button

    private func setupBackButton() {
        let back = makeBackButton(target: self) { [weak self] in
            guard let view = self?.view else { return }
            GameManager.transition(from: view, toSceneType: HubScene.self)
        }
        back.position = CGPoint(x: safeLeft + 52, y: safeTop - 20)
        addChild(back)
    }

    // MARK: - Color Helpers

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

    private func statColor(_ value: Int) -> UIColor {
        switch value {
        case 85...99: return RetroPalette.gold
        case 75...84: return RetroPalette.textGreen
        case 65...74: return RetroPalette.textWhite
        case 55...64: return RetroPalette.textGray
        default: return RetroPalette.textRed
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
