import SerenixCore
import SwiftUI

/// The tab bar (specs 012, 014): Today and Sleep, sharing the Day shown, then Body.
struct MainTabs: View {
    @ObservedObject var connection: StrapConnection
    @ObservedObject var profile: ProfileStore
    /// The user's Body data, in its own store (ADR 0008).
    @StateObject private var bodyStore = BodyStore()
    /// The Day picked on either tab; nil is today, whatever today is when the tabs draw.
    @State private var pickedDay: Day?
    /// The sync pill swiped away on either tab: one pill across both (spec 002, Sync pill).
    @State private var dismissedPill: SyncPill?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            TodayScreen(
                connection: connection,
                profile: profile,
                pickedDay: $pickedDay,
                dismissedPill: $dismissedPill
            )
            .tabItem { Label("Today", systemImage: "sun.max") }
            SleepScreen(
                connection: connection,
                profile: profile,
                pickedDay: $pickedDay,
                dismissedPill: $dismissedPill
            )
            .tabItem { Label("Sleep", systemImage: "moon.zzz") }
            BodyScreen(store: bodyStore)
                .tabItem { Label("Body", systemImage: "figure") }
        }
        // The selected tab in the accent colour (spec 012, Tab bar).
        .tint(Theme.accent)
        // Serenix opens on today (spec 002), on both tabs, also when iOS kept it suspended
        // overnight.
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if oldPhase == .background, newPhase != .background { pickedDay = nil }
        }
    }
}
