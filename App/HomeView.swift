import SwiftUI
import HoursCore

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var picking = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                RulePicker(selection: model.spot.rules) { model.setRules($0) }
                CountdownCard(spot: model.spot)
                WhereCard(spot: model.spot, whereabouts: model.whereabouts, duck: model.duckZone,
                          isDefault: model.isDefaultSpot) { picking = true }
                WeekCard(spot: model.spot)
                SourceNote(spot: model.spot)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .sheet(isPresented: $picking) { LocationSheet().environment(model) }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("LEGAL LIGHT").font(.system(size: 13, weight: .heavy)).tracking(2.5).foregroundStyle(Theme.dim)
            Spacer()
            Button { picking = true } label: {
                HStack(spacing: 5) {
                    Image(systemName: model.spot.gps ? "location.fill" : "mappin")
                    Text(model.spot.name ?? "Your spot").lineLimit(1)
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(Theme.card, in: Capsule())
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - rule sets

struct RulePicker: View {
    let selection: RuleSet
    let pick: (RuleSet) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(RuleSet.allCases) { r in
                    let on = r == selection
                    Button { pick(r) } label: {
                        Text(r.label)
                            .font(.system(size: 14, weight: on ? .bold : .medium))
                            .foregroundStyle(on ? Theme.bg : Theme.text)
                            .padding(.horizontal, 13).padding(.vertical, 8)
                            .background(on ? Theme.text : Theme.card, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

// MARK: - the countdown

struct CountdownCard: View {
    let spot: Spot

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let st = spot.status(at: ctx.date)
            let c = Theme.color(st.state)
            VStack(alignment: .leading, spacing: 10) {
                Text(Theme.headline(st.state).uppercased())
                    .font(.system(size: 13, weight: .heavy)).tracking(1.5).foregroundStyle(c)
                Text(Fmt.duration(st.target.timeIntervalSince(ctx.date)))
                    .font(.system(size: 76, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.text)
                    .minimumScaleFactor(0.5).lineLimit(1)
                    .contentTransition(.numericText(countsDown: true))
                ProgressView(value: st.progress(at: ctx.date)).tint(c)
                HStack {
                    timeBlock("OPEN", st.hours.open, highlight: st.state != .open, c)
                    Spacer()
                    timeBlock("CLOSE", st.hours.close, highlight: st.state == .open, c)
                }
                if st.state == .after || st.hours.date != Central.today(ctx.date) {
                    Text("Tomorrow, \(Fmt.day(st.hours.date))").font(.footnote).foregroundStyle(Theme.dim)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [c.opacity(0.16), Theme.card], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(c.opacity(0.25)))
        }
    }

    private func timeBlock(_ label: String, _ t: Date, highlight: Bool, _ c: Color) -> some View {
        VStack(alignment: label == "OPEN" ? .leading : .trailing, spacing: 2) {
            Text(label).font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(Theme.dim)
            Text(Fmt.time(t)).font(.system(size: 24, weight: .semibold, design: .rounded)).monospacedDigit()
                .foregroundStyle(highlight ? c : Theme.text)
        }
    }
}

// MARK: - where you are, as the regs see it

struct WhereCard: View {
    let spot: Spot
    let whereabouts: Locate.Where
    let duck: (zone: Locate.DuckZone, km: Double?)?
    let isDefault: Bool
    let change: () -> Void

    var body: some View {
        let zone = LongitudeZone.at(lon: spot.lon)
        VStack(alignment: .leading, spacing: 12) {
            if isDefault {
                Button(action: change) {
                    Label("Showing Stevens Point. Set your spot.", systemImage: "location.circle")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.waiting)
                }
            }
            if !whereabouts.inside {
                Label("That's outside Wisconsin. These are Wisconsin hours.", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.warn)
            }
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 9) {
                row("County", whereabouts.county.map { "\($0) Co." } ?? "—")
                row("Hours area", "\(spot.area.name) · times from \(spot.area.reference.name)")
                row("Hours zone", "\(zone.id), \(zone.minutes == 0 ? "+0" : "+\(zone.minutes)") min (\(zone.desc))")
                if spot.rules == .waterfowl || spot.rules == .teal, let duck {
                    row("Duck zone", duck.zone.name)
                }
            }
            if let km = duck?.km, km < 1.5, spot.rules == .waterfowl {
                Text("You're \(String(format: "%.1f", km)) km from the duck-zone line (US 10 / US 41). Check which side of the highway you're on.")
                    .font(.footnote).foregroundStyle(Theme.warn)
            }
            if abs(-spot.lon - (-spot.lon).rounded()) < 0.02 && -spot.lon > 88 - 0.02 && -spot.lon < 92 + 0.02 {
                Text("You're right on a zone line (\(Int((-spot.lon).rounded()))° W). Within about a mile of it, which side you are on changes the time by 4 minutes.")
                    .font(.footnote).foregroundStyle(Theme.warn)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder private func row(_ k: String, _ v: String) -> some View {
        GridRow {
            Text(k).font(.subheadline).foregroundStyle(Theme.dim)
            Text(v).font(.subheadline.weight(.medium)).foregroundStyle(Theme.text)
        }
    }
}

// MARK: - the week

struct WeekCard: View {
    let spot: Spot

    var body: some View {
        let today = Central.today()
        VStack(spacing: 0) {
            HStack {
                Text("NEXT 7 DAYS").font(.system(size: 11, weight: .heavy)).tracking(1.2)
                Spacer()
                Text("OPEN").frame(width: 82, alignment: .trailing)
                Text("CLOSE").frame(width: 82, alignment: .trailing)
            }
            .font(.system(size: 11, weight: .heavy)).foregroundStyle(Theme.dim)
            .padding(.bottom, 8)
            ForEach(0..<7, id: \.self) { i in
                let d = today.adding(days: i)
                let h = spot.hours(on: d)
                HStack {
                    Text(i == 0 ? "Today" : Fmt.day(d)).fontWeight(i == 0 ? .bold : .regular)
                    Spacer()
                    Text(Fmt.time(h.open)).frame(width: 82, alignment: .trailing)
                    Text(Fmt.time(h.close)).frame(width: 82, alignment: .trailing)
                }
                .font(.system(size: 15, design: .rounded)).monospacedDigit()
                .foregroundStyle(Theme.text)
                .padding(.vertical, 7)
                if i < 6 { Divider().overlay(Theme.line) }
            }
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - where the numbers come from

struct SourceNote: View {
    let spot: Spot

    var body: some View {
        let h = spot.hours(on: Central.today())
        VStack(alignment: .leading, spacing: 8) {
            Text("\(spot.rules.covers): \(spot.rules.rule.lowercased()).")
            if spot.rules == .teal {
                Text("Early teal is a short season in early September. Check this year's dates in the regulations.")
            }
            if h.source == .dnr {
                Text("Read straight from the DNR's published \(String(h.date.y)) shooting hours table, plus your zone's minutes.")
            } else {
                Text("The DNR hasn't published \(String(h.date.y)) tables in this app yet, so these are computed the DNR's way (within a minute of their tables in past years). Check the official table before you hunt.")
                    .foregroundStyle(Theme.warn)
            }
            Text("Not legal advice. The Wisconsin hunting regulations are the final word.")
        }
        .font(.footnote)
        .foregroundStyle(Theme.dim)
        .padding(.horizontal, 4)
    }
}
