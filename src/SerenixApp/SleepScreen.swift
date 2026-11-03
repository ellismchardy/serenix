import SerenixCore
import SwiftUI

/// The Sleep tab (spec 011): draws the Sleep view for the Day shown, inside the same top bar and
/// sync pill as the Today tab.
struct SleepScreen: View {
    @ObservedObject var connection: StrapConnection
    @ObservedObject var profile: ProfileStore
    /// The Day shown, shared with the Today tab; nil is today.
    @Binding var pickedDay: Day?
    /// The sync pill swiped away, shared with the other tab so there is one pill.
    @Binding var dismissedPill: SyncPill?
    @State private var showsProfileMenu = false
    @State private var showsSleepPopup = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let now = Date()
        let shownDay = pickedDay ?? Day(containing: now, in: .current)
        // The Today view gives the shared top bar and pill their content, and the Sleep popup.
        let today = TodayView(
            connection: connection,
            profile: profile,
            showing: shownDay,
            now: now
        )
        let sleep = SleepView(
            nights: connection.nights,
            showing: shownDay,
            now: now,
            timeZone: .current,
            birthYear: profile.birthYear
        )
        ScreenChrome(
            connection: connection,
            profile: profile,
            pickedDay: $pickedDay,
            showsProfileMenu: $showsProfileMenu,
            dismissedPill: $dismissedPill,
            today: today
        ) {
            WeekStripView(strip: sleep.weekStrip) { pickedDay = shownSelection($0) }
            if let lastNight = sleep.lastNight {
                lastNightCard(lastNight)
            } else if let message = sleep.noNightMessage {
                Text(message)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showsSleepPopup) {
            TodayPopupView(popup: .sleep, today: today, connection: connection)
        }
        // Back from the background, the tabs show today (spec 002); the popup described the Day
        // being left, so it closes, as on the Today tab.
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if oldPhase == .background, newPhase != .background { showsSleepPopup = false }
        }
    }

    /// Last night (spec 011): its title, Time Asleep and the Sleep Score button, then Time in Bed.
    private func lastNightCard(_ lastNight: SleepLastNight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lastNight.title).font(.headline)
                    Text(lastNight.timeAsleepText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Sleep Score \u{203A}") { showsSleepPopup = true }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.accentSoft, in: Capsule())
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.accent)
            }
            if let inBed = lastNight.inBedText {
                Text(inBed)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .themeCard()
    }
}
