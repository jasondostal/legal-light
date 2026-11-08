import ActivityKit
import Foundation
import HoursCore

/// The "hunt" Live Activity: a countdown in the Dynamic Island and on the lock
/// screen. There's no push server, so the app can't update it once it's in
/// the background. Instead the activity carries the day's open and close, and
/// its staleDate is set to the next transition. When that passes, the system
/// marks it stale and redraws, and the views read stale as "the next phase".
/// One activity covers the change that matters (waiting → legal, or legal →
/// closed), and the app re-syncs it whenever it comes to the foreground.
struct HuntAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        enum Phase: String, Codable, Hashable { case before, open }
        var phase: Phase
        var open: Date
        var close: Date
    }
    var rules: RuleSet
    var spotName: String
    /// "Zone C +8 · southern table"
    var zoneLine: String
}

/// What the views show, after accounting for staleness.
enum HuntPhase: Hashable {
    case before, open, closed

    init(_ state: HuntAttributes.ContentState, stale: Bool) {
        switch (state.phase, stale) {
        case (.before, false): self = .before
        case (.before, true), (.open, false): self = .open
        case (.open, true): self = .closed
        }
    }

    func target(_ s: HuntAttributes.ContentState) -> Date? {
        switch self { case .before: return s.open; case .open: return s.close; case .closed: return nil }
    }

    /// Start of the current stretch, for progress bars.
    func since(_ s: HuntAttributes.ContentState) -> Date {
        switch self {
        case .before: return s.open.addingTimeInterval(-2 * 3600)
        case .open, .closed: return s.open
        }
    }

    var status: HoursStatus.State {
        switch self { case .before: return .before; case .open: return .open; case .closed: return .after }
    }

    var headline: String {
        switch self { case .before: return "Legal light in"; case .open: return "Legal · closes in"; case .closed: return "Closed for today" }
    }
}

extension HuntAttributes.ContentState {
    /// Content for a spot at `now`: waiting for the next opening, or legal until close.
    static func at(_ now: Date, spot: Spot) -> (state: Self, stale: Date) {
        let st = spot.status(at: now)
        switch st.state {
        case .before, .after:
            return (Self(phase: .before, open: st.hours.open, close: st.hours.close), st.hours.open)
        case .open:
            return (Self(phase: .open, open: st.hours.open, close: st.hours.close), st.hours.close)
        }
    }
}
