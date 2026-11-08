import Foundation

/// The app's idea of "now". Debug builds can pretend it's another moment for
/// store screenshots: `-now 2026-11-21T05:52:00-06:00` (the clock keeps running
/// from there). Release builds always use the real time.
enum Clock {
    static let offset: TimeInterval = {
        #if DEBUG
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-now"), i + 1 < args.count,
           let d = ISO8601DateFormatter().date(from: args[i + 1]) {
            return d.timeIntervalSinceNow
        }
        #endif
        return 0
    }()
    static var now: Date { Date().addingTimeInterval(offset) }
    static func adjust(_ d: Date) -> Date { d.addingTimeInterval(offset) }
}
