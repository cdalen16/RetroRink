import SpriteKit

// MARK: - Game Manager Singleton
final class GameManager {
    static let shared = GameManager()

    var league: League!
    var hasActiveGame: Bool { league != nil }

    private init() {
        load()
    }

    // MARK: - New Game
    func startNewGame(teamIndex: Int, difficulty: Difficulty) {
        league = League.newLeague(playerTeamIndex: teamIndex, difficulty: difficulty)
        save()
    }

    // MARK: - Convenience
    var playerTeam: Team {
        get { league.playerTeam }
        set { league.playerTeam = newValue }
    }

    var playerTeamIndex: Int { league.playerTeamIndex }

    // MARK: - Week Simulation
    func simulateWeek() {
        guard !league.isSeasonComplete else { return }

        let games = league.currentWeekGames
        for (i, game) in league.schedule.enumerated() {
            guard game.week == league.currentWeek && game.result == nil else { continue }

            // Skip player's game (they play it)
            if game.homeTeamIndex == league.playerTeamIndex || game.awayTeamIndex == league.playerTeamIndex {
                continue
            }

            let result = GameSimulator.simulate(
                home: league.teams[game.homeTeamIndex],
                away: league.teams[game.awayTeamIndex],
                difficulty: league.difficulty
            )

            league.schedule[i].result = result

            // Update records
            if result.homeScore > result.awayScore {
                league.teams[game.homeTeamIndex].wins += 1
                if result.overtime {
                    league.teams[game.awayTeamIndex].overtimeLosses += 1
                } else {
                    league.teams[game.awayTeamIndex].losses += 1
                }
            } else {
                league.teams[game.awayTeamIndex].wins += 1
                if result.overtime {
                    league.teams[game.homeTeamIndex].overtimeLosses += 1
                } else {
                    league.teams[game.homeTeamIndex].losses += 1
                }
            }

            var homeTeam = league.teams[game.homeTeamIndex]
            var awayTeam = league.teams[game.awayTeamIndex]
            GameSimulator.recordStats(result: result, home: &homeTeam, away: &awayTeam)
            league.teams[game.homeTeamIndex] = homeTeam
            league.teams[game.awayTeamIndex] = awayTeam
        }

        _ = games
        save()
    }

    func advanceToNextWeek() {
        simulateWeek()
        league.advanceWeek()
        save()
    }

    // MARK: - Record Player Game
    func recordPlayerGame(scheduleIndex: Int, result: GameResult) {
        league.schedule[scheduleIndex].result = result

        let game = league.schedule[scheduleIndex]
        if result.homeScore > result.awayScore {
            league.teams[game.homeTeamIndex].wins += 1
            if result.overtime {
                league.teams[game.awayTeamIndex].overtimeLosses += 1
            } else {
                league.teams[game.awayTeamIndex].losses += 1
            }
        } else {
            league.teams[game.awayTeamIndex].wins += 1
            if result.overtime {
                league.teams[game.homeTeamIndex].overtimeLosses += 1
            } else {
                league.teams[game.homeTeamIndex].losses += 1
            }
        }

        var homeTeam = league.teams[game.homeTeamIndex]
        var awayTeam = league.teams[game.awayTeamIndex]
        GameSimulator.recordStats(result: result, home: &homeTeam, away: &awayTeam)
        league.teams[game.homeTeamIndex] = homeTeam
        league.teams[game.awayTeamIndex] = awayTeam
        save()
    }

    // MARK: - Coaching Credits
    /// Award coaching credits based on game result
    /// +1 CC per win, +2 per playoff win, +1 bonus for shutout
    /// Arena facility level adds bonus CC
    func awardCoachingCredits(result: GameResult, isPlayerHome: Bool) {
        let playerWon: Bool
        if isPlayerHome {
            playerWon = result.homeScore > result.awayScore
        } else {
            playerWon = result.awayScore > result.homeScore
        }

        guard playerWon else { return }

        var credits = 0

        // Base win credit
        let isPlayoffs = league.seasonPhase == .playoffs
        credits += isPlayoffs ? 2 : 1

        // Shutout bonus
        let opponentScore = isPlayerHome ? result.awayScore : result.homeScore
        if opponentScore == 0 {
            credits += 1
        }

        // Arena facility bonus
        credits += league.playerTeam.ccEarnBonus

        league.teams[league.playerTeamIndex].coachingCredits += credits
        save()
    }

    // MARK: - Persistence
    private let saveKey = "RetroRink_SaveData"

    func save() {
        guard let league = league else { return }
        if let data = try? JSONEncoder().encode(league) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let loaded = try? JSONDecoder().decode(League.self, from: data) {
            league = loaded
        }
    }

    func deleteSave() {
        UserDefaults.standard.removeObject(forKey: saveKey)
        league = nil
    }

    // MARK: - Scene Transitions

    /// Transition to a pre-created scene (backward compatible)
    static func transition(from view: SKView?, to scene: SKScene) {
        scene.scaleMode = .aspectFill
        let transition = SKTransition.fade(withDuration: 0.4)
        view?.presentScene(scene, transition: transition)
    }

    /// Transition to a new scene created via BaseScene.create, with optional configure block
    static func transition<T: BaseScene>(from view: SKView?, toSceneType type: T.Type, configure: ((T) -> Void)? = nil) {
        guard let view = view else { return }
        let scene = BaseScene.create(type, in: view)
        configure?(scene)
        let transition = SKTransition.fade(withDuration: 0.4)
        view.presentScene(scene, transition: transition)
    }

    static func pixelTransition(from view: SKView?, to scene: SKScene) {
        scene.scaleMode = .aspectFill
        let transition = SKTransition.doorway(withDuration: 0.6)
        view?.presentScene(scene, transition: transition)
    }

    /// Pixel transition to a new scene created via BaseScene.create
    static func pixelTransition<T: BaseScene>(from view: SKView?, toSceneType type: T.Type, configure: ((T) -> Void)? = nil) {
        guard let view = view else { return }
        let scene = BaseScene.create(type, in: view)
        configure?(scene)
        let transition = SKTransition.doorway(withDuration: 0.6)
        view.presentScene(scene, transition: transition)
    }
}
