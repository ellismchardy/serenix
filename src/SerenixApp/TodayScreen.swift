import SerenixCore
import SwiftUI

/// The Today screen (spec 002): draws the Today view for the Day shown and sends taps back.
struct TodayScreen: View {
    @ObservedObject var connection: StrapConnection
    @ObservedObject var profile: ProfileStore
    /// The Day picked in the week strip or the date picker; nil is today, whatever today is when
    /// the screen draws.
    @State private var pickedDay: Day?
    @State private var showsDatePicker = false
    /// The bell is a placeholder until a notifications spec (spec 002, Non-goals).
    @State private var showsNotifications = false
    /// The pill the user swiped away, or "Sync successful" once its 3 seconds are up; it shows
    /// again as soon as the Today view gives a different pill.
    @State private var dismissedPill: SyncPill?
    /// The paused, failed or syncing pill whose detail is open, kept as tapped while it's open.
    @State private var detailPill: SyncPill?
    @State private var showsPillDetail = false
    @State private var openPopup: TodayPopup?
    @State private var showsProfileMenu = false
    /// The Nights whose Readiness message was closed, kept on the phone (spec 002, Readiness
    /// message).
    @State private var closedMessages = ClosedReadinessMessages()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        // The stored Nights (spec 003) and Day Loads (spec 005).
        let now = Date()
        let shownDay = pickedDay ?? Day(containing: now, in: .current)
        let today = TodayView(
            nights: connection.nights,
            dayLoads: connection.dayLoads,
            showing: shownDay,
            now: now,
            timeZone: .current,
            sync: connection.syncStatus,
            profileName: profile.name,
            lastSyncEnded: connection.lastSyncCompleted
        )
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    topBar(today)
                    WeekStripView(strip: today.weekStrip) { show($0) }
                    if let message = today.noNightMessage {
                        Text(message)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    rings(today)
                    readinessMessage(today, for: shownDay)
                    vsBaseline(today)
                    tiles(today)
                }
                .padding()
            }
            .background(Theme.background.ignoresSafeArea())
            // Pulling down starts a sync (001's Sync now) unless one is running.
            .refreshable { @MainActor in
                if !connection.phase.isBusy { connection.syncNow() }
            }
            .overlay(alignment: .top) {
                syncPill(today).animation(.spring, value: visiblePill(today))
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
            .sheet(item: $openPopup) { popup in
                TodayPopupView(popup: popup, today: today, connection: connection)
            }
            .alert("No notifications yet.", isPresented: $showsNotifications) {
                Button("OK", role: .cancel) {}
            }
            .sheet(isPresented: $showsDatePicker) {
                DayPicker(range: today.pickerDates, shown: today.shownDate) { picked in
                    show(Day(containing: picked, in: .current))
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
            // Serenix opens on today (spec 002), also when iOS kept it suspended overnight.
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if oldPhase == .background, newPhase != .background { showToday() }
            }
        }
    }

    /// The avatar opening the profile menu, the greeting over the Profile name, and the calendar
    /// and bell buttons (spec 002, Top bar).
    private func topBar(_ today: TodayView) -> some View {
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
    private func visiblePill(_ today: TodayView) -> SyncPill? {
        guard let pill = today.syncPill, pill != dismissedPill else { return nil }
        return pill
    }

    /// The pill sliding down over the top: tap a syncing pill to cancel, a paused or failed one
    /// for its reason and Retry; swipe up to put it away.
    @ViewBuilder
    private func syncPill(_ today: TodayView) -> some View {
        if let pill = visiblePill(today) {
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

    /// Sleep Score, Readiness in the middle and Load, the same size, spread evenly across the card.
    private func rings(_ today: TodayView) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Button {
                open(.sleep, in: today)
            } label: {
                ScoreRing(
                    text: today.sleepScoreText,
                    fill: today.sleepScoreFill,
                    label: "Sleep Score",
                    diameter: ringDiameter,
                    colour: Theme.accent
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            Button {
                open(.readiness, in: today)
            } label: {
                ScoreRing(
                    text: today.readinessText,
                    fill: today.readinessFill,
                    label: "Readiness",
                    diameter: ringDiameter,
                    colour: today.readinessBand?.colour ?? .secondary
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            // The Load ring opens the profile menu while it asks for the age (spec 005, Add your
            // age), and the Load popup otherwise (spec 006).
            Button {
                if today.loadOpensProfileMenu {
                    showsProfileMenu = true
                } else {
                    open(.load, in: today)
                }
            } label: {
                loadRing(today).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(
                today.loadOpensProfileMenu ? "Opens your profile" : "Shows your Load"
            )
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .themeCard()
    }

    private func loadRing(_ today: TodayView) -> some View {
        ScoreRing(
            text: today.loadText,
            fill: today.loadFill,
            label: today.loadLabel,
            diameter: ringDiameter
        )
    }

    /// The band word for the Night shown, in its colour, with the Today view's advice under it,
    /// on a card with an ✕ that hides it for that Night; none while Readiness is Calibrating or
    /// missing.
    @ViewBuilder
    private func readinessMessage(_ today: TodayView, for day: Day) -> some View {
        if let band = today.readinessBand, !closedMessages.contains(day) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(band.word)
                        .font(.headline)
                        .foregroundStyle(band.colour)
                    if let advice = today.readinessAdvice {
                        Text(advice)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                Button {
                    withAnimation { closedMessages.close(day) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Theme.accentSoft, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(16)
            .themeCard()
            .transition(.opacity)
        }
    }

    /// HRV and Resting HR against Baseline, or the one Calibrating line; nothing on a Day without
    /// a Night.
    @ViewBuilder
    private func vsBaseline(_ today: TodayView) -> some View {
        switch today.vsBaseline {
        case .comparisons(let comparisons):
            VStack(alignment: .leading, spacing: 8) {
                Text("vs your Baseline")
                    .font(.headline)
                ForEach(comparisons, id: \.metric) { comparison in
                    BaselineComparisonRow(comparison: comparison)
                }
            }
            .padding(16)
            .themeCard()
        case .calibrating(let line):
            Text(line)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .themeCard()
        case nil:
            EmptyView()
        }
    }

    /// Under "Last night" or the date: Time Asleep, then the Nightly Metric tiles, in a 2-column
    /// grid; none on a Day without a Night.
    private func tiles(_ today: TodayView) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if today.noNightMessage == nil {
                Text(today.tilesHeading)
                    .font(.headline)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    if let timeAsleep = today.timeAsleepTile {
                        Button {
                            open(.sleep, in: today)
                        } label: {
                            TimeAsleepTileView(tile: timeAsleep)
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(today.tiles, id: \.metric) { tile in
                        Button {
                            open(.metric(tile.metric), in: today)
                        } label: {
                            MetricTileView(tile: tile)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// Opens a popup, unless the Today view has nothing for it to show (a Day without a Night).
    private func open(_ popup: TodayPopup, in today: TodayView) {
        let hasContent =
            switch popup {
            case .readiness: today.readinessPopup != nil
            case .sleep: today.sleepPopup != nil
            case .metric(let metric): today.metricPopup(metric) != nil
            case .load: today.loadPopup != nil
            }
        if hasContent { openPopup = popup }
    }

    /// Shows `day`, from the week strip or the date picker. Today means today, so the screen moves
    /// on at midnight like opening does.
    private func show(_ day: Day) {
        pickedDay = day == Day(containing: Date(), in: .current) ? nil : day
    }

    /// Back to today, closing any popup, which described the Day being left.
    private func showToday() {
        openPopup = nil
        pickedDay = nil
    }
}

/// The date picker the calendar button opens: a graphical calendar limited to the Today view's range,
/// from the Day of the earliest Night to today. Picking a date shows it.
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

/// All three rings' size, points (spec 002, Rings: the same size).
private let ringDiameter: CGFloat = 84
