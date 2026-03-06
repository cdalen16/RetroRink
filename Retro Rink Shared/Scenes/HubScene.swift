import SpriteKit

// MARK: - Team Hub Scene (Main Management Screen)
class HubScene: BaseScene {

    private let gm = GameManager.shared

    override func didMove(to view: SKView) {
        backgroundColor = RetroPalette.background
        super.didMove(to: view)

        guard gm.league != nil else { return }

        setupMenuButton()
        setupLeftColumn()
        setupCenterColumn()
        setupRightColumn()
    }

    // MARK: - Layout Constants

    private var leftColX: CGFloat { safeLeft + safeWidth * 0.17 }
    private var centerColX: CGFloat { 0 }
    private var rightColX: CGFloat { safeRight - safeWidth * 0.17 }
    private var colWidth: CGFloat { safeWidth * 0.28 }

    // MARK: - Menu Button

    private func setupMenuButton() {
        let menuBtn = RetroButton(text: "MENU", width: 80, height: 28,
                                  color: UIColor(hex: "333344"), borderColor: UIColor(hex: "555577"),
                                  fontSize: RetroFont.tinySize)
        menuBtn.position = CGPoint(x: safeLeft + 47, y: safeTop - 20)
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
        var y = safeTop - 20

        // Team name
        let teamName = RetroFont.label(team.fullName.uppercased(), size: RetroFont.bodySize, color: team.colors.primaryColor)
        teamName.position = CGPoint(x: x, y: y)
        addChild(teamName)

        // Record
        y -= 18
        let record = RetroFont.label(team.record, size: RetroFont.bodySize, color: .white)
        record.position = CGPoint(x: x, y: y)
        addChild(record)

        // Season info
        y -= 16
        let seasonInfo = RetroFont.label(
            "Season \(league.seasonNumber) | Week \(league.currentWeek + 1)/\(GameConfig.seasonGames)",
            size: RetroFont.tinySize, color: RetroPalette.textGray
        )
        seasonInfo.position = CGPoint(x: x, y: y)
        addChild(seasonInfo)

        // Panel background
        y -= 10
        let panelHeight: CGFloat = 100
        let panel = RetroPanel(width: colWidth, height: panelHeight)
        panel.position = CGPoint(x: x, y: y - panelHeight / 2)
        addChild(panel)

        // OVR
        y -= 18
        let ovrLabel = RetroFont.label("OVR: \(team.teamOverall)", size: RetroFont.bodySize, color: RetroPalette.textGreen)
        ovrLabel.position = CGPoint(x: x, y: y)
        addChild(ovrLabel)

        // Roster count
        y -= 16
        let rosterLabel = RetroFont.label("Roster: \(team.roster.count)/\(GameConfig.maxRosterSize)",
                                          size: RetroFont.tinySize, color: .white)
        rosterLabel.position = CGPoint(x: x, y: y)
        addChild(rosterLabel)

        // Salary cap bar
        y -= 14
        let capText = "Cap: $\(team.totalSalary / 1_000_000)M / $\(GameConfig.salaryCap / 1_000_000)M"
        let capLabel = RetroFont.label(capText, size: RetroFont.tinySize, color: RetroPalette.textGray)
        capLabel.position = CGPoint(x: x, y: y)
        addChild(capLabel)

        y -= 12
        let capBar = RetroProgressBar(width: colWidth - 20)
        capBar.position = CGPoint(x: x, y: y)
        capBar.progress = CGFloat(team.capUsagePercent)
        addChild(capBar)

        // Coaching credits
        y -= 16
        let creditsLabel = RetroFont.label("Coaching Credits: \(team.coachingCredits)",
                                           size: RetroFont.tinySize, color: RetroPalette.gold)
        creditsLabel.position = CGPoint(x: x, y: y)
        addChild(creditsLabel)

        // Facilities section
        y -= 26
        let facTitle = RetroFont.label("FACILITIES", size: RetroFont.tinySize, color: RetroPalette.gold)
        facTitle.position = CGPoint(x: x, y: y)
        addChild(facTitle)

        for facility in team.facilities {
            y -= 22
            let levelText = "Lv.\(facility.level)"
            let facLabel = RetroFont.label("\(facility.type.name): \(levelText)",
                                          size: RetroFont.tinySize, color: .white)
            facLabel.horizontalAlignmentMode = .left
            facLabel.position = CGPoint(x: x - colWidth / 2 + 8, y: y)
            addChild(facLabel)

            if facility.canUpgrade {
                let cost = facility.upgradeCost
                let canAfford = team.coachingCredits >= cost
                let upgradeBtn = RetroButton(
                    text: "UP (\(cost)CC)",
                    width: 64, height: 18,
                    color: canAfford ? UIColor(hex: "225522") : UIColor(hex: "332222"),
                    borderColor: canAfford ? RetroPalette.textGreen : UIColor(hex: "554444"),
                    fontSize: 7
                )
                upgradeBtn.position = CGPoint(x: x + colWidth / 2 - 40, y: y)
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
        var y: CGFloat = safeTop - 40

        // PLAY GAME (large accent button)
        let hasGame = league.playerGameThisWeek != nil
        let playBtn = RetroButton(
            text: hasGame ? "PLAY GAME" : "ADVANCE WEEK",
            width: 200, height: 48,
            color: RetroPalette.midPanel, borderColor: RetroPalette.accent,
            fontSize: RetroFont.headerSize
        )
        playBtn.position = CGPoint(x: x, y: y)
        playBtn.action = { [weak self] in
            if hasGame {
                self?.playGame()
            } else {
                self?.advanceWeek()
            }
        }
        addChild(playBtn)

        // Secondary buttons
        let buttons: [(String, () -> Void)] = [
            ("ROSTER", { [weak self] in self?.openRoster() }),
            ("SCHEDULE", { [weak self] in self?.openSchedule() }),
            ("TRADE", { [weak self] in self?.openTrade() }),
            ("FREE AGENTS", { [weak self] in self?.openFreeAgency() }),
        ]

        y -= 46
        for (text, action) in buttons {
            let btn = RetroButton(text: text, width: 160, height: 36,
                                  color: UIColor(hex: "222233"), borderColor: UIColor(hex: "444466"))
            btn.position = CGPoint(x: x, y: y)
            btn.action = action
            addChild(btn)
            y -= 42
        }
    }

    private func setupOffseasonButtons(x: CGFloat) {
        var y: CGFloat = safeTop - 40

        let offseasonLabel = RetroFont.label("OFFSEASON", size: RetroFont.headerSize, color: RetroPalette.gold)
        offseasonLabel.position = CGPoint(x: x, y: y)
        addChild(offseasonLabel)

        let buttons: [(String, Bool, () -> Void)] = [
            ("DRAFT", false, { [weak self] in self?.openDraft() }),
            ("FREE AGENCY", false, { [weak self] in self?.openFreeAgency() }),
            ("ROSTER", false, { [weak self] in self?.openRoster() }),
            ("NEXT SEASON", true, { [weak self] in self?.advanceSeason() }),
        ]

        y -= 36
        for (text, isPrimary, action) in buttons {
            let btn = RetroButton(
                text: text,
                width: isPrimary ? 200 : 160,
                height: isPrimary ? 44 : 36,
                color: isPrimary ? UIColor(hex: "225522") : UIColor(hex: "222233"),
                borderColor: isPrimary ? RetroPalette.textGreen : UIColor(hex: "444466"),
                fontSize: isPrimary ? RetroFont.bodySize : RetroFont.bodySize
            )
            btn.position = CGPoint(x: x, y: y)
            btn.action = action
            addChild(btn)
            y -= 44
        }
    }

    // MARK: - Right Column: Standings + News

    private func setupRightColumn() {
        guard let league = gm.league else { return }
        let x = rightColX
        var y = safeTop - 20

        // Standings panel
        let standingsHeight: CGFloat = 170
        let standingsPanel = RetroPanel(width: colWidth, height: standingsHeight, title: "STANDINGS")
        standingsPanel.position = CGPoint(x: x, y: y - standingsHeight / 2)
        addChild(standingsPanel)

        let standings = league.standings
        let topN = min(8, standings.count)
        y -= 36

        for i in 0..<topN {
            let entry = standings[i]
            let isPlayer = entry.teamIndex == league.playerTeamIndex
            let color: UIColor = isPlayer ? RetroPalette.gold : RetroPalette.textGray

            // Rank + abbreviation
            let rankText = "\(i + 1)."
            let rankLabel = RetroFont.label(rankText, size: RetroFont.tinySize, color: color)
            rankLabel.horizontalAlignmentMode = .right
            rankLabel.position = CGPoint(x: x - colWidth / 2 + 22, y: y)
            addChild(rankLabel)

            let abbrLabel = RetroFont.label(entry.abbreviation, size: RetroFont.tinySize, color: color)
            abbrLabel.horizontalAlignmentMode = .left
            abbrLabel.position = CGPoint(x: x - colWidth / 2 + 28, y: y)
            addChild(abbrLabel)

            // Record
            let recLabel = RetroFont.label(entry.record, size: RetroFont.tinySize, color: color)
            recLabel.position = CGPoint(x: x + 10, y: y)
            addChild(recLabel)

            // Points
            let ptsLabel = RetroFont.label("\(entry.points)pts", size: RetroFont.tinySize, color: color)
            ptsLabel.horizontalAlignmentMode = .right
            ptsLabel.position = CGPoint(x: x + colWidth / 2 - 8, y: y)
            addChild(ptsLabel)

            y -= 16
        }

        // News section
        y -= 16
        let newsHeight: CGFloat = 100
        let newsPanel = RetroPanel(width: colWidth, height: newsHeight, title: "NEWS")
        newsPanel.position = CGPoint(x: x, y: y - newsHeight / 2)
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

            let msgLabel = RetroFont.label(event.message, size: 7, color: newsColor)
            msgLabel.position = CGPoint(x: x, y: y)
            msgLabel.preferredMaxLayoutWidth = colWidth - 16
            msgLabel.numberOfLines = 1
            addChild(msgLabel)

            y -= 14
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
