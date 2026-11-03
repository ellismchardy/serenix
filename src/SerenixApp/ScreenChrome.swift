import SerenixCore
import SwiftUI

/// What the Today and Sleep tabs share (spec 002, Top bar and Sync pill; spec 012, Tab bar): the
/// top bar, the sync pill over the top, pull to sync, the date picker and the profile menu, around
/// a tab's own content. The Today view gives the top bar and pill their content.
struct ScreenChrome<Content: View>: View {
    @ObservedObject var connection: StrapConnection
    @ObservedObject var profile: ProfileStore
    /// The Day shown, shared by both tabs; nil is today.
    @Binding var pickedDay: Day?
    /// Owned by the tab, since its content can open the profile menu too (the Load ring).
    @Binding var showsProfileMenu: Bool
    /// The pill the user swiped away, or "Sync successful" once its 3 seconds are up; it shows
    /// again as soon as the Today view gives a different pill. Shared by both tabs, so there is
    /// one pill.
    @Binding var dismissedPill: SyncPill?
    let today: TodayView
    @ViewBuilder let content: () -> Content

    @State private var showsDatePicker = false
    /// The bell is a placeholder until a notifications spec (spec 002, Non-goals).
    @State private var showsNotifications = false
    /// The paused, failed or syncing pill whose detail is open, kept as tapped while it's open.
    @State private var detailPill: SyncPill?
    @State private var showsPillDetail = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    topBar
                    content()
                }
                .padding()
            }
            .background(Theme.background.ignoresSafeArea())
            // Pulling down starts a sync (001's Sync now) unless one is running.
            .refreshable { @MainActor in
                if !connection.phase.isBusy { connection.syncNow() }
            }
            .overlay(alignment: .top) {
                syncPill.animation(.spring, value: visiblePill)
            }
            .onChange(of: today.syncPill) { dismissedPill = nil }
            // "Sync successful" slides away after 3 seconds.
            .task(id: today.syncPill) {
                guard let pill = today.syncPill, pill.kind == .successful else { return }
                try? await Task.sleep(for: .seconds(successfulPillSeconds))
                if !Task.isCancelled { dismissedPill = pill }
            }
            .alert(
                detailPill?.text ?? "",
                isPresented: $showsPillDetail,
                presenting: detailPill
            ) { pill in
                if pill.kind == .syncing {
                    Button("Cancel sync", role: .destructive) { connection.cancel() }
                    Button("Keep syncing", role: .cancel) {}
                } else {
                    Button("Retry") { connection.syncNow() }
                    Button("OK", role: .cancel) { dismissedPill = pill }
                }
            } message: { pill in
                Text(pill.detail ?? "")
            }
            .alert("No notifications yet.", isPresented: $showsNotifications) {
                Button("OK", role: .cancel) {}
            }
            .sheet(isPresented: $showsDatePicker) {
                DayPicker(range: today.pickerDates, shown: today.shownDate) { picked in
                    pickedDay = shownSelection(Day(containing: picked, in: .current))
                    showsDatePicker = false
                }
            }
            .sheet(isPresented: $showsProfileMenu) {
                ProfileMenu(
                    connection: connection,
                    profile: profile,
                    avatarLetter: today.avatarLetter,
                    menuName: today.menuName,
                    syncOffersRetry: today.syncOffersRetry,
                    showsSyncProgress: today.syncPill?.showsProgress ?? false
                )
            }
        }
    }

    /// The avatar opening the profile menu, the greeting over the Profile name, and the calendar
    /// and bell buttons (spec 002, Top bar).
    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                showsProfileMenu = true
            } label: {
                Avatar(letter: today.avatarLetter, diameter: 44)
            }
            .accessibilityLabel("Profile")
            VStack(alignment: .leading, spacing: 2) {
                Text(today.greeting)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let name = today.greetingName {
                    Text(name).font(.headline.bold())
                }
            }
            .lineLimit(1)
            Spacer()
            roundButton("calendar", label: "Pick a Day") { showsDatePicker = true }
            roundButton("bell", label: "Notifications") { showsNotifications = true }
        }
    }

    /// A round icon button in the top bar.
    private func roundButton(_ symbol: String, label: String, action: @escaping () -> Void)
        -> some View
    {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 40, height: 40)
                .themeCard(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// The Today view's sync pill, unless it was swiped away or has timed out.
    private var visiblePill: SyncPill? {
        guard let pill = today.syncPill, pill != dismissedPill else { return nil }
        return pill
    }

    /// The pill sliding down over the top: tap a syncing pill to cancel, a paused or failed one
    /// for its reason and Retry; swipe up to put it away.
    @ViewBuilder
    private var syncPill: some View {
        if let pill = visiblePill {
            SyncPillView(pill: pill)
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture {
                    if pill.kind == .successful {
                        dismissedPill = pill
                    } else {
                        detailPill = pill
                        showsPillDetail = true
                    }
                }
                // Syncing stays up until the sync ends, keeping Cancel in reach.
                .gesture(
                    DragGesture(minimumDistance: 10).onEnded { drag in
                        if drag.translation.height < 0, pill.canBeDismissed { dismissedPill = pill }
                    }
                )
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(named: "Dismiss") {
                    if pill.canBeDismissed { dismissedPill = pill }
                }
        }
    }
}

extension TodayView {
    /// The Today view for the Day shown, from the phone's stored Nights, Day Loads, sync and
    /// Profile, as both tabs need it.
    init(
        connection: StrapConnection,
        profile: ProfileStore,
        showing day: Day,
        now: Date
    ) {
        self.init(
            nights: connection.nights,
            dayLoads: connection.dayLoads,
            showing: day,
            now: now,
            timeZone: .current,
            sync: connection.syncStatus,
            profileName: profile.name,
            birthYear: profile.birthYear,
            lastSyncEnded: connection.lastSyncCompleted
        )
    }
}

/// The picked Day to keep for `day`, from the week strip or the date picker: today means today
/// (nil), so the tabs move on at midnight like opening does.
func shownSelection(_ day: Day) -> Day? {
    day == Day(containing: Date(), in: .current) ? nil : day
}

/// The date picker the calendar button opens: a graphical calendar limited to the Today view's
/// range, from the Day of the earliest Night to today. Picking a date shows it.
private struct DayPicker: View {
    let range: ClosedRange<Date>
    let pick: (Date) -> Void
    @State private var selection: Date

    init(range: ClosedRange<Date>, shown: Date, pick: @escaping (Date) -> Void) {
        self.range = range
        self.pick = pick
        _selection = State(initialValue: shown)
    }

    var body: some View {
        NavigationStack {
            DatePicker("Day", selection: $selection, in: range, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding()
                .navigationTitle("Pick a Day")
                .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .onChange(of: selection) { _, picked in pick(picked) }
    }
}

/// How long "Sync successful" stays up (spec 002, Sync pill).
private let successfulPillSeconds = 3
