import HoursCore
import SwiftUI
import WidgetKit

// Shared with the app target, so the debug gallery can render every family.

struct HoursEntry: TimelineEntry {
    let date: Date
    let spot: Spot
    let rules: RuleSet
    let status: HoursStatus
    let hasSpot: Bool
}

// MARK: - views

enum WTheme {
    static let bg = Color(red: 0.035, green: 0.047, blue: 0.075)
    static let dim = Color(red: 0.58, green: 0.62, blue: 0.70)
    static func color(_ s: HoursStatus.State) -> Color {
        switch s {
        case .before: return Color(red: 0.42, green: 0.66, blue: 1.00)
        case .open: return Color(red: 1.00, green: 0.66, blue: 0.20)
        case .after: return Color(red: 0.62, green: 0.56, blue: 0.86)
        }
    }
    static func verb(_ s: HoursStatus.State) -> String { s == .open ? "Closes in" : "Opens in" }
}

struct HoursWidgetView: View {
    @Environment(\.widgetFamily) private var envFamily
    let e: HoursEntry
    /// Set by the in-app debug gallery; the widget itself reads the environment.
    var forced: WidgetFamily? = nil
    private var family: WidgetFamily { forced ?? envFamily }

    private var st: HoursStatus { e.status }
    private var c: Color { WTheme.color(st.state) }
    private var timer: some View {
        Text(timerInterval: e.date...max(e.date, st.target), countsDown: true).monospacedDigit()
    }

    var body: some View {
        switch family {
        case .accessoryInline: inline
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .systemMedium: medium
        default: small
        }
    }

    private var timerText: Text { Text(timerInterval: e.date...max(e.date, st.target), countsDown: true) }

    // Lock screen, above the clock: one Text, since inline drops everything else.
    private var inline: some View {
        let icon = Text(Image(systemName: st.isLegal ? "sun.max.fill" : "sunrise.fill"))
        return st.isLegal
            ? icon + Text(" \(e.rules.short) ") + timerText + Text(" left")
            : icon + Text(" \(e.rules.short) legal in ") + timerText
    }

    // The next event's clock time: certain to render, no animation needed.
    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: st.isLegal ? "sunset.fill" : "sunrise.fill").font(.system(size: 13, weight: .semibold))
                Text(Fmt.time(st.target, bare: true)).font(.system(size: 17, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6).lineLimit(1)
                Text(e.rules.short.uppercased()).font(.system(size: 8, weight: .heavy)).lineLimit(1)
            }
            .padding(.horizontal, 4)
        }
        .widgetAccentable()
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(e.rules.short.uppercased()) · \(WTheme.verb(st.state).uppercased())")
                .font(.system(size: 11, weight: .heavy)).widgetAccentable()
            timer.font(.system(size: 26, weight: .bold, design: .rounded)).lineLimit(1)
            Text("\(Fmt.time(st.hours.open, bare: true)) – \(Fmt.time(st.hours.close, bare: true))\(st.state == .after ? " tmrw" : "")")
                .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(e.rules.short.uppercased()).font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(WTheme.dim)
            Text(WTheme.verb(st.state)).font(.system(size: 13, weight: .bold)).foregroundStyle(c)
            timer.font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(.white)
                .minimumScaleFactor(0.6).lineLimit(1)
            Spacer(minLength: 0)
            ProgressView(timerInterval: st.since...max(st.since.addingTimeInterval(1), st.target), countsDown: false) {
                EmptyView()
            } currentValueLabel: { EmptyView() }
                .tint(c)
            HStack {
                Text(Fmt.time(st.hours.open, bare: true))
                Spacer()
                Text(Fmt.time(st.hours.close, bare: true))
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(.white)
            Text(e.hasSpot ? (e.spot.name ?? "Your spot") : "Open to set spot")
                .font(.system(size: 10)).foregroundStyle(WTheme.dim).lineLimit(1)
        }
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 16) {
            small
            VStack(alignment: .leading, spacing: 5) {
                Text("NEXT DAYS").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(WTheme.dim)
                let d0 = Central.today(e.date)
                ForEach(0..<4, id: \.self) { i in
                    let h = e.spot.hours(on: d0.adding(days: i), rules: e.rules)
                    HStack {
                        Text(i == 0 ? "Today" : Fmt.day(h.date).components(separatedBy: " ").first!)
                            .foregroundStyle(WTheme.dim)
                        Spacer()
                        Text("\(Fmt.time(h.open, bare: true))–\(Fmt.time(h.close, bare: true))").foregroundStyle(.white)
                    }
                    .font(.system(size: 13, weight: .medium, design: .rounded)).monospacedDigit()
                }
                Spacer(minLength: 0)
            }
        }
    }
}

