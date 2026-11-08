import SwiftUI
import UserNotifications

@main
struct ShootingHoursApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var phase

    init() { UNUserNotificationCenter.current().delegate = AlertPresenter.shared }

    @ViewBuilder private var root: some View {
        #if DEBUG
        if CommandLine.arguments.contains("-gallery") { WidgetGallery(spot: model.spot) } else { HomeView() }
        #else
        HomeView()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            root
                .environment(model)
                .preferredColorScheme(.dark)
                .onChange(of: phase) { _, p in if p == .active { model.foreground() } }
        }
    }
}
