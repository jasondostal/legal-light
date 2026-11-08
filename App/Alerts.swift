import Foundation
import HoursCore
import UserNotifications

/// Local notifications at legal light and N minutes before close. They're
/// scheduled ahead (two weeks, well under iOS's 64 pending limit), so they fire
/// with no signal and with the app closed. Rescheduled whenever the spot,
/// species or settings change, and each time the app comes forward.
enum Alerts {
    static let openKey = "alerts.open", closeKey = "alerts.close", leadKey = "alerts.closeLead"
    static let days = 14

    static var wantsOpen: Bool { UserDefaults.standard.bool(forKey: openKey) }
    static var wantsClose: Bool { UserDefaults.standard.bool(forKey: closeKey) }
    static var lead: Int { let v = UserDefaults.standard.integer(forKey: leadKey); return v == 0 ? 10 : v }

    /// Ask once, when a toggle is first switched on.
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func reschedule(_ spot: Spot, now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard wantsOpen || wantsClose else { return }
        let name = spot.name ?? "your spot"
        let today = Central.today(now)
        for i in 0..<days {
            let h = spot.hours(on: today.adding(days: i))
            if wantsOpen, h.open > now {
                add(center, id: "open-\(h.date)", at: h.open,
                    title: "Legal light · \(spot.rules.short)",
                    body: "Shooting hours are open at \(name). Closes at \(Fmt.time(h.close)).")
            }
            let warn = h.close.addingTimeInterval(-Double(lead) * 60)
            if wantsClose, warn > now {
                add(center, id: "close-\(h.date)", at: warn,
                    title: "\(lead) minutes of legal light left",
                    body: "\(spot.rules.short) close at \(Fmt.time(h.close)) at \(name).")
            }
        }
    }

    private static func add(_ center: UNUserNotificationCenter, id: String, at date: Date, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive   // gets through a Focus in the blind
        var comps = Central.calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        comps.timeZone = Central.zone
        center.add(UNNotificationRequest(identifier: id, content: content,
                                         trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
    }
}

/// Show alerts as banners even while the app is open.
final class AlertPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AlertPresenter()
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
