import Foundation

/// Bundled data, generated from the ducktyping.dev web toy by tools/gen-data.mjs.
public enum Bundled {
    static func json<T: Decodable>(_ name: String, as: T.Type) -> T {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Resources"),
              let data = try? Data(contentsOf: url),
              let v = try? JSONDecoder().decode(T.self, from: data)
        else { fatalError("HoursCore: bundled \(name).json missing or malformed") }
        return v
    }

    public static let official = Official(json("official", as: Official.File.self))
    public static let geo = json("geo", as: Geo.self)
    public static let ducks = json("ducks", as: DuckData.self)
}

/// The DNR's published Zone A tables, verbatim: one string per month, one
/// "HMM/HHMM" cell per day, 24 h Wisconsin clock time.
public struct Official: Sendable {
    struct File: Decodable { let years: [String: [String: [String: [String]]]] }
    let years: [Int: [String: [String: [String]]]]

    init(_ f: File) {
        var y: [Int: [String: [String: [String]]]] = [:]
        for (k, v) in f.years { if let n = Int(k) { y[n] = v } }
        years = y
    }

    public var publishedYears: [Int] { years.keys.sorted() }

    /// (am, pm) in minutes after Wisconsin midnight, or nil if we don't carry
    /// that date. Teal and spring turkey ride on the waterfowl table: teal opens
    /// at sunrise, which is the waterfowl opening + 30.
    public func entry(_ ymd: YMD, _ area: Area, _ rules: RuleSet) -> (am: Int, pm: Int)? {
        guard let months = years[ymd.y]?[area.rawValue]?[rules.tableKey], ymd.m - 1 < months.count else { return nil }
        let cells = months[ymd.m - 1].split(separator: " ")
        guard ymd.d - 1 < cells.count else { return nil }
        let p = cells[ymd.d - 1].split(separator: "/").compactMap { Int($0) }
        guard p.count == 2 else { return nil }
        let hm = { (v: Int) in v / 100 * 60 + v % 100 }
        var am = hm(p[0])
        if rules == .teal { am += 30 }
        return (am, hm(p[1]))
    }
}

/// [lon, lat] rings; a polygon is an outer ring plus holes (even-odd rule).
public typealias Ring = [[Double]]

public struct Geo: Decodable, Sendable {
    public struct County: Decodable, Sendable { public let name: String; public let area: Area; public let polys: [[Ring]] }
    public struct Place: Decodable, Sendable, Hashable, Identifiable {
        public let name: String, county: String, lat: Double, lon: Double, seat: Bool
        public var id: String { name }
    }
    public let counties: [County]
    public let places: [Place]
}

public struct DuckData: Decodable, Sendable {
    public let duckLine: [[Double]]
    public let openWater: [[Ring]]
}
