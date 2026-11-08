import Foundation

public enum Fmt {
    /// "6:05 a.m." from minutes after Wisconsin midnight.
    public static func minutes(_ min0: Int, bare: Bool = false) -> String {
        let min = ((min0 % 1440) + 1440) % 1440
        let h = min / 60, mm = min % 60
        let h12 = h % 12 == 0 ? 12 : h % 12
        let s = "\(h12):" + (mm < 10 ? "0" : "") + "\(mm)"
        return bare ? s : s + (h < 12 ? " a.m." : " p.m.")
    }

    /// Wisconsin clock time of an instant, rounded to the minute.
    public static func time(_ d: Date?, bare: Bool = false) -> String {
        guard let d else { return "—" }
        return minutes(Central.roundedMinutes(d), bare: bare)
    }

    /// "1:02:03" or "12:34".
    public static func duration(_ t: TimeInterval) -> String {
        let s = max(0, Int(t.rounded(.down)))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        let p = { (n: Int) in (n < 10 ? "0" : "") + "\(n)" }
        return h > 0 ? "\(h):\(p(m)):\(p(sec))" : "\(m):\(p(sec))"
    }

    /// "10 h 42 m" for a window length.
    public static func span(_ t: TimeInterval) -> String {
        let m = Int((t / 60).rounded())
        return "\(m / 60) h \(m % 60) m"
    }

    static let dow = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    static let mon = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    public static func day(_ d: YMD) -> String { "\(dow[d.weekday]) \(mon[d.m - 1]) \(d.d)" }
}
