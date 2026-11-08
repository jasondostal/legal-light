import SwiftUI
import HoursCore

/// Dark-first, pre-dawn palette. State is carried by colour: cold blue while
/// you wait for light, hot amber while it's legal, dim slate once it's over.
enum Theme {
    static let bg = Color(red: 0.035, green: 0.047, blue: 0.075)
    static let card = Color(red: 0.075, green: 0.090, blue: 0.130)
    static let line = Color.white.opacity(0.08)
    static let text = Color(red: 0.93, green: 0.94, blue: 0.96)
    static let dim = Color(red: 0.58, green: 0.62, blue: 0.70)

    static let waiting = Color(red: 0.42, green: 0.66, blue: 1.00)  // before light
    static let legal = Color(red: 1.00, green: 0.66, blue: 0.20)    // legal
    static let done = Color(red: 0.62, green: 0.56, blue: 0.86)     // after close
    static let warn = Color(red: 1.00, green: 0.45, blue: 0.38)

    static func color(_ s: HoursStatus.State) -> Color {
        switch s { case .before: return waiting; case .open: return legal; case .after: return done }
    }

    static func headline(_ s: HoursStatus.State) -> String {
        switch s {
        case .before: return "Legal light in"
        case .open: return "Legal · closes in"
        case .after: return "Done for today · opens in"
        }
    }
}
