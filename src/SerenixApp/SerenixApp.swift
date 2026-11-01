import SwiftUI

@main
struct SerenixApp: App {
    @StateObject private var connection = StrapConnection()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            TodayScreen(connection: connection)
                // A History Sync runs each time Serenix comes to the foreground (spec 001).
                .onChange(of: scenePhase, initial: true) { oldPhase, newPhase in
                    switch newPhase {
                    case .active:
                        connection.sceneBecameActive(fromBackground: oldPhase == .background)
                    case .background:
                        connection.sceneWentToBackground()
                    default:
                        break
                    }
                }
        }
    }
}
