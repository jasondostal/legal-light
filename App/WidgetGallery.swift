#if DEBUG
import HoursCore
import SwiftUI
import WidgetKit

/// Debug-only: every widget family at its real size, live. Launch with
/// `-gallery` (simctl launch <sim> dev.ducktyping.shootinghours -gallery).
struct WidgetGallery: View {
    let spot: Spot
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let entries = [spot.rules, .smallgame].map { r in
                HoursEntry(date: Clock.adjust(ctx.date), spot: spot, rules: r, status: spot.status(at: Clock.adjust(ctx.date), rules: r), hasSpot: true)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Lock screen").font(.headline)
                    ForEach(entries.indices, id: \.self) { i in
                        let e = entries[i]
                        HStack(spacing: 14) {
                            HoursWidgetView(e: e, forced: .accessoryCircular).frame(width: 72, height: 72)
                            HoursWidgetView(e: e, forced: .accessoryRectangular).frame(width: 170, height: 72)
                        }
                        HoursWidgetView(e: e, forced: .accessoryInline).frame(height: 22)
                    }
                    Text("Live Activity").font(.headline)
                    let c = HuntAttributes.ContentState.at(Clock.adjust(ctx.date), spot: spot).state
                    let attrs = HuntLive.attributes(for: spot)
                    ForEach([HuntPhase.before, .open, .closed], id: \.self) { ph in
                        HuntBanner(attrs: attrs, state: c, phase: ph)
                            .frame(width: 364).background(Theme.night, in: RoundedRectangle(cornerRadius: 22))
                    }
                    // Dynamic Island mock-ups (compact + expanded), for layout only
                    HStack {
                        Image(systemName: "sun.max.fill").foregroundStyle(Theme.mallard)
                        Spacer()
                        ShortTimer(target: c.close)
                            .font(.mono(13, .bold)).monospacedDigit().foregroundStyle(Theme.mallard)
                            .multilineTextAlignment(.trailing).frame(maxWidth: 58, alignment: .trailing)
                    }
                    .padding(.horizontal, 14).frame(width: 250, height: 37).background(.black, in: Capsule())
                    VStack(spacing: 6) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(spot.rules.short.uppercased()).font(.pixel(10)).foregroundStyle(Theme.bone)
                                Text(HuntPhase.open.headline.uppercased()).font(.pixel(9)).foregroundStyle(Theme.mallard)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("open \(Fmt.time(c.open, bare: true))").font(.mono(11)).foregroundStyle(Theme.reed)
                                Text("close \(Fmt.time(c.close, bare: true))").font(.mono(11)).foregroundStyle(Theme.mallard)
                            }
                        }
                        CountdownText(phase: .open, state: c, size: 40)
                        Text("\(attrs.spotName) · \(attrs.zoneLine)").font(.mono(10)).foregroundStyle(Theme.reed)
                    }
                    .padding(18).frame(width: 370).background(.black, in: RoundedRectangle(cornerRadius: 40))
                    Text("Home screen").font(.headline)
                    HStack(spacing: 14) {
                        ForEach(entries.indices, id: \.self) { i in
                            HoursWidgetView(e: entries[i], forced: .systemSmall).padding(16)
                                .frame(width: 170, height: 170).background(Theme.night, in: RoundedRectangle(cornerRadius: 22))
                        }
                    }
                    HoursWidgetView(e: entries[1], forced: .systemMedium).padding(16)
                        .frame(width: 364, height: 170).background(Theme.night, in: RoundedRectangle(cornerRadius: 22))
                }
                .padding(16)
            }
            .foregroundStyle(.white)
            .background(Color(white: 0.25).ignoresSafeArea())
        }
    }
}
#endif
