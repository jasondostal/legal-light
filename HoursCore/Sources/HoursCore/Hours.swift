import Foundation

/// Legal shooting hours, the DNR way (Wis. Admin. Code NR 10.06).
///
/// The legal time for a spot is NOT the sunrise at that spot. It is the
/// reference town's sunrise (Powers, MI for the northern area, Sheboygan for
/// the southern), rounded to the minute as the table prints it, plus the
/// longitude zone's minutes. When we carry the DNR's printed table for the
/// year we read it directly; otherwise we compute the reference town's sun
/// (matches all 2,920 entries of the 2026 tables within a minute).
///
/// Times are Wisconsin clock time including daylight time, as the tables are
/// printed (the code says "Central Standard Time"; the tables follow DST).
public struct Hours: Equatable, Sendable {
    public enum Source: String, Sendable { case dnr, computed }

    public let date: YMD
    public let rules: RuleSet
    public let area: Area
    public let zone: LongitudeZone
    /// Zone A table values, minutes after Wisconsin midnight.
    public let tableAm: Int, tablePm: Int
    public let source: Source
    public let openMin: Int, closeMin: Int
    public let open: Date, close: Date
    /// The true sun at the exact coordinates, for interest.
    public let localSun: Sun.Times

    public static func == (a: Hours, b: Hours) -> Bool {
        a.date == b.date && a.rules == b.rules && a.area == b.area && a.open == b.open && a.close == b.close
    }

    public var isDST: Bool { Central.isDST(at: Central.toDate(date, minutes: 720)) }
    public var length: TimeInterval { close.timeIntervalSince(open) }

    /// Zone A entry computed from the reference town's sun.
    public static func zoneAComputed(_ ymd: YMD, _ area: Area, _ rules: RuleSet) -> (am: Int, pm: Int) {
        let r = area.reference
        let st = Sun.times(ymd, lat: r.lat, lon: r.lon)
        // The reference towns always have a sunrise and sunset.
        return (Central.roundedMinutes(st.sunrise!) + rules.openOffset, Central.roundedMinutes(st.sunset!) + rules.closeOffset)
    }

    /// The DNR's printed value when we carry the year, else computed.
    public static func zoneA(_ ymd: YMD, _ area: Area, _ rules: RuleSet, official: Official = Bundled.official) -> (am: Int, pm: Int, source: Source) {
        if let o = official.entry(ymd, area, rules) { return (o.am, o.pm, .dnr) }
        let c = zoneAComputed(ymd, area, rules)
        return (c.am, c.pm, .computed)
    }

    public init(_ ymd: YMD, lat: Double, lon: Double, area: Area, rules: RuleSet, official: Official = Bundled.official) {
        let zone = LongitudeZone.at(lon: lon)
        let a = Hours.zoneA(ymd, area, rules, official: official)
        date = ymd; self.rules = rules; self.area = area; self.zone = zone
        tableAm = a.am; tablePm = a.pm; source = a.source
        openMin = a.am + zone.minutes; closeMin = a.pm + zone.minutes
        open = Central.toDate(ymd, minutes: openMin)
        close = Central.toDate(ymd, minutes: closeMin)
        localSun = Sun.times(ymd, lat: lat, lon: lon)
    }

    public var localOpen: Date? { localSun.sunrise?.addingTimeInterval(Double(rules.openOffset) * 60) }
    public var localClose: Date? { localSun.sunset?.addingTimeInterval(Double(rules.closeOffset) * 60) }
}

/// Where the countdown is pointing.
public struct HoursStatus: Equatable, Sendable {
    public enum State: String, Sendable { case before, open, after }
    public let state: State
    /// The previous transition (when this state began).
    public let since: Date
    /// The next transition: opening (before/after) or closing (open).
    public let target: Date
    /// The day whose window `target` belongs to.
    public let hours: Hours

    public var isLegal: Bool { state == .open }
    /// 0 → 1 through the current state, for progress rings.
    public func progress(at now: Date) -> Double {
        let span = target.timeIntervalSince(since)
        return span > 0 ? min(1, max(0, now.timeIntervalSince(since) / span)) : 1
    }
}

/// A spot and rule set: everything needed to answer "when is it legal?".
public struct Spot: Codable, Equatable, Sendable {
    public var lat: Double
    public var lon: Double
    public var name: String?
    /// The spot came from a GPS fix (refresh it when the app opens).
    public var gps: Bool
    public var rules: RuleSet
    /// nil = from the county lookup.
    public var areaOverride: Area?

    public init(lat: Double, lon: Double, name: String? = nil, gps: Bool = false, rules: RuleSet = .waterfowl, areaOverride: Area? = nil) {
        self.lat = lat; self.lon = lon; self.name = name; self.gps = gps; self.rules = rules; self.areaOverride = areaOverride
    }

    public var whereabouts: Locate.Where { Locate.county(lat: lat, lon: lon) }
    public var area: Area { areaOverride ?? whereabouts.area }

    public func hours(on ymd: YMD, rules r: RuleSet? = nil) -> Hours {
        Hours(ymd, lat: lat, lon: lon, area: area, rules: r ?? rules)
    }

    /// Status at `now`: before today's opening, open until today's close, or
    /// after close and counting to tomorrow's opening.
    public func status(at now: Date = Date(), rules r: RuleSet? = nil) -> HoursStatus {
        let today = Central.today(now)
        let h = hours(on: today, rules: r)
        if now < h.open {
            let y = hours(on: today.adding(days: -1), rules: r)
            return HoursStatus(state: .before, since: y.close, target: h.open, hours: h)
        }
        if now < h.close { return HoursStatus(state: .open, since: h.open, target: h.close, hours: h) }
        let t = hours(on: today.adding(days: 1), rules: r)
        return HoursStatus(state: .after, since: h.close, target: t.open, hours: t)
    }

    /// Every open/close instant from `from` for `days` days: the moments a
    /// widget timeline must refresh at.
    public func transitions(from: Date, days: Int, rules r: RuleSet? = nil) -> [Date] {
        let d0 = Central.today(from)
        return (0..<days).flatMap { i -> [Date] in
            let h = hours(on: d0.adding(days: i), rules: r)
            return [h.open, h.close]
        }.filter { $0 > from }
    }

    public static let stevensPoint = Spot(lat: 44.5253, lon: -89.5504, name: "Stevens Point")
}
