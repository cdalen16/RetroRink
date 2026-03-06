import SpriteKit

// MARK: - Season Schedule & Standings Scene
class SeasonScene: BaseScene {

    private let gm = GameManager.shared
    private var currentTab: Int = 0  // 0=Schedule, 1=Standings, 2=Leaders
    private var segmentedControl: RetroSegmentedControl!
    private var scrollContainer: ScrollContainer!

    override func didMove(to view: SKView) {
        backgroundColor = RetroPalette.background
        super.didMove(to: view)

        setupHeader()
        setupTabs()
        setupScrollContainer()
        populateTab()

        let back = makeBackButton(target: self) { [weak self] in
            GameManager.transition(from: self?.view, toSceneType: HubScene.self)
        }
        back.position = CGPoint(x: safeLeft + 52, y: safeTop - 20)
        addChild(back)
    }

    // MARK: - Setup

    private func setupHeader() {
        guard let league = gm.league else { return }

        let title = RetroFont.label("SEASON \(league.seasonNumber)", size: RetroFont.headerSize, color: RetroPalette.gold)
        title.position = CGPoint(x: 40, y: safeTop - 20)
        addChild(title)

        let phaseText: String
        switch league.seasonPhase {
        case .regularSeason: phaseText = "Week \(league.currentWeek + 1) of \(GameConfig.seasonGames)"
        case .playoffs: phaseText = league.playoffBracket?.roundName ?? "Playoffs"
        case .offseason: phaseText = "Offseason"
        default: phaseText = league.seasonPhase.rawValue.capitalized
        }

        let subtitle = RetroFont.label(phaseText, size: RetroFont.smallSize, color: RetroPalette.textGray)
        subtitle.position = CGPoint(x: 40, y: safeTop - 42)
        addChild(subtitle)
    }

    private func setupTabs() {
        segmentedControl = RetroSegmentedControl(items: ["SCHEDULE", "STANDINGS", "LEADERS"], width: 420, height: 28)
        segmentedControl.position = CGPoint(x: 0, y: safeTop - 66)
        segmentedControl.onSelectionChanged = { [weak self] index in
            self?.currentTab = index
            self?.populateTab()
        }
        addChild(segmentedControl)
    }

    private func setupScrollContainer() {
        let containerHeight = safeHeight - 100
        scrollContainer = ScrollContainer(width: safeWidth - 20, height: containerHeight)
        scrollContainer.position = CGPoint(x: 0, y: -10)
        addChild(scrollContainer)
    }

    private func populateTab() {
        scrollContainer.clearContent()

        switch currentTab {
        case 0: buildSchedule()
        case 1: buildStandings()
        case 2: buildLeaders()
        default: break
        }
    }

    // MARK: - Schedule Tab

    private func buildSchedule() {
        guard let league = gm.league else { return }

        let playerGames = league.schedule.filter {
            $0.homeTeamIndex == league.playerTeamIndex || $0.awayTeamIndex == league.playerTeamIndex
        }.sorted { $0.week < $1.week }

        let rowHeight: CGFloat = 28
        let containerW = safeWidth - 20
        let topY = scrollContainer.containerHeight / 2 - 14

        // Column headers
        let headerRow = SKNode()
        let headerTexts = ["WK", "OPPONENT", "RESULT"]
        let headerXs: [CGFloat] = [-containerW / 2 + 20, -containerW / 2 + 70, containerW / 2 - 100]
        for (text, x) in zip(headerTexts, headerXs) {
            let label = RetroFont.label(text, size: RetroFont.tinySize, color: RetroPalette.gold)
            label.position = CGPoint(x: x, y: 0)
            label.horizontalAlignmentMode = .left
            headerRow.addChild(label)
        }
        scrollContainer.addScrollContent(headerRow, at: topY)

        for (i, game) in playerGames.enumerated() {
            let y = topY - CGFloat(i + 1) * rowHeight
            let isHome = game.homeTeamIndex == league.playerTeamIndex
            let opponentIndex = isHome ? game.awayTeamIndex : game.homeTeamIndex
            let opponent = league.teams[opponentIndex]

            let isCurrent = game.week == league.currentWeek && !game.isPlayed

            let row = SKNode()

            // Highlight current week
            if isCurrent {
                let highlight = SKSpriteNode(color: RetroPalette.accent.withAlphaComponent(0.15),
                                              size: CGSize(width: containerW - 10, height: rowHeight - 2))
                highlight.zPosition = 0
                row.addChild(highlight)
            }

            // Week number
            let weekLabel = RetroFont.label("\(game.week + 1)", size: RetroFont.tinySize,
                                             color: isCurrent ? RetroPalette.accent : RetroPalette.textGray)
            weekLabel.position = CGPoint(x: headerXs[0], y: 0)
            weekLabel.horizontalAlignmentMode = .left
            row.addChild(weekLabel)

            // Opponent
            let prefix = isHome ? "vs" : "@"
            let oppText = "\(prefix) \(opponent.abbreviation) \(opponent.fullName)"
            let oppLabel = RetroFont.label(oppText, size: RetroFont.tinySize,
                                            color: isCurrent ? .white : RetroPalette.textGray)
            oppLabel.position = CGPoint(x: headerXs[1], y: 0)
            oppLabel.horizontalAlignmentMode = .left
            row.addChild(oppLabel)

            // Result
            if let result = game.result {
                let playerScore = isHome ? result.homeScore : result.awayScore
                let oppScore = isHome ? result.awayScore : result.homeScore
                let won = playerScore > oppScore
                let resultText = "\(won ? "W" : "L") \(playerScore)-\(oppScore)\(result.overtime ? " OT" : "")"
                let resultColor = won ? RetroPalette.textGreen : RetroPalette.textRed
                let resultLabel = RetroFont.label(resultText, size: RetroFont.tinySize, color: resultColor)
                resultLabel.position = CGPoint(x: headerXs[2], y: 0)
                resultLabel.horizontalAlignmentMode = .left
                row.addChild(resultLabel)
            } else if isCurrent {
                let nextLabel = RetroFont.label("NEXT >>", size: RetroFont.tinySize, color: RetroPalette.textYellow)
                nextLabel.position = CGPoint(x: headerXs[2], y: 0)
                nextLabel.horizontalAlignmentMode = .left
                row.addChild(nextLabel)
            } else {
                let vsLabel = RetroFont.label("vs \(opponent.abbreviation)", size: RetroFont.tinySize, color: UIColor(hex: "555577"))
                vsLabel.position = CGPoint(x: headerXs[2], y: 0)
                vsLabel.horizontalAlignmentMode = .left
                row.addChild(vsLabel)
            }

            scrollContainer.addScrollContent(row, at: y)
        }

        let totalHeight = CGFloat(playerGames.count + 2) * rowHeight
        scrollContainer.setContentHeight(totalHeight)
    }

    // MARK: - Standings Tab

    private func buildStandings() {
        guard let league = gm.league else { return }

        let rowHeight: CGFloat = 22
        let containerW = safeWidth - 20
        let topY = scrollContainer.containerHeight / 2 - 14

        // Headers
        let headers = ["#", "TEAM", "W", "L", "OTL", "PTS"]
        let xs: [CGFloat] = [
            -containerW / 2 + 20,
            -containerW / 2 + 50,
            containerW / 2 - 180,
            containerW / 2 - 140,
            containerW / 2 - 95,
            containerW / 2 - 40
        ]

        let headerRow = SKNode()
        for (text, x) in zip(headers, xs) {
            let label = RetroFont.label(text, size: RetroFont.tinySize, color: RetroPalette.gold)
            label.position = CGPoint(x: x, y: 0)
            label.horizontalAlignmentMode = .left
            headerRow.addChild(label)
        }
        scrollContainer.addScrollContent(headerRow, at: topY)

        let standings = league.standings
        for (i, entry) in standings.enumerated() {
            let y = topY - CGFloat(i + 1) * rowHeight
            let isPlayer = entry.teamIndex == league.playerTeamIndex
            let isPlayoff = i < GameConfig.playoffTeams
            let color: UIColor = isPlayer ? RetroPalette.gold : (isPlayoff ? .white : RetroPalette.textGray)

            let row = SKNode()

            // Highlight player's team
            if isPlayer {
                let highlight = SKSpriteNode(color: RetroPalette.gold.withAlphaComponent(0.1),
                                              size: CGSize(width: containerW - 10, height: rowHeight - 2))
                highlight.zPosition = 0
                row.addChild(highlight)
            }

            let values: [(String, CGFloat)] = [
                ("\(i + 1)", xs[0]),
                (entry.abbreviation, xs[1]),
                ("\(entry.wins)", xs[2]),
                ("\(entry.losses)", xs[3]),
                ("\(entry.otLosses)", xs[4]),
                ("\(entry.points)", xs[5]),
            ]

            for (text, x) in values {
                let label = RetroFont.label(text, size: RetroFont.tinySize, color: color)
                label.position = CGPoint(x: x, y: 0)
                label.horizontalAlignmentMode = .left
                row.addChild(label)
            }

            scrollContainer.addScrollContent(row, at: y)

            // Playoff cutoff line
            if i == GameConfig.playoffTeams - 1 {
                let line = SKSpriteNode(color: RetroPalette.accent.withAlphaComponent(0.3),
                                         size: CGSize(width: containerW - 40, height: 1))
                line.zPosition = 0
                scrollContainer.addScrollContent(line, at: y - rowHeight / 2)
            }
        }

        let totalHeight = CGFloat(standings.count + 2) * rowHeight
        scrollContainer.setContentHeight(totalHeight)
    }

    // MARK: - Leaders Tab

    private func buildLeaders() {
        guard let league = gm.league else { return }

        let rowHeight: CGFloat = 22
        let containerW = safeWidth - 20
        let topY = scrollContainer.containerHeight / 2 - 14

        // Gather all skaters across all teams
        struct ScorerEntry {
            let name: String
            let teamAbbr: String
            let goals: Int
            let assists: Int
            let points: Int
        }

        var scorers: [ScorerEntry] = []
        for team in league.teams {
            for player in team.roster where !player.position.isGoalie {
                if player.seasonGoals > 0 || player.seasonAssists > 0 {
                    scorers.append(ScorerEntry(
                        name: player.shortName,
                        teamAbbr: team.abbreviation,
                        goals: player.seasonGoals,
                        assists: player.seasonAssists,
                        points: player.points
                    ))
                }
            }
        }
        scorers.sort { $0.points > $1.points }

        // Section: Top Scorers
        let scorerTitle = RetroFont.label("TOP SCORERS", size: RetroFont.smallSize, color: RetroPalette.gold)
        scorerTitle.horizontalAlignmentMode = .left
        scorerTitle.position.x = -containerW / 2 + 20
        scrollContainer.addScrollContent(scorerTitle, at: topY)

        // Headers
        let headerRow = SKNode()
        let headers = ["#", "PLAYER", "TEAM", "G", "A", "PTS"]
        let hxs: [CGFloat] = [
            -containerW / 2 + 20,
            -containerW / 2 + 50,
            containerW / 2 - 200,
            containerW / 2 - 140,
            containerW / 2 - 95,
            containerW / 2 - 40
        ]
        for (text, x) in zip(headers, hxs) {
            let label = RetroFont.label(text, size: RetroFont.tinySize, color: RetroPalette.textGray)
            label.position = CGPoint(x: x, y: 0)
            label.horizontalAlignmentMode = .left
            headerRow.addChild(label)
        }
        scrollContainer.addScrollContent(headerRow, at: topY - rowHeight)

        let displayCount = min(15, scorers.count)
        for i in 0..<displayCount {
            let entry = scorers[i]
            let y = topY - CGFloat(i + 2) * rowHeight

            let row = SKNode()
            let isPlayerTeam = entry.teamAbbr == league.playerTeam.abbreviation
            let color: UIColor = isPlayerTeam ? RetroPalette.gold : .white

            let values: [(String, CGFloat)] = [
                ("\(i + 1)", hxs[0]),
                (entry.name, hxs[1]),
                (entry.teamAbbr, hxs[2]),
                ("\(entry.goals)", hxs[3]),
                ("\(entry.assists)", hxs[4]),
                ("\(entry.points)", hxs[5]),
            ]
            for (text, x) in values {
                let label = RetroFont.label(text, size: RetroFont.tinySize, color: color)
                label.position = CGPoint(x: x, y: 0)
                label.horizontalAlignmentMode = .left
                row.addChild(label)
            }
            scrollContainer.addScrollContent(row, at: y)
        }

        // Section: Top Goalies
        let goalieStartY = topY - CGFloat(displayCount + 3) * rowHeight

        struct GoalieEntry {
            let name: String
            let teamAbbr: String
            let gamesPlayed: Int
            let gaa: Double
            let svPct: Double
        }

        var goalieEntries: [GoalieEntry] = []
        for team in league.teams {
            for player in team.roster where player.position.isGoalie && player.seasonGamesPlayed > 0 {
                goalieEntries.append(GoalieEntry(
                    name: player.shortName,
                    teamAbbr: team.abbreviation,
                    gamesPlayed: player.seasonGamesPlayed,
                    gaa: player.goalieGAA,
                    svPct: player.goalieSavePercentage
                ))
            }
        }
        goalieEntries.sort { $0.svPct > $1.svPct }

        let goalieTitle = RetroFont.label("TOP GOALIES", size: RetroFont.smallSize, color: RetroPalette.gold)
        goalieTitle.horizontalAlignmentMode = .left
        goalieTitle.position.x = -containerW / 2 + 20
        scrollContainer.addScrollContent(goalieTitle, at: goalieStartY)

        let gHeaderRow = SKNode()
        let gHeaders = ["#", "PLAYER", "TEAM", "GP", "GAA", "SV%"]
        for (text, x) in zip(gHeaders, hxs) {
            let label = RetroFont.label(text, size: RetroFont.tinySize, color: RetroPalette.textGray)
            label.position = CGPoint(x: x, y: 0)
            label.horizontalAlignmentMode = .left
            gHeaderRow.addChild(label)
        }
        scrollContainer.addScrollContent(gHeaderRow, at: goalieStartY - rowHeight)

        let goalieDisplayCount = min(10, goalieEntries.count)
        for i in 0..<goalieDisplayCount {
            let entry = goalieEntries[i]
            let y = goalieStartY - CGFloat(i + 2) * rowHeight

            let row = SKNode()
            let isPlayerTeam = entry.teamAbbr == league.playerTeam.abbreviation
            let color: UIColor = isPlayerTeam ? RetroPalette.gold : .white

            let gaaStr = String(format: "%.2f", entry.gaa)
            let svStr = String(format: ".%03d", Int(entry.svPct * 1000))

            let values: [(String, CGFloat)] = [
                ("\(i + 1)", hxs[0]),
                (entry.name, hxs[1]),
                (entry.teamAbbr, hxs[2]),
                ("\(entry.gamesPlayed)", hxs[3]),
                (gaaStr, hxs[4]),
                (svStr, hxs[5]),
            ]
            for (text, x) in values {
                let label = RetroFont.label(text, size: RetroFont.tinySize, color: color)
                label.position = CGPoint(x: x, y: 0)
                label.horizontalAlignmentMode = .left
                row.addChild(label)
            }
            scrollContainer.addScrollContent(row, at: y)
        }

        let totalHeight = CGFloat(displayCount + goalieDisplayCount + 6) * rowHeight
        scrollContainer.setContentHeight(totalHeight)
    }
}
