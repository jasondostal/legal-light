import ActivityKit
import Foundation
import HoursCore

/// Starts, re-syncs and ends the hunt Live Activities.
///
/// A Live Activity can't change itself without a push server, and the staleDate
/// redraw turned out not to happen on a real phone (2026-11-08 flip test: the
/// countdown froze at 0:00). iOS 26 can schedule an activity to *start* later
/// with nothing running, so a hunt is a short chain of activities, each counting
/// to one moment:
///   lead-in   now → legal light          ("Legal light in")
///   legal     starts at legal light → close ("Legal · closes in"), with an alert
///   late      starts 7 h 45 m into legal, when the day is longer than the
///             8-hour Live Activity cap → close
/// Later links rank higher, so the Dynamic Island moves to them as they start.
/// The app tidies up the finished links whenever it comes forward.
@MainActor
enum HuntLive {
    enum Failure: LocalizedError {
        case disabled
        var errorDescription: String? { "Live Activities are off for Legal Light. Turn them on in Settings → Legal Light." }
    }

    static let testName = "Flip test"
    static let cap: TimeInterval = 7 * 3600 + 50 * 60   // under the 8 h system limit

    static var all: [Activity<HuntAttributes>] {
        Activity<HuntAttributes>.activities.filter { $0.activityState != .ended && $0.activityState != .dismissed }
    }
    static var isRunning: Bool { !all.isEmpty }
    static var current: Activity<HuntAttributes>? { all.first }

    static func attributes(for spot: Spot) -> HuntAttributes {
        let z = LongitudeZone.at(lon: spot.lon)
        return HuntAttributes(rules: spot.rules, spotName: spot.name ?? "Your spot",
                              zoneLine: "Zone \(z.id) +\(z.minutes) · \(spot.area.rawValue)ern table")
    }

    /// The opening times a scheduled "legal" link will announce (so the plain
    /// legal-light notification can stand down for those days).
    static var announcedOpens: Set<Date> {
        Set(all.filter(isPending).map { $0.content.state.open })
    }

    static func isPending(_ a: Activity<HuntAttributes>) -> Bool {
        if #available(iOS 26.0, *) { return a.activityState == .pending }
        return false
    }

    static func start(_ spot: Spot) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { throw Failure.disabled }
        await endAll()
        let st = spot.status(at: Date())
        try chain(attributes(for: spot), open: st.hours.open, close: st.hours.close,
                  legalNow: st.state == .open, rules: spot.rules, spot: spot.name ?? "your spot")
        Alerts.reschedule(spot)
    }

    /// Request the links for one day's window.
    private static func chain(_ attrs: HuntAttributes, open: Date, close: Date, legalNow: Bool,
                              rules: RuleSet, spot: String) throws {
        let now = Date()
        let legal = HuntAttributes.ContentState(phase: .open, open: open, close: close)
        var legalStart = open
        if legalNow {
            _ = try Activity.request(attributes: attrs,
                                     content: ActivityContent(state: legal, staleDate: close, relevanceScore: 20),
                                     pushType: nil)
            legalStart = now
        } else {
            var lead = HuntAttributes.ContentState(phase: .before, open: open, close: close)
            lead.handoff = true
            _ = try Activity.request(attributes: attrs,
                                     content: ActivityContent(state: lead, staleDate: open, relevanceScore: 10),
                                     pushType: nil)
            guard #available(iOS 26.0, *) else { return }   // older iOS: the lead-in alone
            _ = try Activity.request(
                attributes: attrs, content: ActivityContent(state: legal, staleDate: close, relevanceScore: 20),
                pushType: nil, style: .standard,
                alertConfiguration: AlertConfiguration(title: "Legal light · \(rules.short)",
                                                       body: "Shooting hours are open at \(spot). Closes at \(Fmt.time(close)).",
                                                       sound: .default),
                start: open)
        }
        // The 8-hour cap: hand over to a fresh link before the legal one expires.
        if #available(iOS 26.0, *), close.timeIntervalSince(legalStart) > cap {
            _ = try Activity.request(
                attributes: attrs, content: ActivityContent(state: legal, staleDate: close, relevanceScore: 30),
                pushType: nil, style: .standard,
                alertConfiguration: AlertConfiguration(title: "Still legal · \(rules.short)",
                                                       body: "Closes at \(Fmt.time(close)).", sound: .default),
                start: legalStart.addingTimeInterval(cap - 5 * 60))
        }
    }

    /// On foreground or a change of spot/species: restart if what it's counting
    /// changed, otherwise end the links whose moment has passed.
    static func sync(_ spot: Spot) async {
        let acts = all.filter { $0.attributes.spotName != testName }
        guard let first = acts.first else { return }
        if first.attributes.rules != spot.rules || first.attributes.spotName != (spot.name ?? "Your spot") {
            try? await start(spot)
            return
        }
        let now = Date()
        for a in acts where !isPending(a) {
            let s = a.content.state
            if (s.phase == .before && now >= s.open) || (s.phase == .open && now >= s.close) {
                await a.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    #if DEBUG
    /// Debug: legal light in 45 s, close 2 min after, through the same chain.
    static func startTest(_ spot: Spot) async throws {
        await endAll()
        var attrs = attributes(for: spot)
        attrs.spotName = testName
        let now = Date()
        try chain(attrs, open: now.addingTimeInterval(45), close: now.addingTimeInterval(165), legalNow: false,
                  rules: spot.rules, spot: testName)
    }
    #endif

    static func endAll() async {
        for a in Activity<HuntAttributes>.activities { await a.end(nil, dismissalPolicy: .immediate) }
    }
}
