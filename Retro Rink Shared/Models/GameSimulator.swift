import Foundation

// MARK: - Game Simulator (for AI vs AI games)
struct GameSimulator {

    static func simulate(home: Team, away: Team, difficulty: Difficulty = .pro) -> GameResult {
        // Weight scoring by forward line quality (top 6 forwards) instead of just team overall
        let homeForwardStrength = forwardLineStrength(for: home)
        let awayForwardStrength = forwardLineStrength(for: away)

        let homeDefenseStrength = defenseStrength(for: home)
        let awayDefenseStrength = defenseStrength(for: away)

        let homeGoalieStrength = goalieStrength(for: home)
        let awayGoalieStrength = goalieStrength(for: away)

        // Combined strength: offense matters most, defense and goalie reduce opponent scoring
        let homeStrength = homeForwardStrength * 0.5 + homeDefenseStrength * 0.25 + homeGoalieStrength * 0.25
        let awayStrength = awayForwardStrength * 0.5 + awayDefenseStrength * 0.25 + awayGoalieStrength * 0.25

        // Factor in training facility: each level above 1 gives +1% stat bonus in sim
        let homeTrainingBonus = 1.0 + Double(max(0, home.trainingFacilityLevel - 1)) * 0.01
        let awayTrainingBonus = 1.0 + Double(max(0, away.trainingFacilityLevel - 1)) * 0.01

        let adjustedHome = homeStrength * homeTrainingBonus
        let adjustedAway = awayStrength * awayTrainingBonus

        // Factor in team morale average (+-5% win chance)
        let homeMorale = averageMorale(for: home)
        let awayMorale = averageMorale(for: away)
        let homeMoraleBonus = (homeMorale - 50.0) / 50.0 * 0.05   // -5% to +5%
        let awayMoraleBonus = (awayMorale - 50.0) / 50.0 * 0.05

        let total = adjustedHome + adjustedAway
        guard total > 0 else {
            return GameResult(homeScore: 0, awayScore: 0, overtime: false, scorers: [], starPlayerID: nil)
        }

        // Home advantage + morale
        let homeWinChance = (adjustedHome / total) * 0.55 + 0.225 + homeMoraleBonus - awayMoraleBonus
        let clampedHomeChance = max(0.15, min(0.85, homeWinChance))

        var homeScore = 0
        var awayScore = 0
        var scorers: [GoalEvent] = []

        for period in 1...3 {
            let homeGoals = generatePeriodGoals(
                offenseStrength: homeForwardStrength,
                defenseStrength: awayDefenseStrength,
                goalieStrength: awayGoalieStrength,
                chance: clampedHomeChance
            )
            let awayGoals = generatePeriodGoals(
                offenseStrength: awayForwardStrength,
                defenseStrength: homeDefenseStrength,
                goalieStrength: homeGoalieStrength,
                chance: 1.0 - clampedHomeChance
            )

            for _ in 0..<homeGoals {
                homeScore += 1
                if let event = generateGoalEvent(team: home, period: period, teamIndex: 0) {
                    scorers.append(event)
                }
            }
            for _ in 0..<awayGoals {
                awayScore += 1
                if let event = generateGoalEvent(team: away, period: period, teamIndex: 1) {
                    scorers.append(event)
                }
            }
        }

        var overtime = false
        if homeScore == awayScore {
            overtime = true
            if Double.random(in: 0...1) < clampedHomeChance {
                homeScore += 1
                if let event = generateGoalEvent(team: home, period: 4, teamIndex: 0) {
                    scorers.append(event)
                }
            } else {
                awayScore += 1
                if let event = generateGoalEvent(team: away, period: 4, teamIndex: 1) {
                    scorers.append(event)
                }
            }
        }

        // Find star player (most points)
        var pointsByPlayer: [UUID: Int] = [:]
        for event in scorers {
            pointsByPlayer[event.scorerID, default: 0] += 1
            if let a1 = event.assist1ID { pointsByPlayer[a1, default: 0] += 1 }
            if let a2 = event.assist2ID { pointsByPlayer[a2, default: 0] += 1 }
        }
        let starPlayer = pointsByPlayer.max { $0.value < $1.value }?.key

        return GameResult(
            homeScore: homeScore,
            awayScore: awayScore,
            overtime: overtime,
            scorers: scorers,
            starPlayerID: starPlayer
        )
    }

    // MARK: - Strength Calculations

    /// Top 6 forwards weighted strength
    private static func forwardLineStrength(for team: Team) -> Double {
        let fwds = team.forwards.filter { !$0.isInjured }.sorted { $0.overall > $1.overall }
        let top6 = fwds.prefix(6)
        guard !top6.isEmpty else { return 50.0 }
        // Weight top line more heavily: first 3 at 1.5x, next 3 at 1.0x
        var total = 0.0
        var weight = 0.0
        for (i, player) in top6.enumerated() {
            let w = i < 3 ? 1.5 : 1.0
            total += Double(player.effectiveOverall) * w
            weight += w
        }
        return total / weight
    }

    /// Defensive strength from top 4 defensemen
    private static func defenseStrength(for team: Team) -> Double {
        let defs = team.defensemen.filter { !$0.isInjured }.sorted { $0.overall > $1.overall }
        let top4 = defs.prefix(4)
        guard !top4.isEmpty else { return 50.0 }
        return Double(top4.reduce(0) { $0 + $1.effectiveOverall }) / Double(top4.count)
    }

    /// Starting goalie strength
    private static func goalieStrength(for team: Team) -> Double {
        guard let goalie = team.startingGoaliePlayer else { return 50.0 }
        return Double(goalie.effectiveOverall)
    }

    /// Average morale across team roster (0-100)
    private static func averageMorale(for team: Team) -> Double {
        guard !team.roster.isEmpty else { return 50.0 }
        return Double(team.roster.reduce(0) { $0 + $1.morale }) / Double(team.roster.count)
    }

    // MARK: - Goal Generation

    private static func generatePeriodGoals(
        offenseStrength: Double,
        defenseStrength: Double,
        goalieStrength: Double,
        chance: Double
    ) -> Int {
        // Average about 1 goal per period per team, influenced by offense vs defense/goalie
        let offenseVsDefense = offenseStrength / max(1.0, (defenseStrength + goalieStrength) / 2.0)
        let base = chance * 1.5 * min(1.5, max(0.5, offenseVsDefense))
        var goals = 0
        for _ in 0...3 {
            if Double.random(in: 0...1) < base * 0.35 {
                goals += 1
            }
        }
        return goals
    }

    private static func generateGoalEvent(team: Team, period: Int, teamIndex: Int) -> GoalEvent? {
        let forwards = team.forwards.filter { !$0.isInjured }
        let defense = team.defensemen.filter { !$0.isInjured }
        let skaters = forwards + defense
        guard !skaters.isEmpty else { return nil }

        // Weight by shooting/offensive ability
        let scorer = weightedRandom(from: skaters) { player in
            Double(player.shooting + player.awareness) / 200.0
        } ?? skaters.randomElement()!

        let assistPool = skaters.filter { $0.id != scorer.id }
        let assist1 = assistPool.randomElement()
        let assist2 = assistPool.filter { $0.id != assist1?.id }.randomElement()

        return GoalEvent(
            period: period,
            scorerID: scorer.id,
            assist1ID: assist1?.id,
            assist2ID: assist2?.id,
            teamIndex: teamIndex,
            isPowerPlay: Int.random(in: 0...4) == 0
        )
    }

    private static func weightedRandom<T>(from items: [T], weight: (T) -> Double) -> T? {
        guard !items.isEmpty else { return nil }
        let weights = items.map { weight($0) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return items.randomElement() }
        var r = Double.random(in: 0..<total)
        for (i, w) in weights.enumerated() {
            r -= w
            if r <= 0 { return items[i] }
        }
        return items.last
    }

    // MARK: - Stat Recording
    static func recordStats(result: GameResult, home: inout Team, away: inout Team) {
        for event in result.scorers {
            let team: Int = event.teamIndex
            let roster = team == 0 ? home.roster : away.roster

            if let scorerIdx = roster.firstIndex(where: { $0.id == event.scorerID }) {
                if team == 0 {
                    home.roster[scorerIdx].seasonGoals += 1
                    home.roster[scorerIdx].seasonGamesPlayed += 1
                } else {
                    away.roster[scorerIdx].seasonGoals += 1
                    away.roster[scorerIdx].seasonGamesPlayed += 1
                }
            }

            for assistID in [event.assist1ID, event.assist2ID].compactMap({ $0 }) {
                if let idx = roster.firstIndex(where: { $0.id == assistID }) {
                    if team == 0 {
                        home.roster[idx].seasonAssists += 1
                    } else {
                        away.roster[idx].seasonAssists += 1
                    }
                }
            }
        }

        // Record games played for all healthy players
        for i in home.roster.indices where !home.roster[i].isInjured {
            if home.roster[i].seasonGamesPlayed == 0 { home.roster[i].seasonGamesPlayed = 1 }
        }
        for i in away.roster.indices where !away.roster[i].isInjured {
            if away.roster[i].seasonGamesPlayed == 0 { away.roster[i].seasonGamesPlayed = 1 }
        }

        // Goalie stats
        if let gIdx = home.goalies.first.flatMap({ g in home.roster.firstIndex(where: { $0.id == g.id }) }) {
            home.roster[gIdx].seasonGoalsAgainst += result.awayScore
            home.roster[gIdx].seasonSaves += Int.random(in: 20...35) // approximate
            home.roster[gIdx].seasonGamesPlayed += 1
            if result.awayScore == 0 { home.roster[gIdx].seasonShutouts += 1 }
        }
        if let gIdx = away.goalies.first.flatMap({ g in away.roster.firstIndex(where: { $0.id == g.id }) }) {
            away.roster[gIdx].seasonGoalsAgainst += result.homeScore
            away.roster[gIdx].seasonSaves += Int.random(in: 20...35)
            away.roster[gIdx].seasonGamesPlayed += 1
            if result.homeScore == 0 { away.roster[gIdx].seasonShutouts += 1 }
        }
    }
}
