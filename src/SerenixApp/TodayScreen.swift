import SerenixCore
import SwiftUI

/// The Today screen (spec 002): draws the Today view for the Day shown and sends taps back.
struct TodayScreen: View {
    @ObservedObject var connection: StrapConnection
    /// The Day stepped to with the arrows; nil is today, whatever today is when the screen draws.
    @State private var steppedToDay: Day?
    @State private var showsSyncFailure = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        // No Night or Load is computed yet (each is its own spec), so both start empty.
        let today = TodayView(
            nights: [],
            dayLoads: [],
            showing: steppedToDay ?? Day(containing: Date(), in: .current),
            now: Date(),
            timeZone: .current,
            sync: connection.syncStatus
        )
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    topRow(today)
                    header(today)
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
            // Serenix opens on today (spec 002), also when iOS kept it suspended overnight.
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if oldPhase == .background, newPhase != .background { steppedToDay = nil }
            }
        }
    }

    private func topRow(_ today: TodayView) -> some View {
        VStack(spacing: 6) {
            HStack {
                Button(today.syncPill.text) { tapSyncPill(today.syncPill) }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                Spacer()
                NavigationLink {
                    SettingsView(connection: connection)
                } label: {
                    Label("Settings", systemImage: "gearshape")
                        .labelStyle(.iconOnly)
                }
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
            ScoreRing(
                text: today.sleepScoreText,
                fill: today.sleepScoreFill,
                label: "Sleep Score",
                diameter: 84
            )
            VStack(spacing: 8) {
                ScoreRing(
                    text: today.readinessText,
                    fill: today.readinessFill,
                    label: "Readiness",
                    diameter: 170,
                    colour: today.readinessBand?.colour ?? .secondary,
                    labelInside: true
                )
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
                        TimeAsleepTileView(tile: timeAsleep)
                    }
                    ForEach(today.tiles, id: \.metric) { tile in
                        MetricTileView(tile: tile)
                    }
                }
            }
        }
    }

    private func header(_ today: TodayView) -> some View {
        HStack {
            Button {
                if let earlier = today.earlierDay { steppedToDay = earlier }
            } label: {
                Label("Earlier Day", systemImage: "chevron.left").labelStyle(.iconOnly)
            }
            .disabled(today.earlierDay == nil)
            Spacer()
            VStack(spacing: 2) {
                Text(today.title).font(.title2.bold())
                Text(today.subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                if let later = today.laterDay { steppedToDay = later }
            } label: {
                Label("Later Day", systemImage: "chevron.right").labelStyle(.iconOnly)
            }
            .disabled(today.laterDay == nil)
        }
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
