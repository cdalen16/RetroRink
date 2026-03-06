import SpriteKit

// MARK: - Post-Game Results Scene
class PostGameScene: BaseScene {

    var gameResult: GameResult!
    var homeTeam: Team!
    var awayTeam: Team!
    var scheduleIndex: Int = 0

    private var isPlayerHome: Bool = false
    private var playerWon: Bool = false
    private var creditsEarned: Int = 0

    override func didMove(to view: SKView) {
        backgroundColor = RetroPalette.background
        super.didMove(to: view)

        let playerTeamIndex = GameManager.shared.playerTeamIndex
        isPlayerHome = homeTeam.id == GameManager.shared.league.teams[playerTeamIndex].id
        let playerScore = isPlayerHome ? gameResult.homeScore : gameResult.awayScore
        let oppScore = isPlayerHome ? gameResult.awayScore : gameResult.homeScore
        playerWon = playerScore > oppScore

        // Record the result
        GameManager.shared.recordPlayerGame(scheduleIndex: scheduleIndex, result: gameResult)

        // Calculate coaching credits (match GameManager logic)
        creditsEarned = calculateCreditsEarned()

        setupFinalHeader()
        setupScoreDisplay()
        setupResultLabel()
        setupThreeStars()
        setupCoachingCredits()
        setupScoringSummary()
        setupContinueButton()
    }

    // MARK: - Final Header

    private func setupFinalHeader() {
        let isOT = gameResult.overtime
        let finalLabel = RetroFont.label(isOT ? "FINAL (OT)" : "FINAL", size: RetroFont.bodySize, color: RetroPalette.textGray)
        finalLabel.position = CGPoint(x: 0, y: safeTop - 22)
        addChild(finalLabel)
    }

    // MARK: - Score Display

    private func setupScoreDisplay() {
        let teamSpread = min(120, safeWidth * 0.18)

        // Home team name
        let homeNameLabel = RetroFont.label(homeTeam.abbreviation, size: RetroFont.headerSize, color: homeTeam.colors.primaryColor)
        homeNameLabel.position = CGPoint(x: -teamSpread, y: safeTop - 55)
        addChild(homeNameLabel)

        // Home team full name below abbreviation
        let homeFullLabel = RetroFont.label(homeTeam.fullName, size: RetroFont.tinySize, color: homeTeam.colors.primaryColor)
        homeFullLabel.position = CGPoint(x: -teamSpread, y: safeTop - 72)
        homeFullLabel.alpha = 0.7
        addChild(homeFullLabel)

        // Score
        let scoreText = "\(gameResult.homeScore)  -  \(gameResult.awayScore)"
        let scoreLabel = RetroFont.label(scoreText, size: 38, color: .white)
        scoreLabel.position = CGPoint(x: 0, y: safeTop - 58)
        addChild(scoreLabel)

        // Away team name
        let awayNameLabel = RetroFont.label(awayTeam.abbreviation, size: RetroFont.headerSize, color: awayTeam.colors.primaryColor)
        awayNameLabel.position = CGPoint(x: teamSpread, y: safeTop - 55)
        addChild(awayNameLabel)

        let awayFullLabel = RetroFont.label(awayTeam.fullName, size: RetroFont.tinySize, color: awayTeam.colors.primaryColor)
        awayFullLabel.position = CGPoint(x: teamSpread, y: safeTop - 72)
        awayFullLabel.alpha = 0.7
        addChild(awayFullLabel)

        // Animated entrance for score
        scoreLabel.setScale(0)
        scoreLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.3),
            SKAction.scale(to: 1.0, duration: 0.3)
        ]))
    }

    // MARK: - Victory/Defeat

    private func setupResultLabel() {
        let resultLabel = RetroFont.label(
            playerWon ? "VICTORY!" : "DEFEAT",
            size: RetroFont.headerSize,
            color: playerWon ? RetroPalette.textGreen : RetroPalette.textRed
        )
        resultLabel.position = CGPoint(x: 0, y: safeTop - 98)
        addChild(resultLabel)

        // Animated fade-in
        resultLabel.alpha = 0
        resultLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.6),
            SKAction.fadeIn(withDuration: 0.3)
        ]))

        // Glow pulse for victory
        if playerWon {
            let glow = RetroFont.label("VICTORY!", size: RetroFont.headerSize, color: RetroPalette.textGreen)
            glow.position = resultLabel.position
            glow.alpha = 0
            addChild(glow)

            glow.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.9),
                SKAction.repeatForever(SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.3, duration: 0.8),
                    SKAction.fadeAlpha(to: 0.0, duration: 0.8),
                ]))
            ]))
        }
    }

    // MARK: - Three Stars

    private func setupThreeStars() {
        let allPlayers = homeTeam.roster + awayTeam.roster

        // Gather points/performance for this game
        struct PerformanceEntry {
            let player: Player
            let teamAbbr: String
            let goals: Int
            let assists: Int
            let points: Int
        }

        var performances: [UUID: PerformanceEntry] = [:]

        for event in gameResult.scorers {
            let team = event.teamIndex == 0 ? homeTeam! : awayTeam!
            let teamAbbr = team.abbreviation

            // Scorer
            if let player = allPlayers.first(where: { $0.id == event.scorerID }) {
                let existing = performances[player.id]
                performances[player.id] = PerformanceEntry(
                    player: player,
                    teamAbbr: teamAbbr,
                    goals: (existing?.goals ?? 0) + 1,
                    assists: existing?.assists ?? 0,
                    points: (existing?.points ?? 0) + 1
                )
            }

            // Assists
            for assistID in [event.assist1ID, event.assist2ID].compactMap({ $0 }) {
                if let player = allPlayers.first(where: { $0.id == assistID }) {
                    let existing = performances[player.id]
                    performances[player.id] = PerformanceEntry(
                        player: player,
                        teamAbbr: team.abbreviation,
                        goals: existing?.goals ?? 0,
                        assists: (existing?.assists ?? 0) + 1,
                        points: (existing?.points ?? 0) + 1
                    )
                }
            }
        }

        let topPerformers = Array(performances.values).sorted { $0.points > $1.points }.prefix(3)

        guard !topPerformers.isEmpty else { return }

        let starsLeftX = safeLeft + 20

        let starsTitle = RetroFont.label("THREE STARS", size: RetroFont.smallSize, color: RetroPalette.gold)
        starsTitle.horizontalAlignmentMode = .left
        starsTitle.position = CGPoint(x: starsLeftX, y: safeTop - 128)
        addChild(starsTitle)

        for (i, perf) in topPerformers.enumerated() {
            let y: CGFloat = safeTop - 152 - CGFloat(i) * 24
            let starCount = 3 - i  // 3 stars, 2 stars, 1 star

            // Star icons
            let starsNode = SKNode()
            for s in 0..<starCount {
                let starSprite = SKSpriteNode(texture: PixelArt.starTexture(filled: true))
                starSprite.position = CGPoint(x: CGFloat(s) * 14, y: 0)
                starSprite.setScale(0.6)
                starsNode.addChild(starSprite)
            }
            starsNode.position = CGPoint(x: starsLeftX, y: y)
            addChild(starsNode)

            // Player name and stats
            let statLine = "\(perf.player.shortName) (\(perf.teamAbbr)) - \(perf.goals)G \(perf.assists)A"
            let statLabel = RetroFont.label(statLine, size: RetroFont.tinySize, color: .white)
            statLabel.horizontalAlignmentMode = .left
            statLabel.position = CGPoint(x: starsLeftX + 50, y: y)
            addChild(statLabel)

            // Animate stat lines appearing one by one
            statLabel.alpha = 0
            starsNode.alpha = 0
            let delay = 1.0 + Double(i) * 0.4
            statLabel.run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.fadeIn(withDuration: 0.3)
            ]))
            starsNode.run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.fadeIn(withDuration: 0.3)
            ]))
        }
    }

    // MARK: - Coaching Credits

    private func setupCoachingCredits() {
        guard playerWon else { return }

        let creditsX = safeRight - 80

        let ccLabel = RetroFont.label("+\(creditsEarned) CC", size: RetroFont.headerSize, color: RetroPalette.gold)
        ccLabel.position = CGPoint(x: creditsX, y: safeTop - 128)
        addChild(ccLabel)

        // Breakdown
        var breakdown: [String] = []
        let isPlayoffs = GameManager.shared.league.seasonPhase == .playoffs
        breakdown.append(isPlayoffs ? "Playoff Win: +2" : "Win: +1")

        let opponentScore = isPlayerHome ? gameResult.awayScore : gameResult.homeScore
        if opponentScore == 0 {
            breakdown.append("Shutout: +1")
        }

        let arenaBonus = GameManager.shared.league.playerTeam.ccEarnBonus
        if arenaBonus > 0 {
            breakdown.append("Arena Bonus: +\(arenaBonus)")
        }

        for (i, text) in breakdown.enumerated() {
            let label = RetroFont.label(text, size: RetroFont.tinySize, color: RetroPalette.textGray)
            label.position = CGPoint(x: creditsX, y: safeTop - 150 - CGFloat(i) * 16)
            addChild(label)
        }

        // Animated entrance
        ccLabel.alpha = 0
        ccLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.fadeIn(withDuration: 0.3),
            SKAction.sequence([
                SKAction.scale(to: 1.15, duration: 0.15),
                SKAction.scale(to: 1.0, duration: 0.15),
            ])
        ]))
    }

    // MARK: - Scoring Summary

    private func setupScoringSummary() {
        let startY: CGFloat = -10
        let rowHeight: CGFloat = 18
        let leftX = safeLeft + 20

        let title = RetroFont.label("SCORING SUMMARY", size: RetroFont.smallSize, color: RetroPalette.gold)
        title.position = CGPoint(x: 0, y: startY + 24)
        addChild(title)

        if gameResult.scorers.isEmpty {
            let noGoals = RetroFont.label("No goals scored", size: RetroFont.tinySize, color: RetroPalette.textGray)
            noGoals.position = CGPoint(x: 0, y: startY)
            addChild(noGoals)
            return
        }

        // Group by period
        var lastPeriod = 0
        var yOffset: CGFloat = 0

        for (i, event) in gameResult.scorers.prefix(10).enumerated() {
            // Period header
            if event.period != lastPeriod {
                lastPeriod = event.period
                let periodStr = event.period <= 3 ? "PERIOD \(event.period)" : "OVERTIME"
                let periodLabel = RetroFont.label(periodStr, size: RetroFont.tinySize, color: RetroPalette.textGray)
                periodLabel.position = CGPoint(x: leftX, y: startY - yOffset)
                periodLabel.horizontalAlignmentMode = .left
                addChild(periodLabel)
                yOffset += rowHeight
            }

            let y = startY - yOffset
            let team = event.teamIndex == 0 ? homeTeam! : awayTeam!
            let allPlayers = team.roster

            let scorerName = allPlayers.first(where: { $0.id == event.scorerID })?.shortName ?? "Unknown"
            let assistNames: [String] = [event.assist1ID, event.assist2ID].compactMap { aid in
                guard let id = aid else { return nil }
                return allPlayers.first(where: { $0.id == id })?.shortName
            }

            var text = "\(team.abbreviation): \(scorerName)"
            if !assistNames.isEmpty {
                text += " (A: \(assistNames.joined(separator: ", ")))"
            }
            if event.isPowerPlay { text += " PP" }

            let goalColor = event.teamIndex == 0 ? homeTeam.colors.primaryColor : awayTeam.colors.primaryColor
            let label = RetroFont.label(text, size: RetroFont.tinySize, color: goalColor)
            label.position = CGPoint(x: 0, y: y)
            addChild(label)

            // Animate appearance
            label.alpha = 0
            let delay = 1.5 + Double(i) * 0.2
            label.run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.fadeIn(withDuration: 0.2)
            ]))

            yOffset += rowHeight
        }
    }

    // MARK: - Continue Button

    private func setupContinueButton() {
        let btn = RetroButton(text: "CONTINUE", width: 180, height: 44,
                               color: RetroPalette.midPanel, borderColor: RetroPalette.accent)
        btn.position = CGPoint(x: 0, y: safeBottom + 32)
        btn.action = { [weak self] in
            // Advance week
            GameManager.shared.advanceToNextWeek()
            GameManager.transition(from: self?.view, toSceneType: HubScene.self)
        }
        addChild(btn)

        // Fade in continue button after animations
        btn.alpha = 0
        btn.run(SKAction.sequence([
            SKAction.wait(forDuration: 3.0),
            SKAction.fadeIn(withDuration: 0.3)
        ]))
    }

    // MARK: - Credits Calculation

    private func calculateCreditsEarned() -> Int {
        guard playerWon else { return 0 }

        var credits = 0
        let isPlayoffs = GameManager.shared.league.seasonPhase == .playoffs
        credits += isPlayoffs ? 2 : 1

        let opponentScore = isPlayerHome ? gameResult.awayScore : gameResult.homeScore
        if opponentScore == 0 {
            credits += 1
        }

        credits += GameManager.shared.league.playerTeam.ccEarnBonus
        return credits
    }
}
