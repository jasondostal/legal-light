import ActivityKit
import HoursCore
import SwiftUI
import WidgetKit

/// Dynamic Island + lock-screen banner for a running hunt countdown.
struct HuntLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HuntAttributes.self) { ctx in
            HuntBanner(attrs: ctx.attributes, state: ctx.state, phase: HuntPhase(ctx.state, stale: ctx.isStale))
                .activityBackgroundTint(Theme.night)
                .activitySystemActionForegroundColor(Theme.bone)
        } dynamicIsland: { ctx in
            let phase = HuntPhase(ctx.state, stale: ctx.isStale)
            let c = Theme.color(phase.status)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ctx.attributes.rules.short.uppercased()).font(.pixel(10)).foregroundStyle(Theme.bone)
                        Text(phase.headline.uppercased()).font(.pixel(9)).foregroundStyle(c)
                    }
                    .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("open \(Fmt.time(ctx.state.open, bare: true))").font(.mono(11))
                            .foregroundStyle(phase == .before ? c : Theme.reed)
                        Text("close \(Fmt.time(ctx.state.close, bare: true))").font(.mono(11))
                            .foregroundStyle(phase == .open ? c : Theme.reed)
                    }
                    .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        CountdownText(phase: phase, state: ctx.state, size: 40)
                        if let t = phase.target(ctx.state) {
                            ProgressView(timerInterval: phase.since(ctx.state)...max(phase.since(ctx.state).addingTimeInterval(1), t),
                                         countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                                .tint(c)
                        }
                        Text("\(ctx.attributes.spotName) · \(ctx.attributes.zoneLine)")
                            .font(.mono(10)).foregroundStyle(Theme.reed).lineLimit(1)
                    }
                    .padding(.horizontal, 6)
                }
            } compactLeading: {
                Image(systemName: icon(phase)).foregroundStyle(c)
            } compactTrailing: {
                if let t = phase.target(ctx.state) {
                    Text(timerInterval: Date.distantPast...max(Date.distantPast, t), countsDown: true)
                        .font(.mono(13, .bold)).monospacedDigit()
                        .foregroundStyle(c)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 64, alignment: .trailing)
                } else {
                    Text("done").font(.mono(12)).foregroundStyle(c)
                }
            } minimal: {
                Image(systemName: icon(phase)).foregroundStyle(c)
            }
            .keylineTint(c)
        }
    }
}

private func icon(_ p: HuntPhase) -> String {
    switch p { case .before: return "sunrise.fill"; case .open: return "sun.max.fill"; case .closed: return "moon.stars.fill" }
}

/// The big number: live timer to the next transition, or the closing time once it's over.
struct CountdownText: View {
    let phase: HuntPhase
    let state: HuntAttributes.ContentState
    var size: CGFloat
    var body: some View {
        if let t = phase.target(state) {
            Text(timerInterval: Date.distantPast...max(Date.distantPast, t), countsDown: true)
                .font(.mono(size, .bold)).kerning(-1.5).monospacedDigit()
                .foregroundStyle(Theme.countColor(phase.status))
                .multilineTextAlignment(.center)
                .lineLimit(1).minimumScaleFactor(0.6)
        } else {
            Text("closed \(Fmt.time(state.close))").font(.mono(size * 0.55, .bold)).foregroundStyle(Theme.reed)
        }
    }
}

/// Lock-screen banner: the web page's countdown board, compressed.
struct HuntBanner: View {
    let attrs: HuntAttributes
    let state: HuntAttributes.ContentState
    let phase: HuntPhase

    var body: some View {
        let c = Theme.color(phase.status)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(attrs.rules.short.uppercased()) · \(attrs.spotName.uppercased())")
                    .font(.pixel(10)).kerning(0.5).foregroundStyle(Theme.bone).lineLimit(1)
                Spacer()
                Image(systemName: icon(phase)).foregroundStyle(c)
            }
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(phase.headline.uppercased()).font(.pixel(10)).kerning(1).foregroundStyle(c)
                    if let t = phase.target(state) {
                        Text(timerInterval: Date.distantPast...max(Date.distantPast, t), countsDown: true)
                            .font(.mono(38, .bold)).kerning(-1.5).monospacedDigit()
                            .foregroundStyle(Theme.countColor(phase.status))
                            .lineLimit(1)
                    } else {
                        Text("Closed").font(.mono(34, .bold)).foregroundStyle(Theme.reed)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    row("OPENS", state.open, on: phase == .before, c)
                    row("CLOSES", state.close, on: phase == .open, c)
                }
            }
            if let t = phase.target(state) {
                ProgressView(timerInterval: phase.since(state)...max(phase.since(state).addingTimeInterval(1), t),
                             countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                    .tint(c)
            }
            Text(attrs.zoneLine).font(.mono(10)).foregroundStyle(Theme.reed)
        }
        .padding(14)
    }

    private func row(_ k: String, _ d: Date, on: Bool, _ c: Color) -> some View {
        HStack(spacing: 6) {
            Text(k).font(.pixel(8)).foregroundStyle(Theme.reed)
            Text(Fmt.time(d)).font(.mono(14, .bold)).monospacedDigit().foregroundStyle(on ? c : Theme.bone)
        }
    }
}
