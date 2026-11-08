import XCTest
@testable import HoursCore

/// Ground truth is the WI DNR's 2026 shooting hours tables (Fixtures/fixture.json,
/// transcribed from the PDFs) and the ducktyping.dev web engine's own answers
/// (Fixtures/web-cases.json, from tools/gen-data.mjs). Port of
/// ducktyping/scripts/check-shooting-hours.mjs plus a full cross-check.
final class HoursCoreTests: XCTestCase {
    struct Fixture: Decodable {
        let year: Int
        let tables: [String: [String]]
        let teal: [String: String]
        enum K: String, CodingKey { case year, teal }
        struct AnyKey: CodingKey { var stringValue: String; var intValue: Int? { nil }
            init?(stringValue: String) { self.stringValue = stringValue }; init?(intValue: Int) { nil } }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: K.self)
            year = try c.decode(Int.self, forKey: .year)
            teal = try c.decode([String: String].self, forKey: .teal)
            let a = try d.container(keyedBy: AnyKey.self)
            var t: [String: [String]] = [:]
            for k in ["wf-north", "wf-south", "dg-north", "dg-south"] { t[k] = try a.decode([String].self, forKey: AnyKey(stringValue: k)!) }
            tables = t
        }
    }

    static func fixture<T: Decodable>(_ name: String, _ t: T.Type) -> T {
        let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")!
        return try! JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
    static let FX = fixture("fixture", Fixture.self)

    static func hm(_ s: Substring) -> Int { let v = Int(s)!; return v / 100 * 60 + v % 100 }
    static func cell(_ key: String, _ m: Int, _ d: Int) -> (Int, Int) {
        let c = FX.tables[key]![m - 1].split(separator: " ")[d - 1].split(separator: "/")
        return (hm(c[0]), hm(c[1]))
    }
    static let tables: [(String, Area, RuleSet)] = [
        ("wf-north", .north, .waterfowl), ("wf-south", .south, .waterfowl),
        ("dg-north", .north, .smallgame), ("dg-south", .south, .smallgame),
    ]

    // ── 1. the computed fallback reproduces every 2026 entry within a minute ──
    func testComputedMatchesEveryTableEntry() {
        for (key, area, rules) in Self.tables {
            var n = 0, exact = 0, worst = 0
            for (mi, row) in Self.FX.tables[key]!.enumerated() {
                for (di, c) in row.split(separator: " ").enumerated() {
                    let p = c.split(separator: "/").map(Self.hm)
                    let r = Hours.zoneAComputed(YMD(Self.FX.year, mi + 1, di + 1), area, rules)
                    for (got, want) in [(r.am, p[0]), (r.pm, p[1])] {
                        n += 1; if got == want { exact += 1 }; worst = max(worst, abs(got - want))
                    }
                }
            }
            XCTAssertEqual(n, 730, key)
            XCTAssertLessThanOrEqual(worst, 1, "\(key): max error \(worst) min")
            XCTAssertGreaterThan(Double(exact) / Double(n), 0.9, key)
        }
        for area in Area.allCases {
            for (i, c) in Self.FX.teal[area.rawValue]!.split(separator: " ").enumerated() {
                let p = c.split(separator: "/").map(Self.hm)
                let r = Hours.zoneAComputed(YMD(Self.FX.year, 9, i + 1), area, .teal)
                XCTAssertLessThanOrEqual(abs(r.am - p[0]), 1); XCTAssertLessThanOrEqual(abs(r.pm - p[1]), 1)
            }
        }
    }

    // ── 1b. the official lookup is exact, every entry ──
    func testOfficialLookupIsExact() {
        for (key, area, rules) in Self.tables {
            for (mi, row) in Self.FX.tables[key]!.enumerated() {
                for (di, c) in row.split(separator: " ").enumerated() {
                    let p = c.split(separator: "/").map(Self.hm)
                    let r = Hours.zoneA(YMD(Self.FX.year, mi + 1, di + 1), area, rules)
                    XCTAssertEqual(r.am, p[0]); XCTAssertEqual(r.pm, p[1]); XCTAssertEqual(r.source, .dnr)
                }
            }
        }
        for area in Area.allCases {
            for (i, c) in Self.FX.teal[area.rawValue]!.split(separator: " ").enumerated() {
                let p = c.split(separator: "/").map(Self.hm)
                let r = Hours.zoneA(YMD(Self.FX.year, 9, i + 1), area, .teal)
                XCTAssertEqual(r.am, p[0], "teal \(area) 9/\(i + 1)"); XCTAssertEqual(r.pm, p[1])
            }
        }
        XCTAssertEqual(Hours.zoneA(YMD(Self.FX.year + 1, 10, 18), .south, .waterfowl).source, .computed)
        XCTAssertEqual(Bundled.official.publishedYears, [2026])
    }

    // ── 2. locations across the state: county, area, zone, final times ──
    func testLocationsAcrossTheState() {
        let places = Dictionary(uniqueKeysWithValues: Bundled.geo.places.map { ($0.name, $0) })
        let whereList: [(String, String, Area, String)] = [
            ("Kewaunee", "Kewaunee", .south, "A"), ("Sturgeon Bay", "Door", .north, "A"),
            ("Milwaukee", "Milwaukee", .south, "A"), ("Marinette", "Marinette", .north, "A"),
            ("Appleton", "Outagamie", .south, "B"), ("Horicon", "Dodge", .south, "B"),
            ("Oshkosh", "Winnebago", .south, "B"), ("Beloit", "Rock", .south, "C"),
            ("Madison", "Dane", .south, "C"), ("Wausau", "Marathon", .north, "C"),
            ("Eagle River", "Vilas", .north, "C"), ("Wisconsin Rapids", "Wood", .south, "C"),
            ("Hurley", "Iron", .north, "D"), ("Black River Falls", "Jackson", .south, "D"),
            ("La Crosse", "La Crosse", .south, "E"), ("Prairie du Chien", "Crawford", .south, "E"),
            ("Eau Claire", "Eau Claire", .north, "E"), ("Hayward", "Sawyer", .north, "E"),
            ("Alma", "Buffalo", .south, "E"), ("Superior", "Douglas", .north, "F"),
            ("Hudson", "St. Croix", .north, "F"), ("Ellsworth", "Pierce", .north, "F"),
        ]
        let zmin = ["A": 0, "B": 4, "C": 8, "D": 12, "E": 16, "F": 20]
        let dates = [(9, 26), (10, 3), (10, 17), (10, 18), (10, 31), (11, 1), (11, 2), (11, 21), (11, 24), (12, 6)]
        for (name, county, area, zone) in whereList {
            let p = places[name]!
            let loc = Locate.county(lat: p.lat, lon: p.lon)
            XCTAssertEqual(loc.county, county, name); XCTAssertEqual(loc.area, area, name)
            XCTAssertEqual(LongitudeZone.at(lon: p.lon).id, zone, name)
            for (m, d) in dates {
                for rules in [RuleSet.waterfowl, .smallgame] {
                    let (am, pm) = Self.cell((rules == .waterfowl ? "wf-" : "dg-") + area.rawValue, m, d)
                    let r = Hours(YMD(2026, m, d), lat: p.lat, lon: p.lon, area: loc.area, rules: rules)
                    XCTAssertEqual(r.openMin, am + zmin[zone]!); XCTAssertEqual(r.closeMin, pm + zmin[zone]!)
                    XCTAssertEqual(r.open, Central.toDate(YMD(2026, m, d), minutes: am + zmin[zone]!))
                    XCTAssertEqual(r.close, Central.toDate(YMD(2026, m, d), minutes: pm + zmin[zone]!))
                }
            }
        }
    }

    func testMapDataLoads() {
        XCTAssertEqual(Bundled.map.countyLabels.count, 72)
        XCTAssertEqual(Bundled.map.neighbors.count, 4)
        XCTAssertFalse(Bundled.map.areaLine.isEmpty)
    }

    func testOutOfStateAndOpenWater() {
        XCTAssertFalse(Locate.county(lat: 44.98, lon: -93.27).inside) // Minneapolis
        XCTAssertFalse(Locate.county(lat: 45.745, lon: -87.065).inside) // Escanaba
        XCTAssertTrue(Locate.county(lat: 44.75, lon: -87.85).inside) // Green Bay water snaps
    }

    func testDuckZones() {
        let cases: [(String, Double, Double, Locate.DuckZone)] = [
            ("Superior", 46.692, -92.080, .north), ("Hudson", 44.975, -92.757, .north), ("Eau Claire", 44.811, -91.498, .north),
            ("Wausau", 44.962, -89.647, .north), ("Marshfield", 44.669, -90.172, .north), ("Lena", 45.05, -88.05, .north),
            ("Oconto", 44.887, -87.865, .south), ("Sturgeon Bay", 44.823, -87.370, .south), ("Green Bay, east", 44.50, -87.95, .south),
            ("Appleton", 44.262, -88.407, .south), ("La Crosse", 43.801, -91.240, .south), ("Madison", 43.073, -89.401, .south),
            ("Lake Winnebago", 44.00, -88.42, .south), ("Green Bay (water)", 44.75, -87.85, .open), ("off Milwaukee", 43.05, -87.75, .open),
            ("off Door Co.", 44.95, -87.05, .open),
        ]
        for (name, lat, lon, want) in cases {
            let z = Locate.duckZone(lat: lat, lon: lon, where: Locate.county(lat: lat, lon: lon))
            XCTAssertEqual(z?.zone, want, name)
        }
        XCTAssertNil(Locate.duckZone(lat: 44.98, lon: -93.27, where: Locate.county(lat: 44.98, lon: -93.27)))
    }

    // ── 3. time zone ──
    func testTimeZone() {
        let utc = { (y: Int, m: Int, d: Int, h: Int) in Date(timeIntervalSince1970: Double(Central.utcDays(y, m, d)) * 86400 + Double(h) * 3600) }
        XCTAssertEqual(Central.offsetMinutes(at: utc(2026, 3, 8, 8).addingTimeInterval(-1)), -360)
        XCTAssertEqual(Central.offsetMinutes(at: utc(2026, 3, 8, 8)), -300)
        XCTAssertEqual(Central.offsetMinutes(at: utc(2026, 11, 1, 7).addingTimeInterval(-1)), -300)
        XCTAssertEqual(Central.offsetMinutes(at: utc(2026, 11, 1, 7)), -360)
        for (m, d) in [(3, 7), (3, 8), (3, 9), (10, 31), (11, 1), (11, 2), (12, 31)] {
            for min in [0, 361, 720, 1100, 1439] {
                let p = Central.parts(Central.toDate(YMD(2026, m, d), minutes: min))
                XCTAssertEqual(p.ymd, YMD(2026, m, d)); XCTAssertEqual(p.h * 60 + p.min, min, "\(m)/\(d) \(min)")
            }
        }
        XCTAssertEqual(YMD(2026, 11, 8).weekday, 0) // a Sunday
        XCTAssertEqual(YMD(2026, 12, 31).adding(days: 1), YMD(2027, 1, 1))
        XCTAssertEqual(YMD(2028, 2, 28).adding(days: 1), YMD(2028, 2, 29))
    }

    func testFormat() {
        XCTAssertEqual(Fmt.minutes(6 * 60 + 5), "6:05 a.m.")
        XCTAssertEqual(Fmt.minutes(17 * 60 + 41), "5:41 p.m.")
        XCTAssertEqual(Fmt.minutes(12 * 60), "12:00 p.m.")
        XCTAssertEqual(Fmt.duration(3723), "1:02:03")
        XCTAssertEqual(Fmt.duration(754), "12:34")
        XCTAssertEqual(Fmt.day(YMD(2026, 11, 21)), "Sat Nov 21")
    }

    func testStatusAndTransitions() {
        let spot = Spot(lat: 43.0731, lon: -89.4012, rules: .waterfowl)
        let today = spot.hours(on: YMD(2026, 10, 18))
        let six = Central.toDate(YMD(2026, 10, 18), minutes: 360)
        XCTAssertEqual(spot.status(at: six).state, .before)
        XCTAssertEqual(spot.status(at: six).target, today.open)
        XCTAssertEqual(spot.status(at: today.open.addingTimeInterval(1)).state, .open)
        XCTAssertEqual(spot.status(at: today.open.addingTimeInterval(1)).target, today.close)
        let after = spot.status(at: today.close.addingTimeInterval(1))
        XCTAssertEqual(after.state, .after)
        XCTAssertEqual(after.target, spot.hours(on: YMD(2026, 10, 19)).open)
        XCTAssertEqual(after.since, today.close)
        XCTAssertEqual(spot.status(at: six).since, spot.hours(on: YMD(2026, 10, 17)).close)
        XCTAssertEqual(spot.status(at: today.open).progress(at: today.open), 0)
        let spotJSON = try! JSONEncoder().encode(Spot(lat: 1, lon: 2, name: "x", gps: true, rules: .teal, areaOverride: .north))
        XCTAssertEqual(try! JSONDecoder().decode(Spot.self, from: spotJSON), Spot(lat: 1, lon: 2, name: "x", gps: true, rules: .teal, areaOverride: .north))
        let tr = spot.transitions(from: six, days: 3)
        XCTAssertEqual(tr.count, 6); XCTAssertEqual(tr.first, today.open)
        XCTAssertEqual(tr, tr.sorted())
        // deer opener, Stevens Point: 30 before sunrise to 20 after sunset, zone C (+8)
        let deer = Spot.stevensPoint.hours(on: YMD(2026, 11, 21), rules: .smallgame)
        XCTAssertEqual(deer.zone.id, "C"); XCTAssertEqual(deer.area, .south)
        XCTAssertEqual(deer.openMin, Self.cell("dg-south", 11, 21).0 + 8)
    }

    // ── 4. the web engine's own answers, ~5k cases incl. computed years ──
    struct WebCase: Decodable {
        struct D: Decodable { let y: Int, m: Int, d: Int }
        let lat: Double, lon: Double, ymd: D, season: String
        let county: String?, area: String, inside: Bool, duck: String?, zone: String
        let openMin: Int, closeMin: Int, source: String, open: Double, close: Double
        let sunrise: Double?, sunset: Double?
    }

    func testMatchesWebEngine() {
        let cases = Self.fixture("web-cases", [WebCase].self)
        XCTAssertGreaterThan(cases.count, 4000)
        var worstSun = 0.0, computed = 0
        for c in cases {
            let ymd = YMD(c.ymd.y, c.ymd.m, c.ymd.d)
            let w = Locate.county(lat: c.lat, lon: c.lon)
            XCTAssertEqual(w.county, c.county); XCTAssertEqual(w.area.rawValue, c.area); XCTAssertEqual(w.inside, c.inside)
            XCTAssertEqual(Locate.duckZone(lat: c.lat, lon: c.lon, where: w)?.zone.rawValue, c.duck, "\(c.lat),\(c.lon)")
            let h = Hours(ymd, lat: c.lat, lon: c.lon, area: w.area, rules: RuleSet(rawValue: c.season)!)
            let tag = "\(ymd) \(c.season) \(c.lat),\(c.lon)"
            XCTAssertEqual(h.zone.id, c.zone, tag)
            XCTAssertEqual(h.openMin, c.openMin, tag); XCTAssertEqual(h.closeMin, c.closeMin, tag)
            XCTAssertEqual(h.source.rawValue, c.source, tag)
            XCTAssertEqual(h.open.ms, c.open, accuracy: 0.5, tag); XCTAssertEqual(h.close.ms, c.close, accuracy: 0.5, tag)
            if let s = c.sunrise { worstSun = max(worstSun, abs(h.localSun.sunrise!.ms - s)) }
            if let s = c.sunset { worstSun = max(worstSun, abs(h.localSun.sunset!.ms - s)) }
            if c.source == "computed" { computed += 1 }
        }
        XCTAssertLessThan(worstSun, 1, "local sun differs from the web engine by \(worstSun) ms")
        XCTAssertGreaterThan(computed, 1000)
    }
}
