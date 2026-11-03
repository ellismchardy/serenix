import SerenixCore
import SwiftUI

/// The Today screen (spec 002): draws the Today view for the Day shown and sends taps back.
struct TodayScreen: View {
    @ObservedObject var connection: StrapConnection
    @ObservedObject var profile: ProfileStore
    /// The Day picked in the week strip or the date picker, shared with the Sleep tab (spec 011);
    /// nil is today, whatever today is when the screen draws.
    @Binding var pickedDay: Day?
    /// The sync pill swiped away, shared with the other tab so there is one pill.
    @Binding var dismissedPill: SyncPill?
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
            connection: connection,
            profile: profile,
            showing: shownDay,
            now: now
        )
        ScreenChrome(
            connection: connection,
            profile: profile,
            pickedDay: $pickedDay,
            showsProfileMenu: $showsProfileMenu,
            dismissedPill: $dismissedPill,
            today: today
        ) {
            WeekStripView(strip: today.weekStrip) { pickedDay = shownSelection($0) }
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
        .sheet(item: $openPopup) { popup in
            TodayPopupView(popup: popup, today: today, connection: connection)
        }
        // Back from the background, the tabs show today (spec 002); a popup open then described
        // the Day being left, so it closes.
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if oldPhase == .background, newPhase != .background { openPopup = nil }
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

    /// HRV and Sleeping HR against Baseline, or the one Calibrating line; nothing on a Day without
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

    /// Under "Last night" or the date: Time Asleep across the full width, then the Nightly Metric
    /// tiles and the Resting HR tile in a 2-column grid (spec 007); none on a Day without a Night.
    private func tiles(_ today: TodayView) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if today.noNightMessage == nil {
                Text(today.tilesHeading)
                    .font(.headline)
                if let timeAsleep = today.timeAsleepTile {
                    Button {
                        open(.sleep, in: today)
                    } label: {
                        TimeAsleepTileView(tile: timeAsleep)
                    }
                    .buttonStyle(.plain)
                    // Matches the grid's 12pt gap, after the stack's 8.
                    .padding(.bottom, 4)
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(today.gridTiles) { gridTile in
                        switch gridTile {
                        case .metric(let tile):
                            Button {
                                open(.metric(tile.metric), in: today)
                            } label: {
                                MetricTileView(tile: tile)
                            }
                            .buttonStyle(.plain)
                        case .restingHR(let tile):
                            // Not a button: the Resting HR tile opens no popup.
                            RestingHRTileView(tile: tile)
                        }
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
}

/// All three rings' size, points (spec 002, Rings: the same size).
private let ringDiameter: CGFloat = 84
