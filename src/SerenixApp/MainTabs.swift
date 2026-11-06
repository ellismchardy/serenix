import SerenixCore
import SwiftUI

/// The tab bar (specs 012, 015): Today and Sleep, sharing the Day shown, then Body.
struct MainTabs: View {
    @ObservedObject var connection: StrapConnection
    @ObservedObject var profile: ProfileStore
    /// The user's Body data, in its own store (ADR 0008).
    @StateObject private var bodyStore = BodyStore()
    /// The user's Food Entries, in their own store file (spec 016).
    @StateObject private var foodStore = FoodStore()
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
            BodyScreen(store: bodyStore, foodStore: foodStore, profile: profile)
                .tabItem { Label("Body", systemImage: "figure") }
        }
        // The selected tab in the accent colour (spec 012, Tab bar).
        .tint(Theme.accent)
        // For the profile menu's Body data export and import (spec 015).
        .environmentObject(bodyStore)
        // Serenix opens on today (spec 002), on both tabs, also when iOS kept it suspended
        // overnight.
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if oldPhase == .background, newPhase != .background { pickedDay = nil }
        }
    }
}
