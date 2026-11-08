import ActivityKit
import Foundation
import HoursCore

/// Starts, re-syncs and ends the hunt Live Activity (see HuntAttributes).
@MainActor
enum HuntLive {
    enum Failure: LocalizedError {
        case disabled
        var errorDescription: String? { "Live Activities are off for Legal Light. Turn them on in Settings → Legal Light." }
    }

    static let testName = "Flip test"
    static var current: Activity<HuntAttributes>? { Activity<HuntAttributes>.activities.first }
    static var isRunning: Bool { current != nil }

    static func attributes(for spot: Spot) -> HuntAttributes {
        let z = LongitudeZone.at(lon: spot.lon)
        return HuntAttributes(rules: spot.rules, spotName: spot.name ?? "Your spot",
                              zoneLine: "Zone \(z.id) +\(z.minutes) · \(spot.area.rawValue)ern table")
    }

    static func start(_ spot: Spot) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { throw Failure.disabled }
        await endAll()
        let c = HuntAttributes.ContentState.at(Date(), spot: spot)
        _ = try Activity.request(attributes: attributes(for: spot),
                                 content: ActivityContent(state: c.state, staleDate: c.stale),
                                 pushType: nil)
    }

    /// On foreground or a change of spot/species: restart if what it's counting
    /// changed, end it if the day is done, otherwise bring its phase up to date.
    static func sync(_ spot: Spot) async {
        guard let a = current else { return }
        if a.attributes.spotName == testName { return }   // leave the debug flip test alone
        let now = Date()
        if a.attributes.rules != spot.rules || a.attributes.spotName != (spot.name ?? "Your spot") {
            try? await start(spot)
            return
        }
        // Past today's close with the app open: the hunt is over.
        if a.content.state.phase == .open, now >= a.content.state.close {
            await a.end(nil, dismissalPolicy: .immediate)
            return
        }
        let c = HuntAttributes.ContentState.at(now, spot: spot)
        if c.state != a.content.state {
            await a.update(ActivityContent(state: c.state, staleDate: c.stale))
        }
    }

    #if DEBUG
    /// Debug: a hunt whose legal light is 45 s away and close 2 min after, to
    /// watch the stale-date flip happen. simctl launch ... -hunttest
    static func startTest(_ spot: Spot) async throws {
        await endAll()
        let now = Date()
        let s = HuntAttributes.ContentState(phase: .before, open: now.addingTimeInterval(45), close: now.addingTimeInterval(165))
        var attrs = attributes(for: spot)
        attrs.spotName = testName
        _ = try Activity.request(attributes: attrs, content: ActivityContent(state: s, staleDate: s.open), pushType: nil)
    }
    #endif

    static func endAll() async {
        for a in Activity<HuntAttributes>.activities { await a.end(nil, dismissalPolicy: .immediate) }
    }
}
