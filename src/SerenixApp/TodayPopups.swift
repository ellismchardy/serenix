import Charts
import SerenixCore
import SwiftUI

/// Which popup is open over the Today screen (spec 002, Popups).
enum TodayPopup: Identifiable, Hashable {
    case readiness
    case sleep
    case metric(NightlyMetric)
    case load

    var id: Self { self }
}

/// The open popup's content, drawn from the Today view. Each slides up and closes on a tap
/// outside or a swipe down.
struct TodayPopupView: View {
    let popup: TodayPopup
    let today: TodayView
    /// For the Live HR pill on today's Load popup, which observes it; the popup itself doesn't,
    /// so it isn't redrawn on every sync tick.
    let connection: StrapConnection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch popup {
                case .readiness:
                    if let readiness = today.readinessPopup { ReadinessPopupView(popup: readiness) }
                case .sleep:
                    if let sleep = today.sleepPopup { SleepPopupView(popup: sleep) }
                case .metric(let metric):
                    if let content = today.metricPopup(metric) { MetricPopupView(popup: content) }
                case .load:
                    if let load = today.loadPopup {
                        LoadPopupView(popup: load, connection: connection)
                    }
                }
            }
            .padding()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct ReadinessPopupView: View {
    let popup: ReadinessPopup

    var body: some View {
        Text("Readiness").font(.headline)
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(popup.readinessText).font(.largeTitle.bold()).monospacedDigit()
            if let band = popup.band {
                Text(band.word).font(.title3.bold()).foregroundStyle(band.colour)
            }
        }
        if let calibrating = popup.calibratingText {
            Text(calibrating).foregroundStyle(.secondary)
        }
        if !popup.rows.isEmpty { rows }
        if let sleepScore = popup.sleepScoreText {
            LabeledContent("Sleep Score", value: sleepScore)
        }
        if let note = popup.baselineNote {
            Text(note).font(.footnote).foregroundStyle(.secondary)
        }
    }

    /// Readiness's inputs: last night, what it's measured against, and the difference.
    private var rows: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                Text("")
                Text("Value").foregroundStyle(.secondary)
                Text("Against").foregroundStyle(.secondary)
                Text("")
            }
            .font(.footnote)
            ForEach(popup.rows, id: \.name) { row in
                GridRow {
                    Text(row.name)
                    Text(row.valueText).monospacedDigit()
                    Text(row.referenceText).monospacedDigit()
                    Text(row.differenceText).monospacedDigit()
                }
            }
        }
    }
}

private struct SleepPopupView: View {
    let popup: SleepPopup

    var body: some View {
        Text("Sleep").font(.headline)
        // Three cards (spec 010, Sleep popup): Sleep Score, When you slept, How much you slept.
        VStack(alignment: .leading, spacing: 12) {
            LabeledContent("Sleep Score", value: popup.sleepScoreText)
            // Sleep Score's parts as three small rings, each with what it came from.
            HStack(alignment: .top) {
                ForEach(popup.parts, id: \.name) { part in
                    VStack(spacing: 4) {
                        ScoreRing(
                            text: part.scoreText,
                            fill: part.fill,
                            label: part.name,
                            diameter: 64
                        )
                        Text(part.detailText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .sleepCard()
        whenYouSlept.sleepCard()
        howMuchYouSlept.sleepCard()
    }

    /// Time Asleep as a bar with a marker at Sleep Need, then Sleep Debt (spec 010).
    private var howMuchYouSlept: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How much you slept").font(.subheadline.bold())
            SleepNeedBarView(bar: popup.sleepNeedBar).frame(height: 22)
            HStack {
                Text(popup.sleepNeedBar.asleepText).monospacedDigit()
                Spacer()
                Text(popup.sleepNeedBar.neededText).monospacedDigit().foregroundStyle(.secondary)
            }
            .font(.subheadline)
            LabeledContent("Sleep Debt") {
                VStack(alignment: .trailing) {
                    Text(popup.sleepDebtText)
                    Text(popup.sleepDebtCaption).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }

    /// The Night's Sleep Period on its timeline, with Sleep Consistency's detail in the heading
    /// and Time in Bed, minutes awake and Sleep Efficiency's detail in the caption.
    private var whenYouSlept: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("When you slept").font(.subheadline.bold())
                Text("· \(detail(of: "Sleep Consistency"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let timeline = popup.timeline {
                SleepTimelineView(timeline: timeline).frame(height: 96)
            } else {
                Text("No Sleep Period for this Night").foregroundStyle(.secondary)
            }
            Text(
                "Time in Bed \(popup.timeInBedText) (\(popup.timeInBedDurationText)) · "
                    + "Awake in the night \(popup.minutesAwakeText) · "
                    + detail(of: "Sleep Efficiency")
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    /// The detail of Sleep Score's part named `name`, e.g. "Sleep Consistency".
    private func detail(of name: String) -> String {
        popup.parts.first { $0.name == name }?.detailText ?? "—"
    }
}

/// The Sleep popup's timeline (spec 010): the Sleep Period as an accent bar between its labelled
/// ends, over the hour labels. Every position comes from `SleepTimeline`.
private struct SleepTimelineView: View {
    let timeline: SleepTimeline

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let periodWidth: CGFloat =
                (timeline.finalWake.position - timeline.sleepOnset.position) * width
            ZStack(alignment: .topLeading) {
                // Time in Bed as a light band behind the Sleep Period.
                if let bed = timeline.timeInBed {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.accentSoft)
                        .frame(width: (bed.end - bed.start) * width, height: 30)
                        .offset(x: bed.start * width, y: 25)
                }
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.accent)
                    .frame(width: max(periodWidth, 2), height: 20)
                    .offset(x: timeline.sleepOnset.position * width, y: 30)
                endLabel(timeline.sleepOnset, width: width)
                endLabel(timeline.finalWake, width: width)
                if let usual = timeline.usualSleepOnset { usualLine(usual, width: width) }
                if let usual = timeline.usualFinalWake { usualLine(usual, width: width) }
                ForEach(timeline.hours, id: \.position) { hour in
                    Text(hour.text)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        .position(x: hour.position * width, y: 86)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    /// The Sleep Period, and the usual times when they're drawn.
    private var accessibilityText: String {
        var text = "Asleep from \(timeline.sleepOnset.text) to \(timeline.finalWake.text)"
        if let onset = timeline.usualSleepOnset, let wake = timeline.usualFinalWake {
            text += ", usually \(onset.text) to \(wake.text)"
        }
        return text
    }

    /// A usual Sleep Onset or Final Wake: a dashed line across the bar, labelled "usual" and its
    /// clock time above it.
    private func usualLine(_ mark: TimelineMark, width: CGFloat) -> some View {
        let x = mark.position * width
        return ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: x, y: 20))
                // Just below the bar (y 30–50), clear of the end labels at y 60.
                path.addLine(to: CGPoint(x: x, y: 52))
            }
            .stroke(.secondary, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            Text("usual \(mark.text)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize()
                .position(x: x, y: 10)
        }
    }

    /// Sleep Onset's or Final Wake's clock time under its end of the bar.
    private func endLabel(_ mark: TimelineMark, width: CGFloat) -> some View {
        Text(mark.text)
            .font(.caption2.bold())
            .monospacedDigit()
            .fixedSize()
            .position(x: mark.position * width, y: 60)
    }
}

/// The Sleep Need bar (spec 010): Time Asleep filled in the accent colour, with a marker at Sleep
/// Need. Fill and marker come from `SleepNeedBar`.
private struct SleepNeedBarView: View {
    let bar: SleepNeedBar

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let markerX: CGFloat = max(0, min(bar.marker * width, width - 2))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6).fill(Theme.accentSoft)
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.accent)
                    .frame(width: bar.fill * width)
                Rectangle()
                    .fill(.primary)
                    .frame(width: 2, height: geometry.size.height + 8)
                    .offset(x: markerX)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(bar.asleepText), \(bar.neededText)")
    }
}

extension View {
    /// One of the Sleep popup's cards.
    fileprivate func sleepCard() -> some View {
        padding(16).frame(maxWidth: .infinity, alignment: .leading).themeCard()
    }
}

private struct MetricPopupView: View {
    let popup: MetricPopup

    var body: some View {
        Text(popup.metric.name).font(.headline)
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(popup.valueText).font(.largeTitle.bold()).monospacedDigit()
            Text(popup.differenceText).font(.title3)
        }
        .foregroundStyle(popup.zone?.colour ?? .primary)
        chart.frame(height: 180)
        ForEach(popup.recent, id: \.dayText) { entry in
            LabeledContent(entry.dayText, value: entry.valueText)
        }
    }

    /// The values over the last 14 Nights, with the Baseline and its In range band.
    private var chart: some View {
        Chart {
            if let baseline = popup.baseline, let band = inRangeBand {
                RectangleMark(yStart: .value("Low", band.low), yEnd: .value("High", band.high))
                    .foregroundStyle(.green.opacity(0.15))
                RuleMark(y: .value("Baseline", baseline))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(dash: [4, 4]))
            }
            ForEach(Array(popup.chart.enumerated()), id: \.element.day) { index, point in
                LineMark(x: .value("Night", index), y: .value("Value", point.value))
                PointMark(x: .value("Night", index), y: .value("Value", point.value))
            }
        }
        .chartXAxis(.hidden)
    }

    /// The In range band, with an open side drawn to the edge of the chart's values.
    private var inRangeBand: (low: Double, high: Double)? {
        guard popup.inRangeLow != nil || popup.inRangeHigh != nil else { return nil }
        let values = popup.chart.map(\.value) + [popup.baseline].compactMap { $0 }
        guard let lowest = values.min(), let highest = values.max() else { return nil }
        // An open side reaches past every value but never crosses the other limit, so the band
        // can't flip onto the out-of-range part.
        let low = popup.inRangeLow ?? min(lowest, popup.inRangeHigh ?? lowest)
        let high = popup.inRangeHigh ?? max(highest, popup.inRangeLow ?? highest)
        return (low, high)
    }
}

/// The Load popup (spec 006): the Day's Load against typical Load, its time in each HR Zone, hour
/// by hour, its Highest HR and the Max HR used, with the Live HR pill at the top left on today.
private struct LoadPopupView: View {
    let popup: LoadPopup
    let connection: StrapConnection

    var body: some View {
        if popup.showsLiveHR { LiveHRPillView(connection: connection) }
        Text("Load").font(.headline)
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(popup.loadText).font(.largeTitle.bold()).monospacedDigit()
            Text(popup.dateText).foregroundStyle(.secondary)
        }
        if let lastSync = popup.lastSyncText {
            Text(lastSync).font(.footnote).foregroundStyle(.secondary)
        }
        Text(popup.typicalText)
        if let note = popup.note {
            Text(note).foregroundStyle(.secondary)
        } else {
            Text("Heart rate zones").font(.headline)
            ForEach(popup.zoneRows, id: \.zone) { row in
                VStack(alignment: .leading, spacing: 4) {
                    LabeledContent(row.label) { Text(row.timeText).monospacedDigit() }
                    ProgressView(value: row.share).tint(row.zone.colour)
                }
            }
            hourlyBars.frame(height: 160)
            if let highest = popup.highestHRText { Text(highest) }
            if let maxHR = popup.maxHRText {
                Text(maxHR).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    /// Minutes in each HR Zone, hour by hour from local midnight, stacked HR Zone 1 at the
    /// bottom, on a 0–60 minute scale.
    private var hourlyBars: some View {
        Chart {
            ForEach(Array(popup.hourlyZoneSeconds.enumerated()), id: \.offset) { hour, seconds in
                ForEach(HRZone.allCases, id: \.self) { zone in
                    BarMark(
                        x: .value("Hour", hour),
                        y: .value("Minutes", Double(seconds[zone] ?? 0) / 60)
                    )
                    .foregroundStyle(zone.colour)
                }
            }
        }
        .chartYScale(domain: 0...60)
        // Half an hour either side, so the first and last bars aren't cut in half.
        .chartXScale(domain: -0.5...(Double(popup.hourlyZoneSeconds.count) - 0.5))
        // Bars count hours from local midnight, so clock labels would be an hour out after a
        // clock change.
        .chartXAxis(.hidden)
        .accessibilityLabel("Minutes in each heart rate zone, hour by hour")
    }
}

extension HRZone {
    /// Cool to hot, HR Zone 1 to 5; no yellow, which is hard to see on the light background.
    var colour: Color {
        switch self {
        case .one: .blue
        case .two: .teal
        case .three: .green
        case .four: .orange
        case .five: .red
        }
    }
}

/// The Live HR pill (spec 006): a heart and the bpm, "…" while connecting, a grey "—" when
/// there's nothing to show. Live HR runs while it's on screen; it's worked out again every
/// second, so a reading going stale shows.
private struct LiveHRPillView: View {
    @ObservedObject var connection: StrapConnection

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let pill = connection.liveHRPill(at: context.date)
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(pill == .unavailable ? Color.secondary : Color.red)
                    .symbolEffect(.pulse, isActive: pill == .connecting)
                Text(pill.text).monospacedDigit()
            }
            .font(.subheadline.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .themeCard(Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Live heart rate \(pill.text)")
        }
        .onAppear { connection.setLiveHRShown(true) }
        .onDisappear { connection.setLiveHRShown(false) }
    }
}
