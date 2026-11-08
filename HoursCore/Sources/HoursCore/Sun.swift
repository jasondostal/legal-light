import Foundation

/// NOAA solar calculator equations (Meeus, low precision): good to well under a
/// minute at these latitudes. A line-for-line port of the web engine, so the
/// computed fallback agrees with it to the millisecond.
public enum Sun {
    static let rad = Double.pi / 180
    /// Rise/set altitude: upper limb on a flat horizon with standard refraction (USNO).
    public static let riseAltitude = -0.8333

    public struct Times: Equatable, Sendable {
        public var sunrise: Date?
        public var sunset: Date?
        public var civilDawn: Date?
        public var civilDusk: Date?
        public var noon: Date
        public init(sunrise: Date?, sunset: Date?, civilDawn: Date?, civilDusk: Date?, noon: Date) {
            self.sunrise = sunrise; self.sunset = sunset; self.civilDawn = civilDawn; self.civilDusk = civilDusk; self.noon = noon
        }
    }

    static func julianCentury(_ ms: Double) -> Double { (ms / Central.dayMs + 2_440_587.5 - 2_451_545) / 36525 }

    /// Declination (deg) and equation of time (minutes) at instant ms.
    static func solar(_ ms: Double) -> (decl: Double, eot: Double) {
        let T = julianCentury(ms)
        let L0 = (280.46646 + T * (36000.76983 + T * 0.0003032)).truncatingRemainder(dividingBy: 360)
        let M = 357.52911 + T * (35999.05029 - 0.0001537 * T)
        let e = 0.016708634 - T * (0.000042037 + 0.0000001267 * T)
        let Mr = M * rad
        var C: Double = sin(Mr) * (1.914602 - T * (0.004817 + 0.000014 * T))
        C = C + sin(2 * Mr) * (0.019993 - 0.000101 * T)
        C = C + sin(3 * Mr) * 0.000289
        let omega = 125.04 - 1934.136 * T
        let lambda = L0 + C - 0.00569 - 0.00478 * sin(omega * rad)
        let eps0 = 23 + (26 + (21.448 - T * (46.815 + T * (0.00059 - T * 0.001813))) / 60) / 60
        let eps = eps0 + 0.00256 * cos(omega * rad)
        let decl = asin(sin(eps * rad) * sin(lambda * rad)) / rad
        let y = pow(tan(eps * rad / 2), 2)
        let L0r = L0 * rad
        // same left-to-right order as the JS, so the floats round identically
        var acc = y * sin(2 * L0r) - 2 * e * sin(Mr)
        acc = acc + 4 * e * y * sin(Mr) * cos(2 * L0r)
        acc = acc - 0.5 * y * y * sin(4 * L0r)
        acc = acc - 1.25 * e * e * sin(2 * Mr)
        let eot = 4 / rad * acc
        return (decl, eot)
    }

    /// Instant when the sun's centre crosses `alt` on calendar day ymd, rising
    /// (dir -1) or setting (dir +1); nil if it never reaches that altitude.
    static func crossing(_ ymd: YMD, lat: Double, lon: Double, alt: Double, dir: Double) -> Date? {
        let day0 = ymd.utcMidnightMs
        var t = day0 + (12 * 60 - 4 * lon) * 60_000
        for _ in 0..<4 {
            let s = solar(t)
            let num: Double = sin(alt * rad) - sin(lat * rad) * sin(s.decl * rad)
            let den: Double = cos(lat * rad) * cos(s.decl * rad)
            let cosH = num / den
            if cosH > 1 || cosH < -1 { return nil }
            let H = acos(cosH) / rad
            let mins: Double = 720 - 4 * lon + dir * 4 * H - s.eot
            t = day0 + mins * 60_000
        }
        return Date(ms: t)
    }

    static func solarNoon(_ ymd: YMD, lon: Double) -> Date {
        let day0 = ymd.utcMidnightMs
        var t = day0 + (720 - 4 * lon) * 60_000
        for _ in 0..<3 { t = day0 + (720 - 4 * lon - solar(t).eot) * 60_000 }
        return Date(ms: t)
    }

    public static func times(_ ymd: YMD, lat: Double, lon: Double) -> Times {
        Times(sunrise: crossing(ymd, lat: lat, lon: lon, alt: riseAltitude, dir: -1),
              sunset: crossing(ymd, lat: lat, lon: lon, alt: riseAltitude, dir: 1),
              civilDawn: crossing(ymd, lat: lat, lon: lon, alt: -6, dir: -1),
              civilDusk: crossing(ymd, lat: lat, lon: lon, alt: -6, dir: 1),
              noon: solarNoon(ymd, lon: lon))
    }

    /// Apparent altitude (deg, with refraction) at an instant.
    public static func altitude(at date: Date, lat: Double, lon: Double) -> Double {
        let ms = date.ms
        let s = solar(ms)
        let utcMin = ((ms.truncatingRemainder(dividingBy: Central.dayMs)) + Central.dayMs)
            .truncatingRemainder(dividingBy: Central.dayMs) / 60_000
        let ha = (utcMin + s.eot + 4 * lon) / 4 - 180
        let cosZ = sin(lat * rad) * sin(s.decl * rad) + cos(lat * rad) * cos(s.decl * rad) * cos(ha * rad)
        let h = 90 - acos(max(-1, min(1, cosZ))) / rad
        let r = h > -1 ? 1.02 / tan((h + 10.3 / (h + 5.11)) * rad) / 60 : 0
        return h + r
    }
}
