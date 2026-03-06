import Foundation

// MARK: - Facility
struct Facility: Codable, Equatable {
    let type: FacilityType
    var level: Int  // 1-5

    /// Display name for the facility at its current level
    var displayName: String {
        "\(type.name) (Lv. \(level))"
    }

    /// Cost in Coaching Credits to upgrade to the next level
    var upgradeCost: Int {
        type.upgradeCost(forLevel: level)  // 2 * current level
    }

    /// Whether the facility can still be upgraded
    var canUpgrade: Bool {
        level < 5
    }
}

// MARK: - Team Model
struct Team: Codable, Identifiable, Equatable {
    let id: UUID
    var city: String
    var name: String
    var abbreviation: String
    var colors: TeamColors

    var roster: [Player]

    // Lines: stored as player IDs
    var forwardLines: [[UUID]]   // 4 lines of 3 (LW, C, RW)
    var defensePairs: [[UUID]]   // 3 pairs of 2 (LD, RD)
    var startingGoalie: UUID?

    // Record
    var wins: Int
    var losses: Int
    var overtimeLosses: Int

    // Finances
    var coachingCredits: Int
    var fanSupport: Int          // 0-100, affects revenue

    // Facilities
    var facilities: [Facility]

    var fullName: String { "\(city) \(name)" }

    var record: String { "\(wins)-\(losses)-\(overtimeLosses)" }

    var points: Int { wins * 2 + overtimeLosses }

    var gamesPlayed: Int { wins + losses + overtimeLosses }

    var totalSalary: Int { roster.reduce(0) { $0 + $1.salary } }

    var capSpace: Int { GameConfig.salaryCap - totalSalary }

    var capUsagePercent: Double {
        Double(totalSalary) / Double(GameConfig.salaryCap)
    }

    var teamOverall: Int {
        guard !roster.isEmpty else { return 0 }
        let top12 = roster.sorted { $0.overall > $1.overall }.prefix(12)
        return top12.reduce(0) { $0 + $1.overall } / max(top12.count, 1)
    }

    // MARK: - Facility Queries

    func facilityLevel(for type: FacilityType) -> Int {
        facilities.first { $0.type == type }?.level ?? 1
    }

    /// Training facility level affects development rates
    var trainingFacilityLevel: Int { facilityLevel(for: .training) }

    /// Medical facility level affects injury chance
    var medicalFacilityLevel: Int { facilityLevel(for: .medical) }

    /// Arena facility level bonus to CC earn rate (0 at level 1, +1 at 2, +2 at 3, etc.)
    var ccEarnBonus: Int {
        max(0, facilityLevel(for: .arena) - 1)
    }

    /// Upgrade a facility. Returns false if can't afford or already max level.
    @discardableResult
    mutating func upgradeFacility(type: FacilityType) -> Bool {
        guard let idx = facilities.firstIndex(where: { $0.type == type }) else { return false }
        guard facilities[idx].canUpgrade else { return false }
        let cost = facilities[idx].upgradeCost
        guard coachingCredits >= cost else { return false }
        coachingCredits -= cost
        facilities[idx].level += 1
        return true
    }

    // MARK: - Roster Queries
    var forwards: [Player] { roster.filter { $0.position.isForward } }
    var defensemen: [Player] { roster.filter { $0.position.isDefense } }
    var goalies: [Player] { roster.filter { $0.position.isGoalie } }
    var healthyRoster: [Player] { roster.filter { !$0.isInjured } }

    var startingGoaliePlayer: Player? {
        if let id = startingGoalie { return roster.first { $0.id == id } }
        return goalies.sorted { $0.overall > $1.overall }.first
    }

    func player(byID id: UUID) -> Player? { roster.first { $0.id == id } }

    // MARK: - Line Management
    func forwardLine(_ index: Int) -> [Player] {
        guard index < forwardLines.count else { return [] }
        return forwardLines[index].compactMap { id in roster.first { $0.id == id } }
    }

    func defensePair(_ index: Int) -> [Player] {
        guard index < defensePairs.count else { return [] }
        return defensePairs[index].compactMap { id in roster.first { $0.id == id } }
    }

    mutating func autoSetLines() {
        let fwds = forwards.filter { !$0.isInjured }.sorted { $0.overall > $1.overall }
        let defs = defensemen.filter { !$0.isInjured }.sorted { $0.overall > $1.overall }
        let gks = goalies.filter { !$0.isInjured }.sorted { $0.overall > $1.overall }

        forwardLines = []
        for i in 0..<4 {
            var line: [UUID] = []
            for j in 0..<3 {
                let idx = i * 3 + j
                if idx < fwds.count { line.append(fwds[idx].id) }
            }
            if !line.isEmpty { forwardLines.append(line) }
        }

        defensePairs = []
        for i in 0..<3 {
            var pair: [UUID] = []
            for j in 0..<2 {
                let idx = i * 2 + j
                if idx < defs.count { pair.append(defs[idx].id) }
            }
            if !pair.isEmpty { defensePairs.append(pair) }
        }

        startingGoalie = gks.first?.id
    }

    mutating func addPlayer(_ player: Player) {
        roster.append(player)
        autoSetLines()
    }

    mutating func removePlayer(id: UUID) {
        roster.removeAll { $0.id == id }
        forwardLines = forwardLines.map { $0.filter { $0 != id } }.filter { !$0.isEmpty }
        defensePairs = defensePairs.map { $0.filter { $0 != id } }.filter { !$0.isEmpty }
        if startingGoalie == id { startingGoalie = goalies.first?.id }
    }

    mutating func resetSeasonRecord() {
        wins = 0
        losses = 0
        overtimeLosses = 0
        for i in roster.indices {
            roster[i].resetSeasonStats()
        }
    }

    mutating func agePlayers() {
        let trainingLevel = trainingFacilityLevel
        for i in roster.indices {
            roster[i].ageSeason(trainingFacilityLevel: trainingLevel)
        }
        // Auto-retire old players with low stats
        roster.removeAll { $0.age >= 40 || ($0.age >= 37 && $0.overall < 60) }
        autoSetLines()
    }

    // MARK: - Codable (backward compat: facilities default to all level 1)
    enum CodingKeys: String, CodingKey {
        case id, city, name, abbreviation, colors, roster
        case forwardLines, defensePairs, startingGoalie
        case wins, losses, overtimeLosses
        case coachingCredits, fanSupport, facilities
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        city = try c.decode(String.self, forKey: .city)
        name = try c.decode(String.self, forKey: .name)
        abbreviation = try c.decode(String.self, forKey: .abbreviation)
        colors = try c.decode(TeamColors.self, forKey: .colors)
        roster = try c.decode([Player].self, forKey: .roster)
        forwardLines = try c.decode([[UUID]].self, forKey: .forwardLines)
        defensePairs = try c.decode([[UUID]].self, forKey: .defensePairs)
        startingGoalie = try c.decodeIfPresent(UUID.self, forKey: .startingGoalie)
        wins = try c.decode(Int.self, forKey: .wins)
        losses = try c.decode(Int.self, forKey: .losses)
        overtimeLosses = try c.decode(Int.self, forKey: .overtimeLosses)
        coachingCredits = try c.decode(Int.self, forKey: .coachingCredits)
        fanSupport = try c.decode(Int.self, forKey: .fanSupport)
        facilities = (try? c.decode([Facility].self, forKey: .facilities)) ?? Team.defaultFacilities
    }

    init(
        id: UUID,
        city: String,
        name: String,
        abbreviation: String,
        colors: TeamColors,
        roster: [Player],
        forwardLines: [[UUID]],
        defensePairs: [[UUID]],
        startingGoalie: UUID?,
        wins: Int,
        losses: Int,
        overtimeLosses: Int,
        coachingCredits: Int,
        fanSupport: Int,
        facilities: [Facility]? = nil
    ) {
        self.id = id
        self.city = city
        self.name = name
        self.abbreviation = abbreviation
        self.colors = colors
        self.roster = roster
        self.forwardLines = forwardLines
        self.defensePairs = defensePairs
        self.startingGoalie = startingGoalie
        self.wins = wins
        self.losses = losses
        self.overtimeLosses = overtimeLosses
        self.coachingCredits = coachingCredits
        self.fanSupport = fanSupport
        self.facilities = facilities ?? Team.defaultFacilities
    }

    static let defaultFacilities: [Facility] = [
        Facility(type: .training, level: 1),
        Facility(type: .medical, level: 1),
        Facility(type: .arena, level: 1),
    ]

    static func == (lhs: Team, rhs: Team) -> Bool { lhs.id == rhs.id }
}

// MARK: - Team Data
struct TeamData {
    static let allTeams: [(city: String, name: String, abbr: String, colors: TeamColors)] = [
        ("Boston",       "Bruisers",    "BOS", TeamColors(primary: "FFB81C", secondary: "000000", accent: "FFFFFF")),
        ("New York",     "Rangers",     "NYR", TeamColors(primary: "0038A8", secondary: "CE1126", accent: "FFFFFF")),
        ("Chicago",      "Wolves",      "CHI", TeamColors(primary: "CF0A2C", secondary: "000000", accent: "FF671B")),
        ("Montreal",     "Voyageurs",   "MTL", TeamColors(primary: "AF1E2D", secondary: "192168", accent: "FFFFFF")),
        ("Toronto",      "Frost",       "TOR", TeamColors(primary: "00205B", secondary: "FFFFFF", accent: "00205B")),
        ("Detroit",      "Engines",     "DET", TeamColors(primary: "CE1126", secondary: "FFFFFF", accent: "CE1126")),
        ("Pittsburgh",   "Ironmen",     "PIT", TeamColors(primary: "000000", secondary: "FCB514", accent: "FFFFFF")),
        ("Philadelphia", "Phantoms",    "PHI", TeamColors(primary: "F74902", secondary: "000000", accent: "FFFFFF")),
        ("Los Angeles",  "Stars",       "LAX", TeamColors(primary: "572A84", secondary: "A2AAAD", accent: "FFFFFF")),
        ("Tampa Bay",    "Thunder",     "TBT", TeamColors(primary: "002868", secondary: "FFFFFF", accent: "002868")),
        ("Colorado",     "Summit",      "COL", TeamColors(primary: "6F263D", secondary: "236192", accent: "A2AAAD")),
        ("Vancouver",    "Orcas",       "VAN", TeamColors(primary: "00205B", secondary: "00843D", accent: "FFFFFF")),
        ("Edmonton",     "Blizzard",    "EDM", TeamColors(primary: "041E42", secondary: "FF4C00", accent: "FFFFFF")),
        ("Dallas",       "Mustangs",    "DAL", TeamColors(primary: "006847", secondary: "8F8F8C", accent: "FFFFFF")),
        ("Washington",   "Eagles",      "WSH", TeamColors(primary: "C8102E", secondary: "041E42", accent: "FFFFFF")),
        ("Carolina",     "Storm",       "CAR", TeamColors(primary: "CC0000", secondary: "000000", accent: "A2AAAD")),
    ]

    static func createTeam(index: Int) -> Team {
        let data = allTeams[index]

        var roster: [Player] = []

        // Generate roster: 12F + 6D + 2G = 20 players
        // 1st line elite/starter, 2nd line starter, 3rd-4th role
        let forwardPositions: [Position] = [.leftWing, .center, .rightWing]

        for line in 0..<4 {
            let tier: PlayerTier = line == 0 ? .elite : (line == 1 ? .starter : .role)
            for pos in forwardPositions {
                roster.append(PlayerGenerator.generatePlayer(position: pos, tier: tier))
            }
        }

        // Defense: 1st pair starter/elite, 2nd starter, 3rd role
        for pair in 0..<3 {
            let tier: PlayerTier = pair == 0 ? .elite : (pair == 1 ? .starter : .role)
            roster.append(PlayerGenerator.generatePlayer(position: .leftDefense, tier: tier))
            roster.append(PlayerGenerator.generatePlayer(position: .rightDefense, tier: tier))
        }

        // Goalies
        roster.append(PlayerGenerator.generatePlayer(position: .goalie, tier: .starter))
        roster.append(PlayerGenerator.generatePlayer(position: .goalie, tier: .role))

        // Ensure unique jersey numbers
        var usedNumbers: Set<Int> = []
        for i in roster.indices {
            while usedNumbers.contains(roster[i].jerseyNumber) {
                roster[i].jerseyNumber = Int.random(in: 1...98)
            }
            usedNumbers.insert(roster[i].jerseyNumber)
        }

        var team = Team(
            id: UUID(),
            city: data.city,
            name: data.name,
            abbreviation: data.abbr,
            colors: data.colors,
            roster: roster,
            forwardLines: [],
            defensePairs: [],
            startingGoalie: nil,
            wins: 0,
            losses: 0,
            overtimeLosses: 0,
            coachingCredits: 3,
            fanSupport: 50,
            facilities: Team.defaultFacilities
        )
        team.autoSetLines()
        return team
    }
}
