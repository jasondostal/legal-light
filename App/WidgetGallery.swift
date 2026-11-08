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
                HoursEntry(date: ctx.date, spot: spot, rules: r, status: spot.status(at: ctx.date, rules: r), hasSpot: true)
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
