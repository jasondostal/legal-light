import Foundation

/// The spot the app and its widgets share, in the App Group's defaults.
public enum SharedStore {
    public static let appGroup = "group.dev.ducktyping.shootinghours"
    static let key = "spot.v1"

    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

    public static func load() -> Spot? {
        guard let d = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Spot.self, from: d)
    }

    public static func save(_ spot: Spot) {
        if let d = try? JSONEncoder().encode(spot) { defaults.set(d, forKey: key) }
    }
}
