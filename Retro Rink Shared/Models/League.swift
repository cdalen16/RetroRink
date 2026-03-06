import Foundation

// MARK: - News Event Types
enum NewsEventType: String, Codable {
    case injury
    case trade
    case milestone
    case morale
    case general
}

// MARK: - News Event
struct NewsEvent: Codable {
    let week: Int
    let type: NewsEventType
    let message: String
}

// MARK: - League Model
struct League: Codable {
    var teams: [Team]
    var schedule: [ScheduledGame]
    var currentWeek: Int
    var seasonPhase: SeasonPhase
    var seasonNumber: Int
    var playerTeamIndex: Int
    var difficulty: Difficulty
    var playoffBracket: PlayoffBracket?
    var draftOrder: [Int]         // team indices in draft order
    var freeAgents: [Player]
    var newsEvents: [NewsEvent]

    var playerTeam: Team {
        get { teams[playerTeamIndex] }
        set { teams[playerTeamIndex] = newValue }
    }

    /// Get recent news messages (most recent first)
    var recentNews: [NewsEvent] {
        newsEvents.sorted { $0.week > $1.week }
    }

    /// Backward-compatible headlines accessor.
    /// Reading returns all news message strings.
    /// Appending creates a new general NewsEvent at the current week.
    var headlines: [String] {
        get { newsEvents.map { $0.message } }
        set {
            // Replace all events with general events from the new strings
            newsEvents = newValue.enumerated().map { i, msg in
                NewsEvent(week: i, type: .general, message: msg)
            }
        }
    }

    // MARK: - Codable (backward compat)
    enum CodingKeys: String, CodingKey {
        case teams, schedule, currentWeek, seasonPhase, seasonNumber
        case playerTeamIndex, difficulty, playoffBracket, draftOrder
        case freeAgents, newsEvents, headlines
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        teams = try c.decode([Team].self, forKey: .teams)
        schedule = try c.decode([ScheduledGame].self, forKey: .schedule)
        currentWeek = try c.decode(Int.self, forKey: .currentWeek)
        seasonPhase = try c.decode(SeasonPhase.self, forKey: .seasonPhase)
        seasonNumber = try c.decode(Int.self, forKey: .seasonNumber)
        playerTeamIndex = try c.decode(Int.self, forKey: .playerTeamIndex)
        difficulty = try c.decode(Difficulty.self, forKey: .difficulty)
        playoffBracket = try c.decodeIfPresent(PlayoffBracket.self, forKey: .playoffBracket)
        draftOrder = try c.decode([Int].self, forKey: .draftOrder)
        freeAgents = try c.decode([Player].self, forKey: .freeAgents)

        // Try newsEvents first, then fall back to headlines
        if let events = try? c.decode([NewsEvent].self, forKey: .newsEvents) {
            newsEvents = events
        } else if let oldHeadlines = try? c.decode([String].self, forKey: .headlines) {
            newsEvents = oldHeadlines.enumerated().map { i, msg in
                NewsEvent(week: i, type: .general, message: msg)
            }
        } else {
            newsEvents = []
        }
    }

    init(
        teams: [Team],
        schedule: [ScheduledGame],
        currentWeek: Int,
        seasonPhase: SeasonPhase,
        seasonNumber: Int,
        playerTeamIndex: Int,
        difficulty: Difficulty,
        playoffBracket: PlayoffBracket?,
        draftOrder: [Int],
        freeAgents: [Player],
        newsEvents: [NewsEvent]
    ) {
        self.teams = teams
        self.schedule = schedule
        self.currentWeek = currentWeek
        self.seasonPhase = seasonPhase
        self.seasonNumber = seasonNumber
        self.playerTeamIndex = playerTeamIndex
        self.difficulty = difficulty
        self.playoffBracket = playoffBracket
        self.draftOrder = draftOrder
        self.freeAgents = freeAgents
        self.newsEvents = newsEvents
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(teams, forKey: .teams)
        try c.encode(schedule, forKey: .schedule)
        try c.encode(currentWeek, forKey: .currentWeek)
        try c.encode(seasonPhase, forKey: .seasonPhase)
        try c.encode(seasonNumber, forKey: .seasonNumber)
        try c.encode(playerTeamIndex, forKey: .playerTeamIndex)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encodeIfPresent(playoffBracket, forKey: .playoffBracket)
        try c.encode(draftOrder, forKey: .draftOrder)
        try c.encode(freeAgents, forKey: .freeAgents)
        try c.encode(newsEvents, forKey: .newsEvents)
        // Don't encode old headlines field
    }

    // MARK: - Season Initialization
    static func newLeague(playerTeamIndex: Int, difficulty: Difficulty) -> League {
        var teams: [Team] = []
        for i in 0..<GameConfig.totalTeams {
            teams.append(TeamData.createTeam(index: i))
        }

        var league = League(
            teams: teams,
            schedule: [],
            currentWeek: 0,
            seasonPhase: .regularSeason,
            seasonNumber: 1,
            playerTeamIndex: playerTeamIndex,
            difficulty: difficulty,
            playoffBracket: nil,
            draftOrder: [],
            freeAgents: generateFreeAgents(count: 30),
            newsEvents: [NewsEvent(week: 0, type: .general, message: "Welcome to Retro Rink! Lead your team to glory!")]
        )
        league.generateSchedule()
        return league
    }

    // MARK: - Schedule Generation
    mutating func generateSchedule() {
        schedule = []
        var weekNum = 0
        let totalGames = GameConfig.seasonGames

        // Round robin style: each team plays each other at least once
        // With 16 teams and 16 games, we can't play everyone.
        // Use a simplified approach: 16 random matchups per team
        var teamGames = [Int: Int]()
        for i in 0..<teams.count { teamGames[i] = 0 }

        for week in 0..<totalGames {
            // Create matchups for this week (8 games = 16 teams / 2)
            var available = Array(0..<teams.count)
            available.shuffle()

            for i in stride(from: 0, to: available.count - 1, by: 2) {
                let home = available[i]
                let away = available[i + 1]
                schedule.append(ScheduledGame(
                    week: week,
                    homeTeamIndex: home,
                    awayTeamIndex: away,
                    result: nil
                ))
                teamGames[home, default: 0] += 1
                teamGames[away, default: 0] += 1
            }
            weekNum = week
        }

        _ = weekNum // suppress unused warning
    }

    // MARK: - Weekly Advance
    var currentWeekGames: [ScheduledGame] {
        schedule.filter { $0.week == currentWeek }
    }

    var playerGameThisWeek: ScheduledGame? {
        currentWeekGames.first { $0.homeTeamIndex == playerTeamIndex || $0.awayTeamIndex == playerTeamIndex }
    }

    var isSeasonComplete: Bool {
        currentWeek >= GameConfig.seasonGames
    }

    mutating func advanceWeek() {
        currentWeek += 1

        // Random events
        generateWeeklyEvents()

        if isSeasonComplete && seasonPhase == .regularSeason {
            startPlayoffs()
        }
    }

    // MARK: - Standings
    var standings: [StandingsEntry] {
        teams.enumerated().map { index, team in
            StandingsEntry(
                teamIndex: index,
                teamName: team.fullName,
                abbreviation: team.abbreviation,
                wins: team.wins,
                losses: team.losses,
                otLosses: team.overtimeLosses,
                points: team.points,
                goalsFor: team.roster.reduce(0) { $0 + $1.seasonGoals },
                goalsAgainst: 0
            )
        }.sorted { $0.points > $1.points }
    }

    // MARK: - Playoffs
    mutating func startPlayoffs() {
        seasonPhase = .playoffs
        let topTeams = standings.prefix(GameConfig.playoffTeams).map { $0.teamIndex }

        playoffBracket = PlayoffBracket(
            round: 1,
            matchups: [
                PlayoffMatchup(team1Index: topTeams[0], team2Index: topTeams[7], team1Wins: 0, team2Wins: 0),
                PlayoffMatchup(team1Index: topTeams[1], team2Index: topTeams[6], team1Wins: 0, team2Wins: 0),
                PlayoffMatchup(team1Index: topTeams[2], team2Index: topTeams[5], team1Wins: 0, team2Wins: 0),
                PlayoffMatchup(team1Index: topTeams[3], team2Index: topTeams[4], team1Wins: 0, team2Wins: 0),
            ],
            champion: nil
        )
    }

    mutating func advancePlayoffRound() {
        guard var bracket = playoffBracket else { return }

        let winners = bracket.matchups.map { matchup -> Int in
            matchup.team1Wins >= 4 ? matchup.team1Index : matchup.team2Index
        }

        if winners.count <= 1 {
            bracket.champion = winners.first
            playoffBracket = bracket
            seasonPhase = .offseason
            return
        }

        var newMatchups: [PlayoffMatchup] = []
        for i in stride(from: 0, to: winners.count - 1, by: 2) {
            newMatchups.append(PlayoffMatchup(
                team1Index: winners[i],
                team2Index: winners[i + 1],
                team1Wins: 0,
                team2Wins: 0
            ))
        }

        bracket.round += 1
        bracket.matchups = newMatchups
        playoffBracket = bracket
    }

    // MARK: - Draft
    mutating func startDraft() {
        seasonPhase = .draft
        // Draft order: worst teams pick first (reverse of standings)
        draftOrder = standings.reversed().map { $0.teamIndex }
        freeAgents = League.generateDraftClass()
    }

    static func generateDraftClass() -> [Player] {
        var prospects: [Player] = []
        let positions: [Position] = [.center, .leftWing, .rightWing, .leftDefense, .rightDefense, .goalie]

        for round in 0..<GameConfig.draftRounds {
            for _ in 0..<GameConfig.totalTeams {
                let pos = positions.randomElement()!
                let tier: PlayerTier = round == 0 ? (Bool.random() ? .starter : .elite) :
                                       round <= 2 ? (Bool.random() ? .role : .starter) : .prospect
                var player = PlayerGenerator.generatePlayer(position: pos, tier: tier, age: 18)
                player.salary = GameConfig.minSalary
                player.contractYears = 3
                prospects.append(player)
            }
        }

        return prospects.sorted { $0.overall > $1.overall }
    }

    static func generateFreeAgents(count: Int) -> [Player] {
        var agents: [Player] = []
        let positions: [Position] = [.center, .leftWing, .rightWing, .leftDefense, .rightDefense, .goalie]
        for _ in 0..<count {
            let pos = positions.randomElement()!
            let tier: PlayerTier = [.role, .role, .role, .starter].randomElement()!
            var player = PlayerGenerator.generatePlayer(position: pos, tier: tier)
            player.contractYears = 0
            agents.append(player)
        }
        return agents.sorted { $0.overall > $1.overall }
    }

    // MARK: - New Season
    mutating func startNewSeason() {
        seasonNumber += 1
        currentWeek = 0
        seasonPhase = .regularSeason
        playoffBracket = nil

        for i in teams.indices {
            teams[i].resetSeasonRecord()
            teams[i].agePlayers()

            // AI teams sign free agents to fill roster
            if i != playerTeamIndex {
                while teams[i].roster.count < GameConfig.minRosterSize {
                    if let fa = freeAgents.first {
                        var player = fa
                        player.contractYears = Int.random(in: 1...3)
                        teams[i].addPlayer(player)
                        freeAgents.removeFirst()
                    } else { break }
                }
            }
        }

        generateSchedule()
        freeAgents = League.generateFreeAgents(count: 30)
        newsEvents = [NewsEvent(week: 0, type: .general, message: "Season \(seasonNumber) begins! Who will hoist the cup?")]
    }

    // MARK: - News Event Helpers

    mutating func addNewsEvent(type: NewsEventType, message: String) {
        newsEvents.append(NewsEvent(week: currentWeek, type: type, message: message))
    }

    // MARK: - Events
    mutating func generateWeeklyEvents() {
        // Random injuries
        for i in teams.indices {
            // Medical facility reduces injury chance for the player's team
            let medicalLevel = teams[i].medicalFacilityLevel
            // Base injury chance: 1 in 51. Medical level reduces it.
            let injuryDenominator = 50 + (medicalLevel * 5)  // level 1=55, level 5=75

            for j in teams[i].roster.indices {
                if !teams[i].roster[j].isInjured && Int.random(in: 0...injuryDenominator) == 0 {
                    teams[i].roster[j].isInjured = true
                    // Medical facility reduces injury duration
                    let maxWeeks = max(1, 4 - (medicalLevel / 2))
                    teams[i].roster[j].injuryWeeks = Int.random(in: 1...maxWeeks)
                    if i == playerTeamIndex {
                        addNewsEvent(
                            type: .injury,
                            message: "\(teams[i].roster[j].fullName) is injured! Out \(teams[i].roster[j].injuryWeeks) weeks."
                        )
                    }
                }
            }
            // Heal injuries
            for j in teams[i].roster.indices {
                if teams[i].roster[j].isInjured {
                    teams[i].roster[j].injuryWeeks -= 1
                    if teams[i].roster[j].injuryWeeks <= 0 {
                        teams[i].roster[j].isInjured = false
                        teams[i].roster[j].injuryWeeks = 0
                    }
                }
            }
        }

        // Morale events based on streaks
        generateMoraleEvents()
    }

    /// Generate morale events: winning streaks boost morale, losing streaks drop it
    private mutating func generateMoraleEvents() {
        for i in teams.indices {
            // Look at last 3 games for this team
            let teamGames = schedule.filter {
                ($0.homeTeamIndex == i || $0.awayTeamIndex == i) && $0.result != nil
            }.suffix(3)

            guard teamGames.count >= 3 else { continue }

            var consecutiveWins = 0
            var consecutiveLosses = 0

            for game in teamGames {
                guard let result = game.result else { continue }
                let isHome = game.homeTeamIndex == i
                let won = isHome ? result.homeScore > result.awayScore : result.awayScore > result.homeScore
                if won {
                    consecutiveWins += 1
                    consecutiveLosses = 0
                } else {
                    consecutiveLosses += 1
                    consecutiveWins = 0
                }
            }

            if consecutiveWins >= 3 {
                // Winning streak: boost morale
                for j in teams[i].roster.indices {
                    teams[i].roster[j].morale = min(100, teams[i].roster[j].morale + Int.random(in: 2...5))
                }
                if i == playerTeamIndex {
                    addNewsEvent(
                        type: .morale,
                        message: "\(teams[i].fullName) on a \(consecutiveWins)-game win streak! Team morale is soaring!"
                    )
                }
            } else if consecutiveLosses >= 3 {
                // Losing streak: drop morale
                for j in teams[i].roster.indices {
                    teams[i].roster[j].morale = max(10, teams[i].roster[j].morale - Int.random(in: 2...5))
                }
                if i == playerTeamIndex {
                    addNewsEvent(
                        type: .morale,
                        message: "\(teams[i].fullName) struggling with a \(consecutiveLosses)-game losing streak. Morale is low."
                    )
                }
            }
        }
    }

    // MARK: - Record Game Result
    mutating func recordResult(gameIndex: Int, result: GameResult) {
        guard gameIndex < schedule.count else { return }
        schedule[gameIndex].result = result

        let home = schedule[gameIndex].homeTeamIndex
        let away = schedule[gameIndex].awayTeamIndex

        if result.homeScore > result.awayScore {
            teams[home].wins += 1
            if result.overtime {
                teams[away].overtimeLosses += 1
            } else {
                teams[away].losses += 1
            }
        } else {
            teams[away].wins += 1
            if result.overtime {
                teams[home].overtimeLosses += 1
            } else {
                teams[home].losses += 1
            }
        }
    }
}

// MARK: - Supporting Types
struct ScheduledGame: Codable, Identifiable {
    let id = UUID()
    let week: Int
    let homeTeamIndex: Int
    let awayTeamIndex: Int
    var result: GameResult?

    var isPlayed: Bool { result != nil }
}

struct GameResult: Codable {
    let homeScore: Int
    let awayScore: Int
    let overtime: Bool
    let scorers: [GoalEvent]
    let starPlayerID: UUID?
}

struct GoalEvent: Codable {
    let period: Int
    let scorerID: UUID
    let assist1ID: UUID?
    let assist2ID: UUID?
    let teamIndex: Int
    let isPowerPlay: Bool
}

struct StandingsEntry {
    let teamIndex: Int
    let teamName: String
    let abbreviation: String
    let wins: Int
    let losses: Int
    let otLosses: Int
    let points: Int
    let goalsFor: Int
    let goalsAgainst: Int

    var record: String { "\(wins)-\(losses)-\(otLosses)" }
}

struct PlayoffBracket: Codable {
    var round: Int
    var matchups: [PlayoffMatchup]
    var champion: Int?

    var roundName: String {
        switch round {
        case 1: return "Quarterfinals"
        case 2: return "Semifinals"
        case 3: return "Championship"
        default: return "Round \(round)"
        }
    }
}

struct PlayoffMatchup: Codable {
    let team1Index: Int
    let team2Index: Int
    var team1Wins: Int
    var team2Wins: Int

    var isComplete: Bool { team1Wins >= 4 || team2Wins >= 4 }
    var winnerIndex: Int? { isComplete ? (team1Wins >= 4 ? team1Index : team2Index) : nil }
}
