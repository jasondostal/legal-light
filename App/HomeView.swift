import SwiftUI
import HoursCore

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var picking = false
    @State private var settings = false
    @AppStorage("icon.followRules") private var followIcon = false
    @AppStorage("seenDisclaimer") private var seenDisclaimer = false

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if !seenDisclaimer { FirstRunNote { withAnimation(.snappy) { seenDisclaimer = true } } }
                CountdownCard(spot: model.spot, isDefault: model.isDefaultSpot) { picking = true }
                HuntButton(spot: model.spot)
                RulePicker(selection: model.spot.rules) { r in
                    model.setRules(r)
                    if followIcon { AppIconChoice.apply(.forRules(r)) }
                }
                DayBar(spot: model.spot).id("daybar")
                ZoneMap(spot: model.spot) { lat, lon in model.setCoordinates(lat: lat, lon: lon) }
                    .id("map")
                WeekCard(spot: model.spot).id("week")
                SunCard(spot: model.spot)
                Disclaimer(spot: model.spot)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            #if DEBUG
            // screenshot aid: simctl launch ... -scroll map|week
            if let i = CommandLine.arguments.firstIndex(of: "-scroll"), i + 1 < CommandLine.arguments.count {
                let target = CommandLine.arguments[i + 1]
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { proxy.scrollTo(target, anchor: .top) }
            }
            if CommandLine.arguments.contains("-settings") { settings = true }
            if CommandLine.arguments.contains("-store") { Task { await HuntLive.endAll() } }
            if CommandLine.arguments.contains("-hunttest") { Task { try? await HuntLive.startTest(model.spot) } }
            #endif
        }
        }
        .background(Theme.night.ignoresSafeArea())
        .sheet(isPresented: $picking) { LocationSheet().environment(model) }
        .sheet(isPresented: $settings) { SettingsSheet().environment(model) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("// ~/wi/shooting-hours").font(.pixel(11)).foregroundStyle(Theme.mallard)
                Spacer()
                Button { settings = true } label: {
                    Image(systemName: "gearshape").font(.system(size: 16)).foregroundStyle(Theme.reed)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
            }
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Legal Light").font(.mono(26, .bold)).foregroundStyle(Theme.bone)
                    Text("Wisconsin shooting hours").font(.mono(14, .medium)).foregroundStyle(Theme.lantern)
                }
                Spacer()
                Button { picking = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: model.spot.gps ? "location.fill" : "mappin")
                        Text(model.spot.name ?? "Your spot").lineLimit(1)
                    }
                    .font(.mono(13, .medium))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 11).padding(.vertical, 7)
                    .background(Theme.mallard, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - shown once, on first launch (no click-through, no repeats)

struct FirstRunNote: View {
    let dismiss: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            (Text("Heads up. ").bold().foregroundStyle(Theme.lantern)
             + Text("Legal Light reads the Wisconsin DNR's published shooting hours tables, but it isn't the law. Check the regulations and season dates, and give yourself a margin."))
                .font(.mono(12)).foregroundStyle(Theme.bone)
            Button(action: dismiss) {
                Text("Got it").font(.mono(13, .bold)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Theme.lantern, in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12).padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.lantern.opacity(0.06))
        .overlay(alignment: .leading) { Rectangle().fill(Theme.lantern).frame(width: 3) }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - the Live Activity

struct HuntButton: View {
    let spot: Spot
    @State private var running = HuntLive.isRunning
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                Task {
                    if running { await HuntLive.endAll() } else {
                        do { try await HuntLive.start(spot); error = nil } catch { self.error = error.localizedDescription }
                    }
                    running = HuntLive.isRunning
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: running ? "stop.fill" : "play.fill")
                    Text(running ? "End hunt countdown" : "Start hunt countdown")
                    Spacer()
                    Text(running ? "on the Dynamic Island" : "Dynamic Island + lock screen").font(.mono(11)).opacity(0.75)
                }
                .font(.mono(14, .bold))
                .foregroundStyle(running ? Theme.bone : Theme.ink)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(running ? Theme.panel : Theme.mallard, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(running ? Theme.mallardDim : .clear))
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: running)
            if let error { Text(error).font(.mono(11)).foregroundStyle(Theme.lantern) }
            else if !running {
                let wait = spot.status(at: Clock.now).target.timeIntervalSince(Clock.now)
                if spot.status(at: Clock.now).state != .open && wait > 8 * 3600 {
                    Text("Live Activities last 8 hours, so start it when you head out.").font(.mono(11)).foregroundStyle(Theme.comment)
                }
            }
        }
        .onAppear { running = HuntLive.isRunning }
    }
}

// MARK: - rule sets

struct RulePicker: View {
    let selection: RuleSet
    let pick: (RuleSet) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Segmented(items: RuleSet.allCases.map { ($0.rawValue, $0.short) }, selected: selection.rawValue) {
                pick(RuleSet(rawValue: $0)!)
            }
            Text("\(selection.covers). \(selection.rule).")
                .font(.mono(12)).foregroundStyle(Theme.comment)
        }
    }
}

// MARK: - the countdown

struct CountdownCard: View {
    let spot: Spot
    let isDefault: Bool
    let setSpot: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let st = spot.status(at: Clock.adjust(ctx.date))
            let c = Theme.color(st.state)
            let w = spot.whereabouts
            let z = LongitudeZone.at(lon: spot.lon)
            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text(spot.rules.label.uppercased()).font(.pixel(11)).kerning(1.5).foregroundStyle(Theme.bone)
                    if isDefault {
                        Button(action: setSpot) {
                            Text("\(spot.name ?? "Stevens Point"), the default. Set your spot").font(.mono(12)).foregroundStyle(Theme.lantern)
                        }.buttonStyle(.plain)
                    } else if !w.inside {
                        Text("Outside Wisconsin: these are Wisconsin hours").font(.mono(12)).foregroundStyle(Theme.lantern)
                    } else {
                        Text("\(spot.name ?? "Your spot") · \(w.county ?? "") Co.").font(.mono(12)).foregroundStyle(Theme.reed)
                    }
                }
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }

                Text(st.state == .open ? "SHOOTING HOURS" : st.state == .before ? "LEGAL LIGHT IN" : "DONE FOR TODAY")
                    .font(.pixel(13)).kerning(2).foregroundStyle(c)
                    .padding(.top, 14)
                Text(Fmt.duration(st.target.timeIntervalSince(Clock.adjust(ctx.date))))
                    .font(.mono(72, .bold)).kerning(-2)
                    .monospacedDigit()
                    .foregroundStyle(Theme.countColor(st.state))
                    .minimumScaleFactor(0.5).lineLimit(1)
                Text(st.state == .open ? "closes at \(Fmt.time(st.target))" : "opens at \(Fmt.time(st.target))\(st.state == .after ? " tomorrow" : "")")
                    .font(.mono(14)).foregroundStyle(Theme.reed)
                    .padding(.bottom, 14)

                HStack(alignment: .top) {
                    VStack(spacing: 2) {
                        Text("OPENS").font(.pixel(10)).kerning(1.5).foregroundStyle(Theme.reed)
                        BigTime(date: st.hours.open, size: 34, color: st.state == .open ? Theme.bone : c)
                    }.frame(maxWidth: .infinity)
                    VStack(spacing: 2) {
                        Text("CLOSES").font(.pixel(10)).kerning(1.5).foregroundStyle(Theme.reed)
                        BigTime(date: st.hours.close, size: 34, color: st.state == .open ? c : Theme.bone)
                    }.frame(maxWidth: .infinity)
                }
                .padding(.top, 12)
                .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }

                Text("\(spot.area.name) area (\(spot.area.reference.name) table), zone \(z.id), +\(z.minutes) min.")
                    .font(.mono(11)).foregroundStyle(Theme.reed).multilineTextAlignment(.center)
                    .padding(.top, 10)
                Text(st.hours.source == .dnr ? "Read from the DNR's published \(String(st.hours.date.y)) table."
                                             : "Computed the DNR's way: no \(String(st.hours.date.y)) table in the app yet.")
                    .font(.mono(10)).foregroundStyle(st.hours.source == .dnr ? Theme.comment : Theme.lantern)
                    .padding(.top, 2)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.line))
        }
    }
}

// MARK: - today, as a bar: night, twilight, legal, sun up, now

struct DayBar: View {
    let spot: Spot

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            let today = Central.today(Clock.adjust(ctx.date))
            let h = spot.hours(on: today)
            let sun = h.localSun
            let t0 = h.open.addingTimeInterval(-75 * 60), t1 = h.close.addingTimeInterval(75 * 60)
            VStack(alignment: .leading, spacing: 8) {
                SectionHead(text: "Today, \(Fmt.day(today))")
                GeometryReader { g in
                    let W = g.size.width
                    let x = { (d: Date?) -> CGFloat in
                        guard let d else { return 0 }
                        return max(0, min(W, CGFloat(d.timeIntervalSince(t0) / t1.timeIntervalSince(t0)) * W))
                    }
                    ZStack(alignment: .topLeading) {
                        Rectangle().fill(Theme.darkFill).frame(height: 22).offset(y: 18)
                        Rectangle().fill(Theme.twilight)
                            .frame(width: x(sun.civilDusk) - x(sun.civilDawn), height: 22).offset(x: x(sun.civilDawn), y: 18)
                        Rectangle().fill(Theme.dayFill)
                            .frame(width: x(sun.sunset) - x(sun.sunrise), height: 22).offset(x: x(sun.sunrise), y: 18)
                        Rectangle().fill(Theme.mallard)
                            .frame(width: x(h.close) - x(h.open), height: 6).offset(x: x(h.open), y: 26)
                        Text(Fmt.time(h.open, bare: true)).font(.mono(11, .bold)).foregroundStyle(Theme.bone)
                            .fixedSize().position(x: x(h.open), y: 7)
                        Text(Fmt.time(h.close, bare: true)).font(.mono(11, .bold)).foregroundStyle(Theme.bone)
                            .fixedSize().position(x: x(h.close), y: 7)
                        if Clock.adjust(ctx.date) > t0 && Clock.adjust(ctx.date) < t1 {
                            Rectangle().fill(Theme.lantern).frame(width: 2, height: 30).offset(x: x(Clock.adjust(ctx.date)) - 1, y: 14)
                        }
                        ForEach(ticks(t0, t1), id: \.self) { t in
                            Text(hourLabel(t)).font(.mono(9)).foregroundStyle(Theme.comment)
                                .fixedSize().position(x: x(t), y: 52)
                        }
                    }
                }
                .frame(height: 60)
                HStack(spacing: 12) {
                    key(Theme.mallard, "legal"); key(Theme.dayFill, "sun up"); key(Theme.twilight, "civil twilight"); key(Theme.lantern, "now")
                }
                .font(.mono(10)).foregroundStyle(Theme.reed)
            }
            .panel()
        }
    }

    private func ticks(_ a: Date, _ b: Date) -> [Date] {
        let cal = Central.calendar
        var t = cal.nextDate(after: a, matching: DateComponents(minute: 0), matchingPolicy: .nextTime)!
        var out: [Date] = []
        while t < b { if cal.component(.hour, from: t) % 2 == 1 { out.append(t) }; t = t.addingTimeInterval(3600) }
        return out
    }
    private func hourLabel(_ d: Date) -> String {
        let h = Central.calendar.component(.hour, from: d)
        return "\(h % 12 == 0 ? 12 : h % 12)\(h < 12 ? "a" : "p")"
    }
    private func key(_ c: Color, _ s: String) -> some View {
        HStack(spacing: 4) { RoundedRectangle(cornerRadius: 2).fill(c).frame(width: 9, height: 9); Text(s) }
    }
}

// MARK: - the week, any week

struct WeekCard: View {
    let spot: Spot
    /// First day shown; nil = today (follows the date as it rolls over).
    @State private var start: YMD? = nil

    private var today: YMD { Central.today(Clock.now) }
    private var first: YMD { start ?? today }

    var body: some View {
        let days = (0..<7).map { first.adding(days: $0) }
        let hours = days.map { spot.hours(on: $0) }
        let computed = Set(hours.filter { $0.source == .computed }.map { $0.date.y })
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionHead(text: first == today ? "This week" : "Week of \(Fmt.day(first))")
                Spacer()
                if first != today {
                    Button { withAnimation(.snappy) { start = nil } } label: {
                        Text("Today").font(.mono(12, .bold)).foregroundStyle(Theme.mallard)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.bottom, 10)
            controls.padding(.bottom, 12)
            HStack {
                Text("Day"); Spacer()
                Text("Opens").frame(width: 84, alignment: .leading)
                Text("Closes").frame(width: 84, alignment: .leading)
            }
            .font(.mono(11)).foregroundStyle(Theme.reed).padding(.horizontal, 6).padding(.bottom, 6)
            ForEach(Array(zip(days, hours).enumerated()), id: \.offset) { i, pair in
                let (d, h) = pair
                let isToday = d == today
                HStack {
                    Text(isToday ? "Today" : Fmt.day(d)).foregroundStyle(isToday ? Theme.lantern : Theme.bone)
                    Spacer()
                    Text(Fmt.time(h.open) + (h.source == .computed ? "*" : " ")).frame(width: 84, alignment: .leading)
                    Text(Fmt.time(h.close)).frame(width: 84, alignment: .leading)
                }
                .font(.mono(13, isToday ? .bold : .regular)).monospacedDigit()
                .foregroundStyle(Theme.bone)
                .padding(.vertical, 8).padding(.horizontal, 6)
                .background(isToday ? Theme.lantern.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 4))
                .overlay(alignment: .bottom) { if i < 6 { Rectangle().fill(Theme.line).frame(height: 1) } }
            }
            if !computed.isEmpty {
                Text("* Computed the DNR's way: the app has no \(computed.sorted().map(String.init).joined(separator: "/")) table yet. Check the official one before you hunt.")
                    .font(.mono(10)).foregroundStyle(Theme.lantern).padding(.top, 8)
            }
        }
        .panel()
        .sensoryFeedback(.selection, trigger: first)
    }

    /// ‹ week · date picker · week ›
    private var controls: some View {
        HStack(spacing: 8) {
            stepButton("chevron.left") { start = first.adding(days: -7) }
            DatePicker("Date", selection: Binding(
                get: { Central.toDate(first, minutes: 720) },
                set: { start = Central.today($0) }), displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .environment(\.timeZone, Central.zone)
                .tint(Theme.lantern)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
                .background(Theme.night, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
            stepButton("chevron.right") { start = first.adding(days: 7) }
        }
    }

    private func stepButton(_ icon: String, _ act: @escaping () -> Void) -> some View {
        Button { withAnimation(.snappy) { act() } } label: {
            Image(systemName: icon).font(.system(size: 14, weight: .bold))
                .frame(width: 44, height: 40)
                .foregroundStyle(Theme.bone)
                .background(Theme.night, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - the true sun at your spot, for interest

struct SunCard: View {
    let spot: Spot

    var body: some View {
        let h = spot.hours(on: Central.today(Clock.now))
        let s = h.localSun
        let moon = Moon.phase(Clock.now)
        VStack(alignment: .leading, spacing: 8) {
            SectionHead(text: "Sun and moon here")
            Grid(alignment: .leading, verticalSpacing: 6) {
                row("Civil dawn", Fmt.time(s.civilDawn))
                row("Sunrise", Fmt.time(s.sunrise))
                row("Sunset", Fmt.time(s.sunset))
                row("Civil dusk", Fmt.time(s.civilDusk))
                row("Moon", "\(moon.name), \(Int((moon.lit * 100).rounded()))% lit")
            }
            if let lo = h.localOpen {
                let diff = Int((h.open.timeIntervalSince(lo) / 60).rounded())
                Text("Measured from the sun at your exact spot. The legal table opens \(diff == 0 ? "the same minute" : "\(abs(diff)) min \(diff > 0 ? "later" : "earlier")"), because it uses a reference town and whole-degree zones.")
                    .font(.mono(10)).foregroundStyle(Theme.comment)
            }
        }
        .panel()
    }

    @ViewBuilder private func row(_ k: String, _ v: String) -> some View {
        GridRow {
            Text(k).foregroundStyle(Theme.reed)
            Text(v).foregroundStyle(Theme.bone).gridColumnAlignment(.trailing).frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.mono(13)).monospacedDigit()
    }
}

/// Cheap moon phase (same as the web page).
enum Moon {
    static func phase(_ d: Date) -> (name: String, lit: Double) {
        let syn = 29.530588853
        let ref = Date(timeIntervalSince1970: 947_182_440) // 2000-01-06 18:14 UTC, a new moon
        var age = (d.timeIntervalSince(ref) / 86400).truncatingRemainder(dividingBy: syn)
        if age < 0 { age += syn }
        let f = age / syn
        let names = ["New moon", "Waxing crescent", "First quarter", "Waxing gibbous", "Full moon", "Waning gibbous", "Last quarter", "Waning crescent"]
        return (names[Int((f * 8).rounded()) % 8], (1 - cos(2 * .pi * f)) / 2)
    }
}

// MARK: - the fine print

struct Disclaimer: View {
    let spot: Spot
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            (Text("Not the law. ").bold().foregroundStyle(Theme.lantern)
             + Text("The Wisconsin DNR's regulations and its published shooting hours tables govern. This app reads those tables and adds your zone's minutes; check the season dates and rules before you shoot, and allow yourself the margin."))
            if spot.rules == .teal {
                Text("Early teal is a short season in early September. Check this year's dates.")
            }
        }
        .font(.mono(12)).foregroundStyle(Theme.bone)
        .padding(.vertical, 10).padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.lantern.opacity(0.06))
        .overlay(alignment: .leading) { Rectangle().fill(Theme.lantern).frame(width: 3) }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
