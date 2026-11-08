import SwiftUI
import UIKit
import HoursCore

/// Selectable app icons (Jason, 2026-11-08: pick one for your sport, or let it
/// follow the rule set you're hunting). Art comes from tools/gen-icons.py.
enum AppIconChoice: String, CaseIterable, Identifiable {
    case dawn, mallard, teal, deer, squirrel, turkey
    var id: String { rawValue }

    /// nil = the primary icon.
    var assetName: String? {
        switch self {
        case .dawn: return nil
        case .mallard: return "AppIcon-Mallard"
        case .teal: return "AppIcon-Teal"
        case .deer: return "AppIcon-Deer"
        case .squirrel: return "AppIcon-Squirrel"
        case .turkey: return "AppIcon-Turkey"
        }
    }
    var preview: String { "Preview-" + (assetName ?? "AppIcon") }
    var label: String {
        switch self {
        case .dawn: return "First light"
        case .mallard: return "Mallard"
        case .teal: return "Teal"
        case .deer: return "Whitetail"
        case .squirrel: return "Fox squirrel"
        case .turkey: return "Tom"
        }
    }

    static func forRules(_ r: RuleSet) -> AppIconChoice {
        switch r {
        case .waterfowl: return .mallard
        case .teal: return .teal
        case .smallgame: return UserDefaults.standard.string(forKey: "icon.smallgame") == "squirrel" ? .squirrel : .deer
        case .springturkey: return .turkey
        }
    }

    static var current: AppIconChoice {
        let n = UIApplication.shared.alternateIconName
        return allCases.first { $0.assetName == n } ?? .dawn
    }

    /// iOS shows its own "icon changed" alert each time; only call on a real change.
    @MainActor static func apply(_ c: AppIconChoice) {
        guard UIApplication.shared.supportsAlternateIcons, c != current else { return }
        UIApplication.shared.setAlternateIconName(c.assetName)
    }
}

struct SettingsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @AppStorage("icon.followRules") private var follow = false
    @State private var chosen = AppIconChoice.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHead(text: "App icon")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 14) {
                            ForEach(AppIconChoice.allCases) { c in
                                let on = c == chosen && !follow
                                Button {
                                    if c == .deer || c == .squirrel { UserDefaults.standard.set(c.rawValue, forKey: "icon.smallgame") }
                                    follow = false; chosen = c; AppIconChoice.apply(c)
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(c.preview).resizable().interpolation(.none)
                                            .aspectRatio(1, contentMode: .fit)
                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(on ? Theme.lantern : Theme.line, lineWidth: on ? 3 : 1))
                                        Text(c.label).font(.mono(11, on ? .bold : .regular))
                                            .foregroundStyle(on ? Theme.lantern : Theme.reed)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Toggle(isOn: $follow) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Match what I'm hunting").font(.mono(14, .medium)).foregroundStyle(Theme.bone)
                                Text("Ducks → mallard, deer & small game → whitetail, or the squirrel if you picked it, turkey → tom, teal → teal. iOS confirms each change with a little alert.")
                                    .font(.mono(11)).foregroundStyle(Theme.comment)
                            }
                        }
                        .tint(Theme.mallard)
                        .onChange(of: follow) { _, on in
                            if on { let c = AppIconChoice.forRules(model.spot.rules); chosen = c; AppIconChoice.apply(c) }
                        }
                    }
                    .panel()

                    AlertSettings(spot: model.spot).panel()
                    #if DEBUG
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHead(text: "Debug", color: Theme.comment)
                        Button {
                            Task { try? await HuntLive.startTest(model.spot) }
                            dismiss()
                        } label: {
                            Text("Test the flip: legal light in 45 s, close 2 min later")
                                .font(.mono(13, .bold)).foregroundStyle(Theme.bone)
                                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.line))
                        }
                        .buttonStyle(.plain)
                        Text("Lock the phone and watch: amber countdown → green \"closes in\" at 0:00 → \"Closed\" 2 minutes later, with no app open.")
                            .font(.mono(11)).foregroundStyle(Theme.comment)
                    }
                    .panel()
                    #endif

                    VStack(alignment: .leading, spacing: 8) {
                        SectionHead(text: "About")
                        Text("Times are read from the Wisconsin DNR's published shooting hours tables (Wis. Admin. Code NR 10.06): one reference town per area, plus 4 minutes per degree of longitude west of 88° W. Everything runs on your phone, with no account and no network.")
                        Text("Made in the blind by ducktyping.dev. Fonts: Silkscreen and JetBrains Mono (SIL Open Font License).")
                            .foregroundStyle(Theme.comment)
                    }
                    .font(.mono(12)).foregroundStyle(Theme.bone)
                    .panel()
                }
                .padding(16)
            }
            .background(Theme.night)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.tint(Theme.mallard) } }
        }
        .preferredColorScheme(.dark)
    }
}

struct AlertSettings: View {
    let spot: Spot
    @AppStorage(Alerts.openKey) private var atOpen = false
    @AppStorage(Alerts.closeKey) private var beforeClose = false
    @AppStorage(Alerts.leadKey) private var lead = 10
    @State private var denied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHead(text: "Alerts")
            Toggle(isOn: $atOpen) { label("At legal light", "A ping the minute shooting hours open.") }
            Toggle(isOn: $beforeClose) { label("Before close", "A heads-up so you're not shooting at 4:42.") }
            if beforeClose {
                Segmented(items: [5, 10, 15, 30].map { ("\($0)", "\($0) min") }, selected: "\(lead)") { lead = Int($0)! }
            }
            Text("For \(spot.rules.label.lowercased()) at \(spot.name ?? "your spot"). Scheduled on the phone two weeks ahead, so they fire with no signal.")
                .font(.mono(11)).foregroundStyle(Theme.comment)
            if denied {
                Text("Notifications are off for Legal Light. Turn them on in Settings → Notifications.").font(.mono(11)).foregroundStyle(Theme.lantern)
            }
        }
        .tint(Theme.mallard)
        .onChange(of: atOpen) { _, on in changed(on) }
        .onChange(of: beforeClose) { _, on in changed(on) }
        .onChange(of: lead) { _, _ in Alerts.reschedule(spot) }
    }

    private func changed(_ on: Bool) {
        Task {
            if on { denied = !(await Alerts.requestPermission()) }
            Alerts.reschedule(spot)
        }
    }

    private func label(_ t: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(t).font(.mono(14, .medium)).foregroundStyle(Theme.bone)
            Text(sub).font(.mono(11)).foregroundStyle(Theme.comment)
        }
    }
}
