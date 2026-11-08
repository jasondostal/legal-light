import AppIntents
import HoursCore
import SwiftUI
import WidgetKit

// MARK: - configuration: which rule set this widget counts

enum RulesChoice: String, AppEnum {
    case app, waterfowl, smallgame, teal, springturkey

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Hours" }
    static var caseDisplayRepresentations: [RulesChoice: DisplayRepresentation] {
        [.app: "Same as the app", .waterfowl: "Ducks & geese", .smallgame: "Deer & small game",
         .teal: "Early teal", .springturkey: "Spring turkey"]
    }
    var rules: RuleSet? { RuleSet(rawValue: rawValue) }
}

struct HoursConfig: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Shooting hours" }
    static var description: IntentDescription { "Counts down to legal shooting light, and to close." }
    @Parameter(title: "Hours for", default: .app) var choice: RulesChoice
}

// MARK: - timeline

struct Provider: AppIntentTimelineProvider {
    func entry(at d: Date, _ config: HoursConfig) -> HoursEntry {
        let saved = SharedStore.load()
        let spot = saved ?? .stevensPoint
        let rules = config.choice.rules ?? spot.rules
        return HoursEntry(date: d, spot: spot, rules: rules, status: spot.status(at: d, rules: rules), hasSpot: saved != nil)
    }

    func placeholder(in context: Context) -> HoursEntry { entry(at: Date(), HoursConfig()) }

    func snapshot(for config: HoursConfig, in context: Context) async -> HoursEntry { entry(at: Date(), config) }

    /// One entry now and one at every opening and closing for the next three
    /// days. The countdown itself is a live Text timer, so between transitions
    /// the widget needs no refreshes at all.
    func timeline(for config: HoursConfig, in context: Context) async -> Timeline<HoursEntry> {
        let now = Date()
        let probe = entry(at: now, config)
        let moments = [now] + probe.spot.transitions(from: now, days: 3, rules: probe.rules)
        let entries = moments.map { entry(at: $0, config) }
        return Timeline(entries: entries, policy: .after(moments.last ?? now.addingTimeInterval(3600)))
    }
}

struct HoursWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "HoursWidget", intent: HoursConfig.self, provider: Provider()) { e in
            HoursWidgetView(e: e)
                .containerBackground(for: .widget) { Theme.night }
        }
        .configurationDisplayName("Shooting hours")
        .description("Counts down to legal light and to close, for your spot.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct HoursWidgets: WidgetBundle {
    var body: some Widget {
        HoursWidget()
        HuntLiveActivity()
    }
}
