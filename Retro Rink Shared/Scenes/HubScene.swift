import SpriteKit

// MARK: - Team Hub Scene (Main Management Screen)
class HubScene: BaseScene {

    private let gm = GameManager.shared

    override func didMove(to view: SKView) {
        backgroundColor = RetroPalette.background
        super.didMove(to: view)

        guard gm.league != nil else { return }

        setupBackgroundDecor()
        setupMenuButton()
        setupLeftColumn()
        setupCenterColumn()
        setupRightColumn()
        setupColumnDividers()
    }

    // MARK: - Layout Constants

    private var leftColX: CGFloat { safeLeft + safeWidth * 0.17 }
    private var centerColX: CGFloat { 0 }
    private var rightColX: CGFloat { safeRight - safeWidth * 0.17 }
    private var colWidth: CGFloat { safeWidth * 0.28 }

    // MARK: - Background Decoration

    private func setupBackgroundDecor() {
        // Subtle scan lines for retro CRT feel
        let lineSpacing: CGFloat = 4
        var y: CGFloat = -size.height / 2
        while y < size.height / 2 {
            let line = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.04),
                                    size: CGSize(width: size.width, height: 1))
            line.position = CGPoint(x: 0, y: y)
            line.zPosition = -1
            addChild(line)
            y += lineSpacing
        }
    }

    // MARK: - Column Dividers

    private func setupColumnDividers() {
        let dividerHeight = safeHeight - 24
        let leftDivX = (leftColX + centerColX) / 2
        let rightDivX = (centerColX + rightColX) / 2

        for x in [leftDivX, rightDivX] {
            // Main divider line
            let divider = SKSpriteNode(color: RetroPalette.divider.withAlphaComponent(0.3),
                                       size: CGSize(width: 1, height: dividerHeight))
            divider.position = CGPoint(x: x, y: 0)
            divider.zPosition = 1
            addChild(divider)

            // Highlight line (bevel effect)
            let highlight = SKSpriteNode(color: UIColor.white.withAlphaComponent(0.04),
                                         size: CGSize(width: 1, height: dividerHeight))
            highlight.position = CGPoint(x: x + 1, y: 0)
            highlight.zPosition = 1
            addChild(highlight)
        }
    }

    // MARK: - Menu Button

    private func setupMenuButton() {
        let menuBtn = RetroButton(text: "MENU", width: 70, height: 24,
                                  color: UIColor(hex: "222233"), borderColor: UIColor(hex: "444466"),
                                  fontSize: RetroFont.tinySize)
        menuBtn.position = CGPoint(x: safeRight - 42, y: safeTop - 16)
        menuBtn.zPosition = ZPos.hud
        menuBtn.action = { [weak self] in
            guard let view = self?.view else { return }
            GameManager.transition(from: view, toSceneType: MainMenuScene.self)
        }
        addChild(menuBtn)
    }

    // MARK: - Left Column: Team Info + Facilities

    private func setupLeftColumn() {
        guard let league = gm.league else { return }
        let team = league.playerTeam
        let x = leftColX
        var y = safeTop - 18

        // Team info panel background
        let teamInfoHeight: CGFloat = 130
        let teamPanel = RetroPanel(width: colWidth + 8, height: teamInfoHeight)
        teamPanel.position = CGPoint(x: x, y: y - teamInfoHeight / 2 + 6)
        teamPanel.zPosition = 0
        addChild(teamPanel)

        // Team name with team color accent bar
        let colorBar = SKSpriteNode(color: team.colors.primaryColor,
                                    size: CGSize(width: 4, height: 14))
        colorBar.position = CGPoint(x: x - colWidth / 2 + 10, y: y)
        colorBar.zPosition = 2
        addChild(colorBar)

        // Team name - truncate to fit within column
        let fullName = team.fullName.uppercased()
        let maxChars = Int(colWidth / 8)  // ~8pt per char at bodySize with Courier
        let displayName = fullName.count > maxChars ? String(fullName.prefix(maxChars)) : fullName
        let teamName = RetroFont.label(displayName, size: RetroFont.smallSize, color: team.colors.primaryColor)
        teamName.position = CGPoint(x: x, y: y)
        teamName.zPosition = 2
        addChild(teamName)

        // Record
        y -= 20
        let record = RetroFont.label(team.record, size: RetroFont.headerSize, color: .white)
        record.position = CGPoint(x: x, y: y)
        record.zPosition = 2
        addChild(record)

        // Season info
        y -= 18
        let seasonInfo = RetroFont.label(
            "Season \(league.seasonNumber) | Week \(league.currentWeek + 1)/\(GameConfig.seasonGames)",
            size: RetroFont.tinySize, color: RetroPalette.textGray
        )
        seasonInfo.position = CGPoint(x: x, y: y)
        seasonInfo.zPosition = 2
        addChild(seasonInfo)

        // OVR badge
        y -= 22
        let ovrBg = SKSpriteNode(color: UIColor(hex: "1A3A2A"), size: CGSize(width: 70, height: 20))
        ovrBg.position = CGPoint(x: x - 30, y: y)
        ovrBg.zPosition = 1
        addChild(ovrBg)

        let ovrLabel = RetroFont.label("OVR \(team.teamOverall)", size: RetroFont.smallSize, color: RetroPalette.textGreen)
        ovrLabel.position = CGPoint(x: x - 30, y: y)
        ovrLabel.zPosition = 2
        addChild(ovrLabel)

        // Roster count
        let rosterLabel = RetroFont.label("\(team.roster.count)/\(GameConfig.maxRosterSize)",
                                          size: RetroFont.tinySize, color: RetroPalette.textGray)
        rosterLabel.position = CGPoint(x: x + 35, y: y)
        rosterLabel.zPosition = 2
        addChild(rosterLabel)

        // Salary cap section
        y -= 20
        let capText = "Cap: $\(team.totalSalary / 1_000_000)M / $\(GameConfig.salaryCap / 1_000_000)M"
        let capLabel = RetroFont.label(capText, size: RetroFont.tinySize, color: RetroPalette.textGray)
        capLabel.position = CGPoint(x: x, y: y)
        capLabel.zPosition = 2
        addChild(capLabel)

        y -= 14
        let capBar = RetroProgressBar(width: colWidth - 20)
        capBar.position = CGPoint(x: x, y: y)
        capBar.zPosition = 2
        capBar.progress = CGFloat(team.capUsagePercent)
        addChild(capBar)

        // Coaching credits
        y -= 18
        let creditsBg = SKSpriteNode(color: UIColor(hex: "2A2210"), size: CGSize(width: colWidth - 16, height: 16))
        creditsBg.position = CGPoint(x: x, y: y)
        creditsBg.zPosition = 1
        addChild(creditsBg)

        let creditsLabel = RetroFont.label("CC: \(team.coachingCredits)",
                                           size: RetroFont.tinySize, color: RetroPalette.gold)
        creditsLabel.position = CGPoint(x: x, y: y)
        creditsLabel.zPosition = 2
        addChild(creditsLabel)

        // Facilities section with panel background
        y -= 24
        let facHeight: CGFloat = CGFloat(team.facilities.count) * 24 + 30
        let facPanel = RetroPanel(width: colWidth + 8, height: facHeight, title: "FACILITIES")
        facPanel.position = CGPoint(x: x, y: y - facHeight / 2 + 6)
        facPanel.zPosition = 0
        addChild(facPanel)

        y -= 4

        for facility in team.facilities {
            y -= 22
            let levelText = "Lv.\(facility.level)"
            let facLabel = RetroFont.label("\(facility.type.name): \(levelText)",
                                          size: RetroFont.tinySize, color: .white)
            facLabel.horizontalAlignmentMode = .left
            facLabel.position = CGPoint(x: x - colWidth / 2 + 12, y: y)
            facLabel.zPosition = 2
            addChild(facLabel)

            if facility.canUpgrade {
                let cost = facility.upgradeCost
                let canAfford = team.coachingCredits >= cost
                let upgradeBtn = RetroButton(
                    text: "UP (\(cost)CC)",
                    width: 64, height: 18,
                    color: canAfford ? UIColor(hex: "1A3A1A") : UIColor(hex: "2A1A1A"),
                    borderColor: canAfford ? RetroPalette.textGreen : UIColor(hex: "443333"),
                    fontSize: 7
                )
                upgradeBtn.position = CGPoint(x: x + colWidth / 2 - 40, y: y)
                upgradeBtn.zPosition = 2
                if canAfford {
                    let facilityType = facility.type
                    upgradeBtn.action = { [weak self] in
                        self?.upgradeFacility(type: facilityType)
                    }
                } else {
                    upgradeBtn.isUserInteractionEnabled = false
                    upgradeBtn.alpha = 0.5
                }
                addChild(upgradeBtn)
            }
        }
    }

    // MARK: - Center Column: Action Buttons

    private func setupCenterColumn() {
        guard let league = gm.league else { return }
        let x = centerColX

        if league.seasonPhase == .offseason || league.isSeasonComplete {
            setupOffseasonButtons(x: x)
        } else {
            setupSeasonButtons(x: x)
        }
    }

    private func setupSeasonButtons(x: CGFloat) {
        guard let league = gm.league else { return }
        var y: CGFloat = safeTop - 35

        // PLAY GAME (large accent button)
        let hasGame = league.playerGameThisWeek != nil
        let playBtn = RetroButton(
            text: hasGame ? "PLAY GAME" : "ADVANCE WEEK",
            width: 220, height: 52,
            color: RetroPalette.midPanel, borderColor: RetroPalette.accent,
            fontSize: RetroFont.headerSize
        )
        playBtn.position = CGPoint(x: x, y: y)
        playBtn.zPosition = 2
        playBtn.action = { [weak self] in
            if hasGame {
                self?.playGame()
            } else {
                self?.advanceWeek()
            }
        }
        addChild(playBtn)

        // Section label
        y -= 50
        let actionsLabel = RetroFont.label("ACTIONS", size: RetroFont.tinySize, color: RetroPalette.textGray)
        actionsLabel.position = CGPoint(x: x, y: y)
        actionsLabel.zPosition = 2
        addChild(actionsLabel)

        // Separator under label
        let sep = SKSpriteNode(color: RetroPalette.divider.withAlphaComponent(0.3),
                               size: CGSize(width: 140, height: 1))
        sep.position = CGPoint(x: x, y: y - 8)
        sep.zPosition = 1
        addChild(sep)

        // Secondary buttons
        let buttons: [(String, () -> Void)] = [
            ("ROSTER", { [weak self] in self?.openRoster() }),
            ("SCHEDULE", { [weak self] in self?.openSchedule() }),
            ("TRADE", { [weak self] in self?.openTrade() }),
            ("FREE AGENTS", { [weak self] in self?.openFreeAgency() }),
        ]

        y -= 24
        for (text, action) in buttons {
            let btn = RetroButton(text: text, width: 170, height: 38,
                                  color: UIColor(hex: "1A1A30"), borderColor: UIColor(hex: "3A3A5A"))
            btn.position = CGPoint(x: x, y: y)
            btn.zPosition = 2
            btn.action = action
            addChild(btn)
            y -= 46
        }
    }

    private func setupOffseasonButtons(x: CGFloat) {
        var y: CGFloat = safeTop - 35

        // Offseason header with accent styling
        let offseasonBg = SKSpriteNode(color: RetroPalette.gold.withAlphaComponent(0.1),
                                       size: CGSize(width: 180, height: 24))
        offseasonBg.position = CGPoint(x: x, y: y)
        offseasonBg.zPosition = 1
        addChild(offseasonBg)

        let offseasonLabel = RetroFont.label("OFFSEASON", size: RetroFont.headerSize, color: RetroPalette.gold)
        offseasonLabel.position = CGPoint(x: x, y: y)
        offseasonLabel.zPosition = 2
        addChild(offseasonLabel)

        let buttons: [(String, Bool, () -> Void)] = [
            ("DRAFT", false, { [weak self] in self?.openDraft() }),
            ("FREE AGENCY", false, { [weak self] in self?.openFreeAgency() }),
            ("ROSTER", false, { [weak self] in self?.openRoster() }),
            ("NEXT SEASON", true, { [weak self] in self?.advanceSeason() }),
        ]

        y -= 40
        for (text, isPrimary, action) in buttons {
            let btn = RetroButton(
                text: text,
                width: isPrimary ? 210 : 170,
                height: isPrimary ? 46 : 38,
                color: isPrimary ? UIColor(hex: "1A3A1A") : UIColor(hex: "1A1A30"),
                borderColor: isPrimary ? RetroPalette.textGreen : UIColor(hex: "3A3A5A"),
                fontSize: isPrimary ? RetroFont.bodySize : RetroFont.bodySize
            )
            btn.position = CGPoint(x: x, y: y)
            btn.zPosition = 2
            btn.action = action
            addChild(btn)
            y -= 48
        }
    }

    // MARK: - Right Column: Standings + News

    private func setupRightColumn() {
        guard let league = gm.league else { return }
        let x = rightColX
        var y = safeTop - 20

        // Standings panel with header
        let standingsHeight: CGFloat = 185
        let standingsPanel = RetroPanel(width: colWidth + 8, height: standingsHeight, title: "STANDINGS")
        standingsPanel.position = CGPoint(x: x, y: y - standingsHeight / 2)
        standingsPanel.zPosition = 0
        addChild(standingsPanel)

        let standings = league.standings
        let topN = min(8, standings.count)
        y -= 38

        // Column headers
        let hdrY = y
        let rankHdr = RetroFont.label("#", size: 7, color: RetroPalette.textGray)
        rankHdr.horizontalAlignmentMode = .right
        rankHdr.position = CGPoint(x: x - colWidth / 2 + 20, y: hdrY)
        rankHdr.zPosition = 2
        addChild(rankHdr)

        let teamHdr = RetroFont.label("TEAM", size: 7, color: RetroPalette.textGray)
        teamHdr.horizontalAlignmentMode = .left
        teamHdr.position = CGPoint(x: x - colWidth / 2 + 26, y: hdrY)
        teamHdr.zPosition = 2
        addChild(teamHdr)

        let ptsHdr = RetroFont.label("PTS", size: 7, color: RetroPalette.textGray)
        ptsHdr.horizontalAlignmentMode = .right
        ptsHdr.position = CGPoint(x: x + colWidth / 2 - 8, y: hdrY)
        ptsHdr.zPosition = 2
        addChild(ptsHdr)

        y -= 4

        for i in 0..<topN {
            y -= 16
            let entry = standings[i]
            let isPlayer = entry.teamIndex == league.playerTeamIndex

            // Alternating row background
            let rowColor = i % 2 == 0 ? RetroPalette.rowEven : RetroPalette.rowOdd
            let rowBg = SKSpriteNode(color: isPlayer ? UIColor(hex: "2A2A18") : rowColor,
                                     size: CGSize(width: colWidth - 4, height: 15))
            rowBg.position = CGPoint(x: x, y: y)
            rowBg.zPosition = 1
            addChild(rowBg)

            // Player team accent bar
            if isPlayer {
                let accentBar = SKSpriteNode(color: RetroPalette.gold,
                                            size: CGSize(width: 2, height: 13))
                accentBar.position = CGPoint(x: x - colWidth / 2 + 4, y: y)
                accentBar.zPosition = 2
                addChild(accentBar)
            }

            let color: UIColor = isPlayer ? RetroPalette.gold : RetroPalette.textGray

            // Rank
            let rankLabel = RetroFont.label("\(i + 1).", size: RetroFont.tinySize, color: color)
            rankLabel.horizontalAlignmentMode = .right
            rankLabel.position = CGPoint(x: x - colWidth / 2 + 22, y: y)
            rankLabel.zPosition = 2
            addChild(rankLabel)

            // Team abbreviation
            let abbrLabel = RetroFont.label(entry.abbreviation, size: RetroFont.tinySize, color: color)
            abbrLabel.horizontalAlignmentMode = .left
            abbrLabel.position = CGPoint(x: x - colWidth / 2 + 28, y: y)
            abbrLabel.zPosition = 2
            addChild(abbrLabel)

            // Record
            let recLabel = RetroFont.label(entry.record, size: RetroFont.tinySize, color: color)
            recLabel.position = CGPoint(x: x + 10, y: y)
            recLabel.zPosition = 2
            addChild(recLabel)

            // Points
            let ptsLabel = RetroFont.label("\(entry.points)pts", size: RetroFont.tinySize, color: color)
            ptsLabel.horizontalAlignmentMode = .right
            ptsLabel.position = CGPoint(x: x + colWidth / 2 - 8, y: y)
            ptsLabel.zPosition = 2
            addChild(ptsLabel)
        }

        // Playoff cutoff line (after 8th place)
        if topN >= 8 {
            let cutoffY = y - 2
            let cutoffLine = SKSpriteNode(color: RetroPalette.accent.withAlphaComponent(0.3),
                                          size: CGSize(width: colWidth - 12, height: 1))
            cutoffLine.position = CGPoint(x: x, y: cutoffY)
            cutoffLine.zPosition = 2
            addChild(cutoffLine)
        }

        // News section
        y -= 24
        let newsHeight: CGFloat = 110
        let newsPanel = RetroPanel(width: colWidth + 8, height: newsHeight, title: "NEWS")
        newsPanel.position = CGPoint(x: x, y: y - newsHeight / 2)
        newsPanel.zPosition = 0
        addChild(newsPanel)

        y -= 20
        let recentNews = league.recentNews
        let newsCount = min(5, recentNews.count)

        for i in 0..<newsCount {
            let event = recentNews[i]

            // Color by type
            let newsColor: UIColor
            switch event.type {
            case .injury: newsColor = RetroPalette.textRed
            case .trade: newsColor = RetroPalette.textYellow
            case .morale: newsColor = UIColor(hex: "8888CC")
            case .milestone: newsColor = RetroPalette.gold
            case .general: newsColor = RetroPalette.textGray
            }

            // News type indicator dot
            let dot = SKSpriteNode(color: newsColor, size: CGSize(width: 3, height: 3))
            dot.position = CGPoint(x: x - colWidth / 2 + 10, y: y)
            dot.zPosition = 2
            addChild(dot)

            // Truncate news message to fit panel width
            let maxMsgChars = Int((colWidth - 28) / 4.5)
            let msgText = event.message.count > maxMsgChars ? String(event.message.prefix(maxMsgChars)) + ".." : event.message
            let msgLabel = RetroFont.label(msgText, size: 7, color: newsColor)
            msgLabel.horizontalAlignmentMode = .left
            msgLabel.position = CGPoint(x: x - colWidth / 2 + 18, y: y)
            msgLabel.numberOfLines = 1
            msgLabel.zPosition = 2
            addChild(msgLabel)

            y -= 16
        }
    }

    // MARK: - Facility Upgrade

    private func upgradeFacility(type: FacilityType) {
        gm.league.playerTeam.upgradeFacility(type: type)
        gm.save()
        refreshScene()
    }

    // MARK: - Navigation

    private func playGame() {
        guard let league = gm.league else { return }

        guard let game = league.playerGameThisWeek else {
            advanceWeek()
            return
        }

        // Simulate other games first
        gm.simulateWeek()

        let scheduleIdx = league.schedule.firstIndex(where: { $0.id == game.id }) ?? 0

        guard let view = view else { return }
        GameManager.pixelTransition(from: view, toSceneType: GameplayScene.self) { gameplay in
            gameplay.homeTeam = league.teams[game.homeTeamIndex]
            gameplay.awayTeam = league.teams[game.awayTeamIndex]
            gameplay.isPlayerHome = game.homeTeamIndex == league.playerTeamIndex
            gameplay.scheduleIndex = scheduleIdx
        }
    }

    private func advanceWeek() {
        gm.advanceToNextWeek()
        refreshScene()
    }

    private func openRoster() {
        guard let view = view else { return }
        GameManager.transition(from: view, toSceneType: RosterScene.self)
    }

    private func openSchedule() {
        guard let view = view else { return }
        GameManager.transition(from: view, toSceneType: SeasonScene.self)
    }

    private func openTrade() {
        guard let view = view else { return }
        GameManager.transition(from: view, toSceneType: TradeScene.self)
    }

    private func openFreeAgency() {
        guard let view = view else { return }
        GameManager.transition(from: view, toSceneType: FreeAgencyScene.self)
    }

    private func openDraft() {
        guard let view = view else { return }
        GameManager.transition(from: view, toSceneType: DraftScene.self)
    }

    private func advanceSeason() {
        gm.league.startNewSeason()
        gm.save()
        refreshScene()
    }

    private func refreshScene() {
        guard let view = view else { return }
        GameManager.transition(from: view, toSceneType: HubScene.self)
    }
}
