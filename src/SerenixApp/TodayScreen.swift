import SerenixCore
import SwiftUI

/// The Today screen (spec 002): draws the Today view for the Day shown and sends taps back.
struct TodayScreen: View {
    @ObservedObject var connection: StrapConnection
    @ObservedObject var profile: ProfileStore
    /// The Day picked in the week strip or the date picker, shared with the Sleep tab (spec 012);
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
    /// Rings or Story, from the profile menu (spec 013).
    @AppStorage(TodayLayout.storageKey) private var todayLayout = TodayLayout.rings

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
            switch todayLayout {
            case .rings:
                if let message = today.noNightMessage {
                    Text(message)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    noNightRestingHR(today)
                }
                rings(today)
                readinessMessage(today, for: shownDay)
                vsBaseline(today)
                tiles(today)
            case .story:
                StoryBodyView(today: today) { openStoryTap($0, in: today) }
            }
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
                openLoad(today)
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

    /// On a Day with no Night, its Resting HR tile on its own under the message, when the Day
    /// has one (spec 002, No Night for the Day): half the width, as a cell of the tile grid.
    @ViewBuilder
    private func noNightRestingHR(_ today: TodayView) -> some View {
        if let tile = today.restingHRTile {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                Button {
                    open(.restingHR, in: today)
                } label: {
                    RestingHRTileView(tile: tile)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Under "Last night" or the date: Time Asleep across the full width, then the Nightly Metric
    /// tiles and the Resting HR tile in a 2-column grid (spec 007); none on a Day without a Night,
    /// where the Resting HR tile shows under the message instead.
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
                            Button {
                                open(.restingHR, in: today)
                            } label: {
                                RestingHRTileView(tile: tile)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    /// A tap in the Story opens the popup the Rings layout's would; Load opens the profile menu
    /// while it asks for the age, as the Load ring does.
    /// Named apart from `open(_:in:)`: StoryTap and TodayPopup share case names, so one
    /// overloaded name makes `.sleep` ambiguous.
    private func openStoryTap(_ tap: StoryTap, in today: TodayView) {
        switch tap {
        case .sleep: open(.sleep, in: today)
        case .metric(let metric): open(.metric(metric), in: today)
        case .readiness: open(.readiness, in: today)
        case .load: openLoad(today)
        }
    }

    /// The profile menu while Load asks for the age (spec 005, Add your age), else the Load
    /// popup (spec 006); for the Load ring and the Story's Load step alike.
    private func openLoad(_ today: TodayView) {
        if today.loadOpensProfileMenu {
            showsProfileMenu = true
        } else {
            open(.load, in: today)
        }
    }

    /// Opens a popup, unless the Today view has nothing for it to show (a Day without a Night).
    private func open(_ popup: TodayPopup, in today: TodayView) {
        let hasContent =
            switch popup {
            case .readiness: today.readinessPopup != nil
            case .sleep: today.sleepPopup != nil
            case .metric(let metric): today.metricPopup(metric) != nil
            case .restingHR: today.restingHRPopup != nil
            case .load: today.loadPopup != nil
            }
        if hasContent { openPopup = popup }
    }
}

/// All three rings' size, points (spec 002, Rings: the same size).
private let ringDiameter: CGFloat = 84
