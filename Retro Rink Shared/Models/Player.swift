import Foundation

// MARK: - Player Trait
enum PlayerTrait: String, Codable, CaseIterable {
    case sniper
    case playmaker
    case enforcer
    case speedster
    case clutch
    case ironMan
    case leader

    var name: String {
        switch self {
        case .sniper: return "Sniper"
        case .playmaker: return "Playmaker"
        case .enforcer: return "Enforcer"
        case .speedster: return "Speedster"
        case .clutch: return "Clutch"
        case .ironMan: return "Iron Man"
        case .leader: return "Leader"
        }
    }

    var description: String {
        switch self {
        case .sniper: return "Elite shooting accuracy and power"
        case .playmaker: return "Superior vision and passing ability"
        case .enforcer: return "Intimidating physical presence"
        case .speedster: return "Blazing speed on the ice"
        case .clutch: return "Performs best under pressure"
        case .ironMan: return "Rarely gets injured, high endurance"
        case .leader: return "Boosts teammate morale and performance"
        }
    }

    /// Returns a multiplier for the given stat name. 1.0 means no bonus.
    func statBonus(for stat: String) -> Double {
        switch self {
        case .sniper:
            if stat == "shooting" { return 1.1 }
        case .playmaker:
            if stat == "passing" { return 1.1 }
            if stat == "awareness" { return 1.05 }
        case .enforcer:
            if stat == "checking" { return 1.1 }
        case .speedster:
            if stat == "speed" { return 1.1 }
        case .clutch:
            if stat == "shooting" { return 1.05 }
            if stat == "awareness" { return 1.05 }
        case .ironMan:
            if stat == "endurance" { return 1.1 }
        case .leader:
            if stat == "awareness" { return 1.05 }
        }
        return 1.0
    }
}

// MARK: - Player Model
struct Player: Codable, Identifiable, Equatable {
    let id: UUID
    var firstName: String
    var lastName: String
    var position: Position
    var age: Int
    var jerseyNumber: Int

    // Skater stats (1-99)
    var speed: Int
    var shooting: Int
    var passing: Int
    var puckHandling: Int
    var checking: Int
    var awareness: Int
    var endurance: Int

    // Goalie stats (1-99)
    var reflexes: Int
    var positioning: Int
    var reboundControl: Int

    // Contract
    var salary: Int
    var contractYears: Int

    // Development
    var potential: Int        // max overall they can reach
    var morale: Int           // 0-100

    var isInjured: Bool
    var injuryWeeks: Int

    // Traits
    var traits: [PlayerTrait]

    // Season stats
    var seasonGoals: Int
    var seasonAssists: Int
    var seasonPlusMinus: Int
    var seasonPIM: Int        // penalty minutes
    var seasonGamesPlayed: Int

    // Goalie season stats
    var seasonSaves: Int
    var seasonGoalsAgainst: Int
    var seasonShutouts: Int

    var fullName: String { "\(firstName) \(lastName)" }
    var shortName: String { "\(firstName.prefix(1)). \(lastName)" }

    var overall: Int {
        if position.isGoalie {
            return (reflexes * 3 + positioning * 3 + reboundControl * 2 + awareness + speed) / 10
        }
        if position.isForward {
            return (speed * 2 + shooting * 3 + passing * 2 + puckHandling * 2 + awareness) / 10
        }
        // Defense
        return (speed + shooting + passing + checking * 3 + awareness * 2 + puckHandling * 2) / 10
    }

    /// Overall with trait bonuses applied
    var effectiveOverall: Int {
        if traits.isEmpty { return overall }
        // Apply trait bonuses to a copy of stats, then recalculate
        let effSpeed = Int(Double(speed) * traitMultiplier(for: "speed"))
        let effShooting = Int(Double(shooting) * traitMultiplier(for: "shooting"))
        let effPassing = Int(Double(passing) * traitMultiplier(for: "passing"))
        let effPuckHandling = Int(Double(puckHandling) * traitMultiplier(for: "puckHandling"))
        let effChecking = Int(Double(checking) * traitMultiplier(for: "checking"))
        let effAwareness = Int(Double(awareness) * traitMultiplier(for: "awareness"))
        let effReflexes = Int(Double(reflexes) * traitMultiplier(for: "reflexes"))
        let effPositioning = Int(Double(positioning) * traitMultiplier(for: "positioning"))
        let effReboundControl = Int(Double(reboundControl) * traitMultiplier(for: "reboundControl"))

        if position.isGoalie {
            return (effReflexes * 3 + effPositioning * 3 + effReboundControl * 2 + effAwareness + effSpeed) / 10
        }
        if position.isForward {
            return (effSpeed * 2 + effShooting * 3 + effPassing * 2 + effPuckHandling * 2 + effAwareness) / 10
        }
        return (effSpeed + effShooting + effPassing + effChecking * 3 + effAwareness * 2 + effPuckHandling * 2) / 10
    }

    /// Combined trait multiplier for a given stat
    func traitMultiplier(for stat: String) -> Double {
        traits.reduce(1.0) { $0 * $1.statBonus(for: stat) }
    }

    var starRating: Int {
        switch overall {
        case 90...99: return 5
        case 80...89: return 4
        case 70...79: return 3
        case 60...69: return 2
        default: return 1
        }
    }

    var salaryString: String {
        if salary >= 1_000_000 {
            let m = Double(salary) / 1_000_000.0
            return String(format: "$%.1fM", m)
        }
        let k = salary / 1000
        return "$\(k)K"
    }

    var points: Int { seasonGoals + seasonAssists }

    var goalieSavePercentage: Double {
        let totalShots = seasonSaves + seasonGoalsAgainst
        guard totalShots > 0 else { return 0 }
        return Double(seasonSaves) / Double(totalShots)
    }

    var goalieGAA: Double {
        guard seasonGamesPlayed > 0 else { return 0 }
        return Double(seasonGoalsAgainst) / Double(seasonGamesPlayed)
    }

    mutating func resetSeasonStats() {
        seasonGoals = 0
        seasonAssists = 0
        seasonPlusMinus = 0
        seasonPIM = 0
        seasonGamesPlayed = 0
        seasonSaves = 0
        seasonGoalsAgainst = 0
        seasonShutouts = 0
    }

    mutating func ageSeason(trainingFacilityLevel: Int = 1) {
        age += 1

        // Training facility bonus: each level above 1 adds +1 potential growth
        let facilityBonus = max(0, trainingFacilityLevel - 1)

        // Development (young players improve, old players decline)
        if age <= 24 {
            let growth = Int.random(in: 1...3) + facilityBonus
            improveStat(by: growth)
        } else if age <= 28 {
            let growth = Int.random(in: 0...2) + facilityBonus
            improveStat(by: growth)
        } else if age >= 33 {
            let decline = Int.random(in: 1...3)
            declineStat(by: decline)
        } else if age >= 36 {
            let decline = Int.random(in: 2...5)
            declineStat(by: decline)
        }

        contractYears = max(0, contractYears - 1)
    }

    private mutating func improveStat(by amount: Int) {
        guard overall < potential else { return }
        if position.isGoalie {
            switch Int.random(in: 0...2) {
            case 0: reflexes = min(99, reflexes + amount)
            case 1: positioning = min(99, positioning + amount)
            default: reboundControl = min(99, reboundControl + amount)
            }
        } else {
            switch Int.random(in: 0...5) {
            case 0: speed = min(99, speed + amount)
            case 1: shooting = min(99, shooting + amount)
            case 2: passing = min(99, passing + amount)
            case 3: puckHandling = min(99, puckHandling + amount)
            case 4: checking = min(99, checking + amount)
            default: awareness = min(99, awareness + amount)
            }
        }
    }

    private mutating func declineStat(by amount: Int) {
        if position.isGoalie {
            reflexes = max(30, reflexes - amount)
            positioning = max(30, positioning - Int.random(in: 0...amount))
        } else {
            speed = max(30, speed - amount)
            endurance = max(30, endurance - amount)
            if Int.random(in: 0...1) == 0 {
                checking = max(30, checking - Int.random(in: 0...amount))
            }
        }
    }

    // MARK: - Codable (traits default to empty for backward compat)
    enum CodingKeys: String, CodingKey {
        case id, firstName, lastName, position, age, jerseyNumber
        case speed, shooting, passing, puckHandling, checking, awareness, endurance
        case reflexes, positioning, reboundControl
        case salary, contractYears, potential, morale
        case isInjured, injuryWeeks, traits
        case seasonGoals, seasonAssists, seasonPlusMinus, seasonPIM, seasonGamesPlayed
        case seasonSaves, seasonGoalsAgainst, seasonShutouts
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        firstName = try c.decode(String.self, forKey: .firstName)
        lastName = try c.decode(String.self, forKey: .lastName)
        position = try c.decode(Position.self, forKey: .position)
        age = try c.decode(Int.self, forKey: .age)
        jerseyNumber = try c.decode(Int.self, forKey: .jerseyNumber)
        speed = try c.decode(Int.self, forKey: .speed)
        shooting = try c.decode(Int.self, forKey: .shooting)
        passing = try c.decode(Int.self, forKey: .passing)
        puckHandling = try c.decode(Int.self, forKey: .puckHandling)
        checking = try c.decode(Int.self, forKey: .checking)
        awareness = try c.decode(Int.self, forKey: .awareness)
        endurance = try c.decode(Int.self, forKey: .endurance)
        reflexes = try c.decode(Int.self, forKey: .reflexes)
        positioning = try c.decode(Int.self, forKey: .positioning)
        reboundControl = try c.decode(Int.self, forKey: .reboundControl)
        salary = try c.decode(Int.self, forKey: .salary)
        contractYears = try c.decode(Int.self, forKey: .contractYears)
        potential = try c.decode(Int.self, forKey: .potential)
        morale = try c.decode(Int.self, forKey: .morale)
        isInjured = try c.decode(Bool.self, forKey: .isInjured)
        injuryWeeks = try c.decode(Int.self, forKey: .injuryWeeks)
        traits = (try? c.decode([PlayerTrait].self, forKey: .traits)) ?? []
        seasonGoals = try c.decode(Int.self, forKey: .seasonGoals)
        seasonAssists = try c.decode(Int.self, forKey: .seasonAssists)
        seasonPlusMinus = try c.decode(Int.self, forKey: .seasonPlusMinus)
        seasonPIM = try c.decode(Int.self, forKey: .seasonPIM)
        seasonGamesPlayed = try c.decode(Int.self, forKey: .seasonGamesPlayed)
        seasonSaves = try c.decode(Int.self, forKey: .seasonSaves)
        seasonGoalsAgainst = try c.decode(Int.self, forKey: .seasonGoalsAgainst)
        seasonShutouts = try c.decode(Int.self, forKey: .seasonShutouts)
    }

    init(
        id: UUID,
        firstName: String,
        lastName: String,
        position: Position,
        age: Int,
        jerseyNumber: Int,
        speed: Int,
        shooting: Int,
        passing: Int,
        puckHandling: Int,
        checking: Int,
        awareness: Int,
        endurance: Int,
        reflexes: Int,
        positioning: Int,
        reboundControl: Int,
        salary: Int,
        contractYears: Int,
        potential: Int,
        morale: Int,
        isInjured: Bool,
        injuryWeeks: Int,
        traits: [PlayerTrait] = [],
        seasonGoals: Int,
        seasonAssists: Int,
        seasonPlusMinus: Int,
        seasonPIM: Int,
        seasonGamesPlayed: Int,
        seasonSaves: Int,
        seasonGoalsAgainst: Int,
        seasonShutouts: Int
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.position = position
        self.age = age
        self.jerseyNumber = jerseyNumber
        self.speed = speed
        self.shooting = shooting
        self.passing = passing
        self.puckHandling = puckHandling
        self.checking = checking
        self.awareness = awareness
        self.endurance = endurance
        self.reflexes = reflexes
        self.positioning = positioning
        self.reboundControl = reboundControl
        self.salary = salary
        self.contractYears = contractYears
        self.potential = potential
        self.morale = morale
        self.isInjured = isInjured
        self.injuryWeeks = injuryWeeks
        self.traits = traits
        self.seasonGoals = seasonGoals
        self.seasonAssists = seasonAssists
        self.seasonPlusMinus = seasonPlusMinus
        self.seasonPIM = seasonPIM
        self.seasonGamesPlayed = seasonGamesPlayed
        self.seasonSaves = seasonSaves
        self.seasonGoalsAgainst = seasonGoalsAgainst
        self.seasonShutouts = seasonShutouts
    }

    static func == (lhs: Player, rhs: Player) -> Bool { lhs.id == rhs.id }
}

// MARK: - Draft Prospect
struct DraftProspect {
    let player: Player
    let scoutingGrade: String  // A-F based on team's facility level

    /// Create a draft prospect with scouting accuracy based on facility level (1-5)
    static func scout(player: Player, facilityLevel: Int) -> DraftProspect {
        // Higher facility = more accurate grade
        // Grade is based on overall, but lower facility levels add noise
        let noise: Int
        switch facilityLevel {
        case 5: noise = 0
        case 4: noise = Int.random(in: -2...2)
        case 3: noise = Int.random(in: -5...5)
        case 2: noise = Int.random(in: -8...8)
        default: noise = Int.random(in: -12...12)
        }
        let perceivedOverall = max(30, min(99, player.overall + noise))

        let grade: String
        switch perceivedOverall {
        case 85...99: grade = "A"
        case 78...84: grade = "B"
        case 70...77: grade = "C"
        case 60...69: grade = "D"
        default: grade = "F"
        }

        return DraftProspect(player: player, scoutingGrade: grade)
    }
}

// MARK: - Player Generation
struct PlayerGenerator {
    static let firstNames = [
        "Alex", "Mike", "Jake", "Ryan", "Cole", "Tyler", "Connor", "Matt",
        "Nick", "Chris", "Kyle", "Brandon", "Dylan", "Josh", "Adam", "Ben",
        "Eric", "Liam", "Noel", "Max", "Sam", "Theo", "Leo", "Jack",
        "Owen", "Finn", "Noah", "Luke", "Evan", "Ian", "Sean", "Brett",
        "Cody", "Dillon", "Ethan", "Grant", "Henry", "Ivan", "James", "Keith",
        "Lars", "Marcus", "Niklas", "Oliver", "Pavel", "Quinn", "Riley", "Scott",
        "Travis", "Viktor", "Wayne", "Xavier", "Yuri", "Zach", "Alexei", "Boris",
        "Dmitri", "Erik", "Filip", "Gustav", "Henrik", "Ilya", "Jaromir", "Kirill",
        "Patrik", "Mika", "Nikita", "Ondrej", "Pierre", "Rasmus", "Sasha", "Tomas",
    ]

    static let lastNames = [
        "Smith", "Johnson", "Williams", "Brown", "Jones", "Miller", "Davis",
        "Wilson", "Anderson", "Thompson", "White", "Martin", "Clark", "Hall",
        "Campbell", "Mitchell", "Carter", "Roberts", "Turner", "Phillips",
        "Evans", "Edwards", "Collins", "Stewart", "Morris", "Murphy", "Cook",
        "Rogers", "Morgan", "Cooper", "Peterson", "Bailey", "Reed", "Kelly",
        "Howard", "Ward", "Nelson", "Hill", "Adams", "Baker", "Green",
        "Bergstrom", "Lindqvist", "Petrov", "Volkov", "Novak", "Kowalski",
        "Schmidt", "Weber", "Eriksson", "Johansson", "Larsson", "Nilsson",
        "Kozlov", "Morozov", "Ivanov", "Kovalev", "Malkin", "Federov",
        "Forsberg", "Backstrom", "Hedman", "Dahlin", "Svechnikov", "Draisaitl",
        "Giroux", "Bergeron", "Leclerc", "Bouchard", "Dubois", "Fleury",
    ]

    static func generatePlayer(position: Position, tier: PlayerTier, age: Int? = nil) -> Player {
        let playerAge = age ?? generateAge(tier: tier)
        let (baseMin, baseMax) = tier.statRange

        let stats = generateStats(position: position, min: baseMin, max: baseMax)
        let potential = min(99, stats.values.max()! + Int.random(in: 0...10))

        let salary = calculateSalary(overall: stats.values.reduce(0, +) / max(stats.count, 1), position: position)

        // Assign traits: elite and starter tiers get 0-2 random traits
        let traits: [PlayerTrait]
        switch tier {
        case .elite:
            let count = Int.random(in: 1...2)
            traits = Array(PlayerTrait.allCases.shuffled().prefix(count))
        case .starter:
            let count = Int.random(in: 0...2)
            traits = Array(PlayerTrait.allCases.shuffled().prefix(count))
        default:
            traits = []
        }

        return Player(
            id: UUID(),
            firstName: firstNames.randomElement()!,
            lastName: lastNames.randomElement()!,
            position: position,
            age: playerAge,
            jerseyNumber: Int.random(in: 1...98),
            speed: stats["speed"]!,
            shooting: stats["shooting"]!,
            passing: stats["passing"]!,
            puckHandling: stats["puckHandling"]!,
            checking: stats["checking"]!,
            awareness: stats["awareness"]!,
            endurance: stats["endurance"]!,
            reflexes: stats["reflexes"]!,
            positioning: stats["positioning"]!,
            reboundControl: stats["reboundControl"]!,
            salary: salary,
            contractYears: Int.random(in: 1...4),
            potential: potential,
            morale: Int.random(in: 60...90),
            isInjured: false,
            injuryWeeks: 0,
            traits: traits,
            seasonGoals: 0,
            seasonAssists: 0,
            seasonPlusMinus: 0,
            seasonPIM: 0,
            seasonGamesPlayed: 0,
            seasonSaves: 0,
            seasonGoalsAgainst: 0,
            seasonShutouts: 0
        )
    }

    private static func generateAge(tier: PlayerTier) -> Int {
        switch tier {
        case .elite: return Int.random(in: 24...31)
        case .starter: return Int.random(in: 22...32)
        case .role: return Int.random(in: 20...34)
        case .prospect: return Int.random(in: 18...22)
        }
    }

    private static func generateStats(position: Position, min statMin: Int, max statMax: Int) -> [String: Int] {
        func r() -> Int { Int.random(in: statMin...statMax) }

        if position.isGoalie {
            return [
                "speed": Int.random(in: 40...60),
                "shooting": Int.random(in: 20...40),
                "passing": Int.random(in: 30...50),
                "puckHandling": Int.random(in: 30...55),
                "checking": Int.random(in: 20...40),
                "awareness": r(),
                "endurance": r(),
                "reflexes": r(),
                "positioning": r(),
                "reboundControl": r(),
            ]
        }

        let lowShoot = Swift.max(statMin - 10, 35)
        let lowHandle = Swift.max(statMin - 10, 35)
        let lowCheck = Swift.max(statMin - 15, 30)

        return [
            "speed": r(),
            "shooting": position.isForward ? r() : Int.random(in: lowShoot...statMax),
            "passing": r(),
            "puckHandling": position.isForward ? r() : Int.random(in: lowHandle...statMax),
            "checking": position.isDefense ? r() : Int.random(in: lowCheck...statMax),
            "awareness": r(),
            "endurance": r(),
            "reflexes": Int.random(in: 40...60),
            "positioning": Int.random(in: 40...60),
            "reboundControl": Int.random(in: 40...60),
        ]
    }

    private static func calculateSalary(overall: Int, position: Position) -> Int {
        let base: Int
        switch overall {
        case 85...99: base = Int.random(in: 8_000_000...13_000_000)
        case 78...84: base = Int.random(in: 5_000_000...8_000_000)
        case 70...77: base = Int.random(in: 2_500_000...5_000_000)
        case 60...69: base = Int.random(in: 1_000_000...2_500_000)
        default: base = GameConfig.minSalary
        }
        // Round to nearest 25K
        return (base / 25_000) * 25_000
    }
}

enum PlayerTier: CaseIterable {
    case elite, starter, role, prospect

    var statRange: (Int, Int) {
        switch self {
        case .elite: return (82, 96)
        case .starter: return (72, 85)
        case .role: return (58, 75)
        case .prospect: return (48, 68)
        }
    }
}
