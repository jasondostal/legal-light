import Foundation

/// The two shooting-hours areas (Wis. Admin. Code NR 10.06(2)). Northern =
/// Pierce, Dunn, Eau Claire, Clark, Marathon, Shawano, Oconto and Door counties
/// and every county north of them; southern = the rest.
public enum Area: String, Codable, CaseIterable, Sendable {
    case north, south
    public var name: String { self == .north ? "Northern" : "Southern" }

    /// The reference town whose USNO sunrise/sunset sets Zone A, at whole-arc-minute
    /// coordinates (the precision USNO's tables take).
    public var reference: (name: String, lat: Double, lon: Double) {
        switch self {
        case .north: return ("Powers, MI", 45 + 41.0 / 60, -(87 + 32.0 / 60))
        case .south: return ("Sheboygan, WI", 43 + 45.0 / 60, -(87 + 43.0 / 60))
        }
    }
}

/// Longitude zones: A east of 88° W, then +4 minutes per degree west to F.
public struct LongitudeZone: Equatable, Sendable {
    public let id: String, minutes: Int, desc: String
    public static let all: [LongitudeZone] = [
        .init(id: "A", minutes: 0, desc: "east of 88° W"),
        .init(id: "B", minutes: 4, desc: "88°–89° W"),
        .init(id: "C", minutes: 8, desc: "89°–90° W"),
        .init(id: "D", minutes: 12, desc: "90°–91° W"),
        .init(id: "E", minutes: 16, desc: "91°–92° W"),
        .init(id: "F", minutes: 20, desc: "west of 92° W"),
    ]
    public static func at(lon: Double) -> LongitudeZone {
        let w = -lon
        let i = w <= 88 ? 0 : w >= 92 ? 5 : Int((w - 88).rounded(.up))
        return all[i]
    }
}

/// The rule sets. Every Wisconsin species falls under one of these four.
public enum RuleSet: String, Codable, CaseIterable, Identifiable, Sendable {
    case waterfowl, teal, smallgame, springturkey
    public var id: String { rawValue }

    /// Minutes relative to sunrise / sunset.
    public var openOffset: Int { self == .teal ? 0 : -30 }
    public var closeOffset: Int { self == .smallgame ? 20 : 0 }

    public var label: String {
        switch self {
        case .waterfowl: return "Ducks & geese"
        case .teal: return "Early teal"
        case .smallgame: return "Deer & small game"
        case .springturkey: return "Spring turkey"
        }
    }
    public var short: String {
        switch self {
        case .waterfowl: return "Waterfowl"
        case .teal: return "Teal"
        case .smallgame: return "Deer"
        case .springturkey: return "Turkey"
        }
    }
    /// What the rule covers, in the regulation's words.
    public var covers: String {
        switch self {
        case .waterfowl: return "Ducks, geese, coot, mourning dove and other migratory game birds"
        case .teal: return "The September teal-only season"
        case .smallgame: return "Deer, bear, small game and fall turkey"
        case .springturkey: return "Spring turkey"
        }
    }
    public var rule: String {
        switch self {
        case .waterfowl, .springturkey: return "30 minutes before sunrise to sunset"
        case .teal: return "Sunrise to sunset"
        case .smallgame: return "30 minutes before sunrise to 20 minutes after sunset"
        }
    }
    var tableKey: String { self == .smallgame ? "smallgame" : "waterfowl" }
}
