import SwiftUI

@main
struct SerenixApp: App {
    @StateObject private var connection = StrapConnection()
    @StateObject private var profile = ProfileStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                // The name is asked for once, before the Today screen (spec 002, Profile).
                if profile.hasBeenAskedForName {
                    TodayScreen(connection: connection, profile: profile)
                } else {
                    NamePrompt(profile: profile)
                }
            }
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
