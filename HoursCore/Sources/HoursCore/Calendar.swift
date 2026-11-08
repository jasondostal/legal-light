import Foundation

/// A Wisconsin calendar day. Every date in the app is a Wisconsin date, whatever
/// zone the phone is set to: the DNR tables are printed in Wisconsin clock time.
public struct YMD: Hashable, Codable, Comparable, Sendable, CustomStringConvertible {
    public var y: Int, m: Int, d: Int
    public init(_ y: Int, _ m: Int, _ d: Int) { self.y = y; self.m = m; self.d = d }

    public static func < (a: YMD, b: YMD) -> Bool { (a.y, a.m, a.d) < (b.y, b.m, b.d) }
    public var description: String { String(format: "%04d-%02d-%02d", y, m, d) }

    /// 00:00 UTC on this calendar date, in ms (the engine's day0).
    var utcMidnightMs: Double { Double(Central.utcDays(y, m, d)) * Central.dayMs }

    public func adding(days n: Int) -> YMD {
        let t = Central.utcDays(y, m, d) + n
        return Central.civil(fromDays: t)
    }

    /// 0 = Sunday.
    public var weekday: Int { ((Central.utcDays(y, m, d) % 7) + 11) % 7 }
}

/// Wisconsin wall-clock time. America/Chicago from the system tz database,
/// which carries the same US rule the web engine hand-codes.
public enum Central {
    public static let zone = TimeZone(identifier: "America/Chicago")!
    static let dayMs = 86_400_000.0

    static var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = zone
        return c
    }()

    /// Days since 1970-01-01 for a proleptic Gregorian date (Howard Hinnant's algorithm).
    static func utcDays(_ y0: Int, _ m: Int, _ d: Int) -> Int {
        let y = m <= 2 ? y0 - 1 : y0
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (m + 9) % 12
        let doy = (153 * mp + 2) / 5 + d - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    static func civil(fromDays z0: Int) -> YMD {
        let z = z0 + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        return YMD(yoe + era * 400 + (m <= 2 ? 1 : 0), m, d)
    }

    /// UTC offset in minutes at an instant (-300 CDT, -360 CST).
    public static func offsetMinutes(at date: Date) -> Int { zone.secondsFromGMT(for: date) / 60 }
    public static func isDST(at date: Date) -> Bool { zone.isDaylightSavingTime(for: date) }

    public struct Parts: Equatable { public var ymd: YMD; public var h: Int, min: Int, s: Int }

    public static func parts(_ date: Date) -> Parts {
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return Parts(ymd: YMD(c.year!, c.month!, c.day!), h: c.hour!, min: c.minute!, s: c.second!)
    }

    public static func today(_ now: Date = Date()) -> YMD { parts(now).ymd }

    /// The instant of a Wisconsin wall-clock time, `minutes` after local midnight
    /// (may exceed 1440 or go negative; it is just an offset from midnight in
    /// wall-clock minutes, resolved with the offset in force at that moment).
    public static func toDate(_ ymd: YMD, minutes: Int) -> Date {
        // Same two-step settle as the web engine, so results match it exactly.
        let base = ymd.utcMidnightMs + Double(minutes) * 60_000
        let guess = base + 360 * 60_000
        let off = offsetMinutes(at: Date(timeIntervalSince1970: guess / 1000))
        var ms = base - Double(off) * 60_000
        let off2 = offsetMinutes(at: Date(timeIntervalSince1970: ms / 1000))
        if off2 != off { ms = base - Double(off2) * 60_000 }
        return Date(timeIntervalSince1970: ms / 1000)
    }

    /// Minutes after Wisconsin midnight, rounded to the nearest minute (half up),
    /// the way the DNR table prints a time.
    public static func roundedMinutes(_ date: Date) -> Int {
        let p = parts(date.addingTimeInterval(30))
        return p.h * 60 + p.min
    }
}

extension Date {
    var ms: Double { timeIntervalSince1970 * 1000 }
    init(ms: Double) { self.init(timeIntervalSince1970: ms / 1000) }
}
