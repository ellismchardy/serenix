import SerenixCore
import SwiftUI

/// The Today screen (spec 002): draws the Today view for the Day shown and sends taps back.
struct TodayScreen: View {
    @ObservedObject var connection: StrapConnection
    @ObservedObject var profile: ProfileStore
    /// The Day picked in the date picker; nil is today, whatever today is when the screen draws.
    @State private var pickedDay: Day?
    @State private var showsDatePicker = false
    @State private var showsSyncFailure = false
    @State private var openPopup: TodayPopup?
    @State private var showsProfileMenu = false
    /// Debug's "Show sample Nights" (plan 002, task 8): off at launch and never saved.
    @State private var showsSampleNights = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        // No Night or Load is computed yet (each is its own spec), so both are empty unless
        // Debug's sample Nights are on.
        let now = Date()
        let samples =
            showsSampleNights
            ? SampleNights.make(now: now, calendar: .current)
            : (nights: [Night](), dayLoads: [DayLoad]())
        let shownDay = pickedDay ?? Day(containing: now, in: .current)
        let today = TodayView(
            nights: samples.nights,
            dayLoads: samples.dayLoads,
            showing: shownDay,
            now: now,
            timeZone: .current,
            sync: connection.syncStatus,
            profileName: profile.name
        )
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    topBar(today)
                    if let greeting = today.greeting {
                        Text(greeting)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    syncRow(today)
                    if let message = today.noNightMessage {
                        Text(message)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    rings(today)
                    vsBaseline(today)
                    tiles(today)
                }
                .padding()
            }
            .alert("Sync failed", isPresented: $showsSyncFailure) {
                Button("Retry") { connection.syncNow() }
                Button("OK", role: .cancel) {}
            } message: {
                Text(today.syncPill.failureReason ?? "")
            }
            .sheet(item: $openPopup) { popup in
                TodayPopupView(popup: popup, today: today)
            }
            .sheet(isPresented: $showsDatePicker) {
                DayPicker(range: today.pickerDates, shown: today.shownDate) { picked in
                    let day = Day(containing: picked, in: .current)
                    // Picking today means today, so it moves on at midnight like opening does.
                    pickedDay = day == Day(containing: Date(), in: .current) ? nil : day
                    showsDatePicker = false
                }
            }
            .sheet(isPresented: $showsProfileMenu) {
                ProfileMenu(connection: connection, showsSampleNights: $showsSampleNights)
            }
            // Switching the sample Nights on or off starts again from today.
            .onChange(of: showsSampleNights) { showToday() }
            // Serenix opens on today (spec 002), also when iOS kept it suspended overnight.
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if oldPhase == .background, newPhase != .background { showToday() }
            }
        }
    }

    /// The Day's date as a large title with ▾ opening the date picker, the Today pill on other
    /// Days, and the profile avatar (spec 002, Top bar).
    private func topBar(_ today: TodayView) -> some View {
        HStack(spacing: 12) {
            Button {
                showsDatePicker = true
            } label: {
                HStack(spacing: 6) {
                    Text(today.title)
                        .font(.largeTitle.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Image(systemName: "chevron.down")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Pick a Day")
            if today.showsTodayPill {
                Button("Today") { showToday() }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
            }
            Spacer()
            Button {
                showsProfileMenu = true
            } label: {
                Avatar(letter: today.avatarLetter, diameter: 40)
            }
            .accessibilityLabel("Profile")
        }
    }

    /// The sync pill and 001's progress and Cancel; task 3 turns this into the pop-up pill.
    private func syncRow(_ today: TodayView) -> some View {
        VStack(spacing: 6) {
            HStack {
                Button(today.syncPill.text) { tapSyncPill(today.syncPill) }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                Spacer()
            }
            if today.syncPill.showsProgress {
                SyncProgressView(
                    progress: connection.syncProgress,
                    timeLeft: connection.syncTimeLeft
                )
            }
            // 001's Cancel, kept while connecting or syncing.
            if connection.phase.isBusy {
                Button("Cancel", role: .cancel) { connection.cancel() }
                    .font(.footnote)
            }
        }
    }

    /// Sleep Score, Readiness in the middle and largest with its band word, and Load.
    private func rings(_ today: TodayView) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                open(.sleep, in: today)
            } label: {
                ScoreRing(
                    text: today.sleepScoreText,
                    fill: today.sleepScoreFill,
                    label: "Sleep Score",
                    diameter: 84
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            VStack(spacing: 8) {
                Button {
                    open(.readiness, in: today)
                } label: {
                    ScoreRing(
                        text: today.readinessText,
                        fill: today.readinessFill,
                        label: "Readiness",
                        diameter: 170,
                        colour: today.readinessBand?.colour ?? .secondary,
                        labelInside: true
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if let band = today.readinessBand {
                    Text(band.word)
                        .font(.title3.bold())
                        .foregroundStyle(band.colour)
                }
            }
            ScoreRing(
                text: today.loadText,
                fill: today.loadFill,
                label: today.loadLabel,
                diameter: 84
            )
            // Tapping the Load ring does nothing in spec 002.
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
        case .calibrating(let line):
            Text(line)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
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
            }
        if hasContent { openPopup = popup }
    }

    /// Back to today, closing any popup, which described the Day being left.
    private func showToday() {
        openPopup = nil
        pickedDay = nil
    }

    /// A failed sync shows its reason and Retry; otherwise a tap starts a sync unless one is
    /// already running.
    private func tapSyncPill(_ pill: SyncPill) {
        if pill.failureReason != nil {
            showsSyncFailure = true
        } else if !connection.phase.isBusy {
            connection.syncNow()
        }
    }
}

/// A running sync's progress bar and time left (spec 001, Sync progress): "Starting…" until the
/// session reports progress.
private struct SyncProgressView: View {
    let progress: Double?
    let timeLeft: TimeInterval?

    var body: some View {
        if let progress {
            VStack(spacing: 4) {
                ProgressView(value: progress)
                if let timeLeft {
                    Text(HistorySync.timeLeftText(timeLeft))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
        } else {
            Text("Starting…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

/// The date picker the title's ▾ opens: a graphical calendar limited to the Today view's range,
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
