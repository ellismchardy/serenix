import SwiftUI

@main
struct SerenixApp: App {
    @StateObject private var connection = StrapConnection()
    @StateObject private var profile = ProfileStore()
    @StateObject private var appearance = AppearanceStore()
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
            .onAppear {
                profile.onLoadInputsChange = { [connection] in
                    connection.redoLoadAfterProfileChange()
                }
            }
            // The Look's accent everywhere, and the Appearance setting (spec 002, Look).
            .tint(Theme.accent)
            .environmentObject(appearance)
            // A History Sync runs each time Serenix comes to the foreground (spec 001).
            .onChange(of: scenePhase, initial: true) { oldPhase, newPhase in
                switch newPhase {
                case .active:
                    // The window exists by now, so the saved Appearance can be applied to it.
                    appearance.apply()
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
