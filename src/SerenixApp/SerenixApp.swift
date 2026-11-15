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
                // Onboarding comes once, before the tabs (spec 014).
                if profile.hasFinishedOnboarding {
                    MainTabs(connection: connection, profile: profile)
                } else {
                    OnboardingScreen(connection: connection, profile: profile)
                }
            }
            .onAppear {
                profile.onLoadInputsChange = { [connection] in
                    connection.redoLoadAfterProfileChange()
                }
            }
            // Controls in ink everywhere (spec 018: one accent, red, kept for verdicts and bars),
            // and the Appearance setting (spec 002, Look).
            .tint(Poster.ink)
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
