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
            tabName: "Today",
            connection: connection,
            profile: profile,
            pickedDay: $pickedDay,
            showsProfileMenu: $showsProfileMenu,
            dismissedPill: $dismissedPill,
            today: today
        ) {
            WeekStripView(strip: today.weekStrip) { pickedDay = shownSelection($0) }
            // Readiness as the headline with its verdict, over either layout (spec 018, Today).
            Button {
                open(.readiness, in: today)
            } label: {
                PosterHeadline(
                    number: today.readinessText,
                    verdict: today.readinessVerdict,
                    caption: "Readiness"
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            switch todayLayout {
            case .rings:
                // Concept M (spec 018, Today): the Readiness message, Load, Sleep Score and Time
                // Asleep, then the Nightly Metrics as rows.
                if let message = today.noNightMessage {
                    Text(message)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Poster.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                readinessMessage(today, for: shownDay)
                loadSection(today)
                if let timeAsleep = today.timeAsleepTile {
                    sleepSection(today, timeAsleep: timeAsleep)
                }
                metricsSection(today)
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

    /// The band word for the Night shown, in its colour, as a ruled section with the Today view's
    /// advice under it and an ✕ that hides it for that Night; none while Readiness is Calibrating
    /// or missing (spec 002, Readiness message; spec 018).
    @ViewBuilder
    private func readinessMessage(_ today: TodayView, for day: Day) -> some View {
        if let band = today.readinessBand, !closedMessages.contains(day) {
            VStack(alignment: .leading, spacing: 10) {
                PosterRule()
                HStack(alignment: .firstTextBaseline) {
                    Text(band.word.uppercased())
                        .font(Poster.labelFont)
                        .foregroundStyle(band.colour)
                    Spacer(minLength: 8)
                    Button {
                        withAnimation { closedMessages.close(day) }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Poster.ink)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
                if let advice = today.readinessAdvice {
                    Text(advice)
                        .font(.subheadline)
                        .foregroundStyle(Poster.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .transition(.opacity)
        }
    }

    /// The Day's Load as a large red number beside a bar from 0 to twice typical Load with a tick
    /// at typical Load, spec 006's sentence as the note; the number alone while typical Load is
    /// learned (spec 018, Today). It opens the Load popup, or the profile menu while Load asks
    /// for the age (spec 005).
    private func loadSection(_ today: TodayView) -> some View {
        let popup = today.loadPopup
        return Button {
            openLoad(today)
        } label: {
            RuledSection(name: today.loadLabel, note: popup?.comparisonText) {
                HStack(alignment: .center, spacing: 16) {
                    Text(today.loadText)
                        .font(Poster.headlineFont(size: 56))
                        .tracking(-2.8)
                        .foregroundStyle(Poster.red)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if let fill = popup?.loadBarFill {
                        PosterBar(fill: fill, tick: typicalLoadTick)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(today.loadOpensProfileMenu ? "Opens your profile" : "Shows your Load")
    }

    /// Sleep Score and Time Asleep side by side, each opening the Sleep popup (spec 018, Today);
    /// only with a Night, which always has Time Asleep.
    private func sleepSection(_ today: TodayView, timeAsleep: TimeAsleepTile) -> some View {
        Button {
            open(.sleep, in: today)
        } label: {
            HStack(alignment: .top, spacing: 16) {
                RuledSection(name: "Sleep Score") {
                    Text(today.sleepScoreText)
                        .font(Poster.headlineFont(size: 56))
                        .tracking(-2.8)
                        .foregroundStyle(Poster.ink)
                        .lineLimit(1)
                }
                RuledSection(name: "Time Asleep", note: timeAsleep.spanText) {
                    Text(timeAsleep.valueText)
                        .font(Poster.headlineFont(size: 40))
                        .tracking(-1.6)
                        .foregroundStyle(Poster.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// The Nightly Metrics and Resting HR as rows: name, value, and a tag with the difference from
    /// Baseline in the Zone's colour (spec 018, Today). While Calibrating, the Calibrating line is
    /// the section's note. On a Day without a Night, only Resting HR, when the Day has one.
    @ViewBuilder
    private func metricsSection(_ today: TodayView) -> some View {
        let calibratingLine: String? =
            if case .calibrating(let line) = today.vsBaseline { line } else { nil }
        let hasNight = today.noNightMessage == nil
        let rows = hasNight ? today.gridTiles : []
        if !rows.isEmpty || today.restingHRTile != nil {
            // Without a Night, Resting HR belongs to the Day (spec 007), so the heading doesn't
            // name a Night.
            metricsSection(
                today,
                heading: hasNight ? today.tilesHeading : "Resting HR",
                rows: rows,
                note: calibratingLine
            )
        }
    }

    private func metricsSection(
        _ today: TodayView,
        heading: String,
        rows: [TodayTile],
        note: String?
    ) -> some View {
        RuledSection(name: heading, note: note) {
            ForEach(rows) { row in
                switch row {
                case .metric(let tile):
                    metricRow(
                        name: tile.metric.name,
                        value: tile.valueText,
                        tag: zoneTag(tile),
                        detail: tile.zone == nil ? tile.statusText : nil
                    ) { open(.metric(tile.metric), in: today) }
                case .restingHR(let tile):
                    restingHRRow(tile, in: today)
                }
            }
            if today.noNightMessage != nil, let tile = today.restingHRTile {
                restingHRRow(tile, in: today)
            }
        }
    }

    /// A metric's difference from Baseline in its Zone's colour; none without a Zone.
    private func zoneTag(_ tile: MetricTile) -> (text: String, colour: Color)? {
        guard let zone = tile.zone else { return nil }
        return (tile.differenceText, zone.colour)
    }

    /// The Resting HR row, opening its popup (spec 011); it has no Zone, so no tag.
    private func restingHRRow(_ tile: RestingHRTile, in today: TodayView) -> some View {
        metricRow(name: tile.name, value: tile.valueText, tag: nil, detail: tile.statusText) {
            open(.restingHR, in: today)
        }
    }

    /// One metric row: its name, value, and a tag or a secondary detail at the right.
    private func metricRow(
        name: String,
        value: String,
        tag: (text: String, colour: Color)?,
        detail: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            RuledRow {
                HStack(spacing: 12) {
                    Text(name).font(.subheadline).foregroundStyle(Poster.ink)
                    Spacer(minLength: 8)
                    Text(value)
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Poster.ink)
                    if let tag {
                        PosterTag(text: tag.text, colour: tag.colour)
                    } else if let detail, !detail.isEmpty {
                        Text(detail).font(.footnote).foregroundStyle(Poster.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
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

    /// Opens a popup, unless the Today view has nothing for it to show (e.g. the Night's popups
    /// on a Day without a Night).
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

/// Where typical Load sits on the Load bar, which runs from 0 to twice typical Load (spec 006).
private let typicalLoadTick = 0.5
