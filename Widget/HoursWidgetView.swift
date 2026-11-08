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

extension Theme {
    static func verb(_ s: HoursStatus.State) -> String { s == .open ? "Closes in" : "Opens in" }
}

struct HoursWidgetView: View {
    @Environment(\.widgetFamily) private var envFamily
    let e: HoursEntry
    /// Set by the in-app debug gallery; the widget itself reads the environment.
    var forced: WidgetFamily? = nil
    private var family: WidgetFamily { forced ?? envFamily }

    private var st: HoursStatus { e.status }
    private var c: Color { Theme.color(st.state) }
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
                Text(Fmt.time(st.target, bare: true)).font(.mono(16, .bold))
                    .minimumScaleFactor(0.6).lineLimit(1)
                Text(e.rules.short.uppercased()).font(.pixel(7)).lineLimit(1)
            }
            .padding(.horizontal, 4)
        }
        .widgetAccentable()
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(e.rules.short.uppercased()) · \(Theme.verb(st.state).uppercased())")
                .font(.pixel(10)).widgetAccentable()
            timer.font(.mono(25, .bold)).kerning(-1).lineLimit(1)
            Text("\(Fmt.time(st.hours.open, bare: true)) – \(Fmt.time(st.hours.close, bare: true))\(st.state == .after ? " tmrw" : "")")
                .font(.mono(12)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(e.rules.short.uppercased()).font(.pixel(10)).kerning(1).foregroundStyle(Theme.bone)
            Text(Theme.verb(st.state).uppercased()).font(.pixel(10)).kerning(1).foregroundStyle(c)
            timer.font(.mono(30, .bold)).kerning(-1.5).foregroundStyle(Theme.countColor(st.state))
                .minimumScaleFactor(0.6).lineLimit(1)
            Spacer(minLength: 0)
            ProgressView(timerInterval: st.since...max(st.since.addingTimeInterval(1), st.target), countsDown: false) {
                EmptyView()
            } currentValueLabel: { EmptyView() }
                .tint(c)
                .background(Theme.line, in: Capsule())
            HStack {
                Text(Fmt.time(st.hours.open, bare: true))
                Spacer()
                Text(Fmt.time(st.hours.close, bare: true))
            }
            .font(.mono(13, .bold)).monospacedDigit().foregroundStyle(Theme.bone)
            Text(e.hasSpot ? (e.spot.name ?? "Your spot") : "Open to set spot")
                .font(.mono(10)).foregroundStyle(Theme.reed).lineLimit(1)
        }
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 16) {
            small
            VStack(alignment: .leading, spacing: 5) {
                Text("THIS WEEK").font(.pixel(10)).kerning(1).foregroundStyle(Theme.lantern)
                let d0 = Central.today(e.date)
                ForEach(0..<4, id: \.self) { i in
                    let h = e.spot.hours(on: d0.adding(days: i), rules: e.rules)
                    HStack {
                        Text(i == 0 ? "Today" : Fmt.day(h.date).components(separatedBy: " ").first!)
                            .foregroundStyle(i == 0 ? Theme.lantern : Theme.reed)
                        Spacer()
                        Text("\(Fmt.time(h.open, bare: true))–\(Fmt.time(h.close, bare: true))").foregroundStyle(Theme.bone)
                    }
                    .font(.mono(12, i == 0 ? .bold : .regular)).monospacedDigit()
                }
                Spacer(minLength: 0)
            }
        }
    }
}

