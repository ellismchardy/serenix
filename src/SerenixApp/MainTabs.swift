import SerenixCore
import SwiftUI

/// The tab bar (specs 012, 015): Today and Sleep, sharing the Day shown, then Body. Drawn as
/// spec 018's block tab bar: three equal cells under a heavy rule, the current one a solid ink
/// block. The system tab bar is hidden, so each tab keeps its own state as before.
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
    @State private var tab = MainTab.today
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $tab) {
                TodayScreen(
                    connection: connection,
                    profile: profile,
                    pickedDay: $pickedDay,
                    dismissedPill: $dismissedPill
                )
                .tag(MainTab.today)
                .toolbar(.hidden, for: .tabBar)
                SleepScreen(
                    connection: connection,
                    profile: profile,
                    pickedDay: $pickedDay,
                    dismissedPill: $dismissedPill
                )
                .tag(MainTab.sleep)
                .toolbar(.hidden, for: .tabBar)
                BodyScreen(store: bodyStore, foodStore: foodStore, profile: profile)
                    .tag(MainTab.body)
                    .toolbar(.hidden, for: .tabBar)
            }
            PosterTabBar(selection: $tab)
        }
        .background(Poster.paper.ignoresSafeArea())
        // For the profile menu's Body data export and import (spec 015).
        .environmentObject(bodyStore)
        .environmentObject(foodStore)
        // Serenix opens on today (spec 002), on both tabs, also when iOS kept it suspended
        // overnight.
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if oldPhase == .background, newPhase != .background { pickedDay = nil }
        }
    }
}

/// The three main tabs, in the tab bar's order.
private enum MainTab: CaseIterable {
    case today
    case sleep
    case body

    var name: String {
        switch self {
        case .today: "Today"
        case .sleep: "Sleep"
        case .body: "Body"
        }
    }
}

/// Today, Sleep and Body as three equal cells under a heavy rule; the current tab a solid block
/// in the type colour with the paper colour as text (spec 018, Tab bar).
private struct PosterTabBar: View {
    @Binding var selection: MainTab

    var body: some View {
        VStack(spacing: 0) {
            PosterRule()
            HStack(spacing: 0) {
                ForEach(MainTab.allCases, id: \.self) { tab in
                    let isCurrent = tab == selection
                    Button {
                        selection = tab
                    } label: {
                        Text(tab.name.uppercased())
                            .font(Poster.labelFont)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isCurrent ? Poster.ink : Color.clear)
                            .foregroundStyle(isCurrent ? Poster.paper : Poster.ink)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.name)
                    .accessibilityAddTraits(isCurrent ? .isSelected : [])
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Tabs")
        }
    }
}
