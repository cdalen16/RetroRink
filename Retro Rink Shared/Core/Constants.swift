import SpriteKit

// MARK: - Pixel Size
let kPixelSize: CGFloat = 3

// MARK: - Legacy Scene Size (deprecated - scenes now use view.bounds via BaseScene)
// Kept for backward compatibility with existing scene files
let kSceneWidth: CGFloat = 736
let kSceneHeight: CGFloat = 414

// MARK: - Physics Categories
struct PhysicsCategory {
    static let none:       UInt32 = 0
    static let puck:       UInt32 = 1 << 0
    static let skater:     UInt32 = 1 << 1
    static let boards:     UInt32 = 1 << 2
    static let goal:       UInt32 = 1 << 3
    static let goalCrease: UInt32 = 1 << 4
}

// MARK: - Z Positions
struct ZPos {
    static let ice: CGFloat        = 0
    static let rinkLines: CGFloat  = 1
    static let shadow: CGFloat     = 2
    static let puck: CGFloat       = 5
    static let skater: CGFloat     = 10
    static let effects: CGFloat    = 15
    static let hud: CGFloat        = 50
    static let overlay: CGFloat    = 100
    static let transition: CGFloat = 200
}

// MARK: - Player Position
enum Position: String, Codable, CaseIterable {
    case center = "C"
    case leftWing = "LW"
    case rightWing = "RW"
    case leftDefense = "LD"
    case rightDefense = "RD"
    case goalie = "G"

    var isForward: Bool { self == .center || self == .leftWing || self == .rightWing }
    var isDefense: Bool { self == .leftDefense || self == .rightDefense }
    var isGoalie: Bool { self == .goalie }

    var shortName: String { rawValue }

    var fullName: String {
        switch self {
        case .center: return "Center"
        case .leftWing: return "Left Wing"
        case .rightWing: return "Right Wing"
        case .leftDefense: return "Left Defense"
        case .rightDefense: return "Right Defense"
        case .goalie: return "Goalie"
        }
    }
}

// MARK: - Gameplay State
enum GameplayState {
    case pregame
    case faceoff
    case playing        // continuous live gameplay (offense + defense)
    case goalScored
    case periodBreak
    case overtime
    case shootout
    case gameOver
}

// MARK: - Possession State (sub-state within .playing)
enum PossessionState {
    case playerOffense    // player's team has puck
    case playerDefense    // opponent has puck
    case loosePuck        // nobody has it
}

// MARK: - Season Phase
enum SeasonPhase: String, Codable {
    case preseason
    case regularSeason
    case playoffs
    case offseason
    case draft
    case freeAgency
}

// MARK: - Difficulty
enum Difficulty: Int, Codable, CaseIterable {
    case rookie = 0
    case pro = 1
    case allStar = 2
    case legend = 3

    var name: String {
        switch self {
        case .rookie: return "Rookie"
        case .pro: return "Pro"
        case .allStar: return "All-Star"
        case .legend: return "Legend"
        }
    }

    var aiReactionMultiplier: CGFloat {
        switch self {
        case .rookie: return 0.6
        case .pro: return 0.8
        case .allStar: return 1.0
        case .legend: return 1.2
        }
    }

    var saveChanceBonus: Double {
        switch self {
        case .rookie: return -0.15
        case .pro: return -0.05
        case .allStar: return 0.05
        case .legend: return 0.15
        }
    }
}

// MARK: - Game Configuration
struct GameConfig {
    static let periodsPerGame = 3
    static let periodDuration: TimeInterval = 75       // seconds per period
    static let otPeriodDuration: TimeInterval = 45     // shorter OT period

    static let maxRosterSize = 20
    static let minRosterSize = 14
    static let salaryCap = 82_500_000
    static let minSalary = 775_000
    static let maxSalary = 13_000_000

    static let draftRounds = 5
    static let draftProspectsPerRound = 16
    static let totalTeams = 16
    static let playoffTeams = 8
    static let seasonGames = 16

    static let rinkWidth: CGFloat = 1200
    static let rinkHeight: CGFloat = 600
    static let goalWidth: CGFloat = 60
    static let goalDepth: CGFloat = 30
    static let creaseRadius: CGFloat = 50

    static let skaterRadius: CGFloat = 10
    static let puckRadius: CGFloat = 3
    static let skaterSpeed: CGFloat = 200
    static let puckSpeed: CGFloat = 500
    static let passSpeed: CGFloat = 500
    static let shotSpeedBase: CGFloat = 400
    static let shotSpeedMax: CGFloat = 700
}

// MARK: - Camera Configuration
struct CameraConfig {
    static let scale: CGFloat = 0.65
    static let followSpeed: CGFloat = 0.12
    static let leadAmount: CGFloat = 50
    static let boundsPadding: CGFloat = 50
}

// MARK: - Touch Configuration
struct TouchConfig {
    static let swipeMinDistance: CGFloat = 30
    static let swipeMaxDuration: TimeInterval = 0.6
    static let dekeAngleThreshold: CGFloat = 55.0 * .pi / 180.0  // 55 degrees — perpendicular swipes trigger dekes
    static let tapRadius: CGFloat = 55
}

// MARK: - Joystick Configuration
struct JoystickConfig {
    static let baseRadius: CGFloat = 40       // outer circle radius (in HUD/camera coords)
    static let thumbRadius: CGFloat = 16      // inner thumb circle
    static let deadzone: CGFloat = 6          // ignore displacement below this
    static let activateRadius: CGFloat = 55   // touch must start within this to activate joystick
}

// MARK: - Animation Configuration
struct AnimationConfig {
    static let skateFrameCount = 4
    static let skateFrameDuration: TimeInterval = 0.12
    static let shootFrameCount = 3
    static let shootFrameDuration: TimeInterval = 0.1
    static let celebrateFrameCount = 4
    static let celebrateFrameDuration: TimeInterval = 0.15
}

// MARK: - Facility Type
enum FacilityType: String, Codable, CaseIterable {
    case training
    case medical
    case arena

    var name: String {
        switch self {
        case .training: return "Training Center"
        case .medical: return "Medical Facility"
        case .arena: return "Arena"
        }
    }

    var description: String {
        switch self {
        case .training: return "Improves player development rates"
        case .medical: return "Reduces injury chance and recovery time"
        case .arena: return "Increases coaching credit earn rate"
        }
    }

    /// Cost in Coaching Credits to upgrade to the given level (2 * level)
    func upgradeCost(forLevel level: Int) -> Int {
        return 2 * level  // Level 1->2 costs 2, 2->3 costs 4, 3->4 costs 6, 4->5 costs 8
    }
}

// MARK: - Team Color Data
struct TeamColors: Codable, Equatable {
    let primary: String      // hex color
    let secondary: String    // hex color
    let accent: String       // hex color

    var primaryColor: UIColor { UIColor(hex: primary) }
    var secondaryColor: UIColor { UIColor(hex: secondary) }
    var accentColor: UIColor { UIColor(hex: accent) }
}

// MARK: - UIColor Hex Extension
extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }

    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - Retro Color Palette
struct RetroPalette {
    static let background  = UIColor(hex: "1A1A2E")
    static let darkPanel   = UIColor(hex: "16213E")
    static let midPanel    = UIColor(hex: "0F3460")
    static let accent      = UIColor(hex: "E94560")
    static let gold        = UIColor(hex: "F5C518")
    static let silver      = UIColor(hex: "C0C0C0")
    static let ice         = UIColor(hex: "E8F0FE")
    static let iceLight    = UIColor(hex: "F5F8FF")
    static let redLine     = UIColor(hex: "CC0000")
    static let blueLine    = UIColor(hex: "0044AA")
    static let boardsBrown = UIColor(hex: "8B6914")
    static let boardsWhite = UIColor(hex: "FFFFFF")
    static let goalRed     = UIColor(hex: "FF0000")
    static let textWhite   = UIColor(hex: "FFFFFF")
    static let textGray    = UIColor(hex: "AAAAAA")
    static let textGreen   = UIColor(hex: "00CC66")
    static let textRed     = UIColor(hex: "FF4444")
    static let textYellow  = UIColor(hex: "FFCC00")
}

// MARK: - Random Helpers
extension Array {
    func randomElement(using rng: inout RandomNumberGenerator) -> Element? {
        guard !isEmpty else { return nil }
        return self[Int.random(in: 0..<count, using: &rng)]
    }
}

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(other.x - x, other.y - y)
    }

    func normalized() -> CGPoint {
        let len = hypot(x, y)
        guard len > 0 else { return .zero }
        return CGPoint(x: x / len, y: y / len)
    }

    static func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func -(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func *(lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
}
