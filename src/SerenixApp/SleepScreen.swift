import SerenixCore
import SwiftUI

/// The Sleep tab (spec 012): draws the Sleep view for the Day shown, inside the same top bar and
/// sync pill as the Today tab.
struct SleepScreen: View {
    @ObservedObject var connection: StrapConnection
    @ObservedObject var profile: ProfileStore
    /// The Day shown, shared with the Today tab; nil is today.
    @Binding var pickedDay: Day?
    /// The sync pill swiped away, shared with the other tab so there is one pill.
    @Binding var dismissedPill: SyncPill?
    @State private var showsProfileMenu = false
    /// The Day whose Night's Sleep popup is open; nil when none is.
    @State private var sleepPopupDay: Day?
    /// The lane the user opened, `.some(nil)` when they closed it; nil until they tap one, and
    /// cleared when the Day shown changes, so the Sleep view's first open lane opens again.
    @State private var chosenLane: Day??
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
        let openLane: Day? =
            if let chosen = chosenLane {
                chosen
            } else {
                sleep.week.firstOpenLane
            }
        ScreenChrome(
            connection: connection,
            profile: profile,
            pickedDay: $pickedDay,
            showsProfileMenu: $showsProfileMenu,
            dismissedPill: $dismissedPill,
            today: today
        ) {
            WeekStripView(strip: sleep.weekStrip) { pickedDay = shownSelection($0) }
            if let summary = sleep.summary {
                summaryCard(summary) { sleepPopupDay = shownDay }
            } else if let message = sleep.noNightMessage {
                Text(message)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            SleepWeekView(
                week: sleep.week,
                tonightLane: sleep.tonight?.lane,
                openLane: openLane,
                toggle: { day in chosenLane = .some(openLane == day ? nil : day) },
                showSleepScore: { sleepPopupDay = $0 }
            )
            if let tonight = sleep.tonight {
                tonightCard(tonight)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { sleepPopupDay != nil },
                set: { if !$0 { sleepPopupDay = nil } }
            )
        ) {
            if let day = sleepPopupDay {
                TodayPopupView(
                    popup: .sleep,
                    today: TodayView(
                        connection: connection,
                        profile: profile,
                        showing: day,
                        now: now
                    ),
                    connection: connection
                )
            }
        }
        // Another Day shown opens its own first lane (spec 012, Opening a lane).
        .onChange(of: shownDay) { chosenLane = nil }
        // Back from the background, the tabs show today (spec 002); the popup described the Day
        // being left, so it closes, as on the Today tab.
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if oldPhase == .background, newPhase != .background { sleepPopupDay = nil }
        }
    }

    /// Tonight (spec 012): one sentence on when to be asleep, on a card in the accent colour.
    private func tonightCard(_ tonight: SleepTonight) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tonight").font(.footnote).opacity(0.85)
            Text(tonight.sentence)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            LinearGradient(
                colors: [Theme.accent, Theme.accentMiddle],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: Theme.cardRadius)
        )
    }

    /// The Summary (spec 012): the Night in one sentence, then the Sleep Score button and Sleep
    /// Onset to Final Wake.
    private func summaryCard(_ summary: SleepSummary, showSleepScore: @escaping () -> Void)
        -> some View
    {
        VStack(alignment: .leading, spacing: 8) {
            Text(summary.label).font(.footnote).foregroundStyle(.secondary)
            Text(summary.sentence)
                .font(.title3.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                SleepScoreButton(action: showSleepScore)
                Spacer()
                if let onsetWake = summary.onsetWakeText {
                    Text(onsetWake).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .themeCard()
    }
}

/// "Sleep Score ›", opening the Sleep popup.
private struct SleepScoreButton: View {
    let action: () -> Void

    var body: some View {
        Button("Sleep Score \u{203A}", action: action)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.accentSoft, in: Capsule())
            .buttonStyle(.plain)
            .foregroundStyle(Theme.accent)
    }
}

/// Your week (spec 012): a lane for each of the 7 Days, the Day shown first, each Night's bar on
/// one evening-to-morning axis with faint hour lines, broken at its Wake Bouts. Tapping a lane
/// opens its Night's chart under it and closes any other.
private struct SleepWeekView: View {
    let week: SleepWeek
    /// Tonight's dashed lane, first; nil when the Day shown isn't today or there's no bedtime.
    let tonightLane: SleepTonightLane?
    /// The lane whose chart is open; nil when none is.
    let openLane: Day?
    let toggle: (Day) -> Void
    let showSleepScore: (Day) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(week.titleText).font(.headline)
                Spacer()
                if let summary = week.summaryText {
                    Text(summary).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 8)
            if let tonightLane {
                tonightRow(tonightLane)
                Divider()
            }
            ForEach(week.lanes, id: \.day) { lane in
                laneRow(lane)
                if lane.day == openLane, lane.noNightText == nil {
                    openPanel(lane)
                }
                if lane.day != week.lanes.last?.day { Divider() }
            }
            HStack(spacing: laneSpacing) {
                Color.clear.frame(width: laneNameWidth, height: 1)
                GeometryReader { geometry in
                    ForEach(week.axisLabels, id: \.text) { label in
                        Text(label.text)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize()
                            .position(
                                x: label.fraction * geometry.size.width,
                                y: axisLabelHeight / 2
                            )
                    }
                }
                .frame(height: axisLabelHeight)
                Color.clear.frame(width: laneValueWidth, height: 1)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .themeCard()
    }

    /// One lane: its name, its Night's bar on the axis (or "no Night"), and its Time Asleep, in
    /// amber when short of its Sleep Need. A Night's lane opens and closes on tap.
    private func laneRow(_ lane: SleepLane) -> some View {
        HStack(spacing: laneSpacing) {
            Text(lane.name)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(lane.day == openLane ? Theme.accent : Color.primary)
                .frame(width: laneNameWidth, alignment: .leading)
            GeometryReader { geometry in
                let width = geometry.size.width
                let x = { (time: Date) -> CGFloat in week.axisFraction(of: time) * width }
                ZStack(alignment: .leading) {
                    ForEach(week.axisLabels, id: \.text) { label in
                        Rectangle()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(width: 1)
                            .offset(x: label.fraction * width)
                    }
                    if let noNight = lane.noNightText {
                        Text(noNight).font(.caption2).foregroundStyle(.secondary)
                    }
                    if let timeInBed = lane.timeInBed {
                        Capsule()
                            .fill(Theme.accentSoft)
                            .frame(width: max(x(timeInBed.end) - x(timeInBed.start), 4), height: 4)
                            .offset(x: x(timeInBed.start))
                    }
                    ForEach(lane.asleepSegments, id: \.start) { segment in
                        Capsule()
                            .fill(Theme.accent)
                            .frame(width: max(x(segment.end) - x(segment.start), 3), height: 12)
                            .offset(x: x(segment.start))
                    }
                    // A thin amber mark in each gap the Wake Bouts leave.
                    ForEach(
                        Array(zip(lane.asleepSegments, lane.asleepSegments.dropFirst())),
                        id: \.0.start
                    ) { pair in
                        Capsule()
                            .fill(.orange)
                            .frame(width: max(x(pair.1.start) - x(pair.0.end), 2), height: 3)
                            .offset(x: x(pair.0.end))
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: laneBarHeight)
            Text(lane.timeAsleepText ?? "")
                .font(.footnote.weight(.semibold).monospacedDigit())
                .foregroundStyle(lane.isShort ? Color.orange : Color.primary)
                .frame(width: laneValueWidth, alignment: .trailing)
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .onTapGesture { if lane.noNightText == nil { toggle(lane.day) } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(lane.name): \(lane.noNightText ?? lane.timeAsleepText ?? "")\(lane.isShort ? ", short" : "")"
        )
        .accessibilityAddTraits(lane.noNightText == nil ? .isButton : [])
        .accessibilityValue(lane.day == openLane ? "Open" : "")
        .accessibilityAction { if lane.noNightText == nil { toggle(lane.day) } }
    }

    /// Tonight's lane: a dashed bar from Be asleep by to the usual wake, the time at its right.
    private func tonightRow(_ lane: SleepTonightLane) -> some View {
        HStack(spacing: laneSpacing) {
            Text("Tonight")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: laneNameWidth, alignment: .leading)
            GeometryReader { geometry in
                let width = geometry.size.width
                let start = week.axisFraction(of: lane.start) * width
                let end = week.axisFraction(of: lane.end) * width
                ZStack(alignment: .leading) {
                    ForEach(week.axisLabels, id: \.text) { label in
                        Rectangle()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(width: 1)
                            .offset(x: label.fraction * width)
                    }
                    Capsule()
                        .fill(Theme.accentSoft)
                        .overlay(
                            Capsule().strokeBorder(
                                Theme.accent,
                                style: StrokeStyle(lineWidth: 1.2, dash: [3, 3])
                            )
                        )
                        .frame(width: max(end - start, 4), height: 12)
                        .offset(x: start)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: laneBarHeight)
            Text(lane.text)
                .font(.footnote.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.accent)
                .frame(width: laneValueWidth, alignment: .trailing)
        }
        .padding(.vertical, 7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tonight: be asleep by \(lane.text)")
    }

    /// Under an open lane: its Night's chart (or the not-kept note), then how often it woke and
    /// the Sleep Score button.
    private func openPanel(_ lane: SleepLane) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let chart = lane.chart {
                SleepChartView(chart: chart, asleepSegments: lane.asleepSegments)
            } else if let notKept = lane.notKeptText {
                Text(notKept)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .multilineTextAlignment(.center)
            }
            HStack {
                if let woke = lane.wakeText {
                    Text(woke).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                SleepScoreButton { showSleepScore(lane.day) }
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 12)
    }
}

/// A Night's chart (spec 012): the Heart Rate Trace as a smooth line with a soft fill, broken at
/// missing steps, over faint bpm gridlines labelled at the right, Wake Bouts shaded behind it and
/// a dotted line at Sleeping HR; under it the sleep/wake band and hour ticks.
private struct SleepChartView: View {
    let chart: SleepChart
    /// The bar's asleep stretches, Sleep Onset to Final Wake broken at each Wake Bout.
    let asleepSegments: [DateInterval]

    var body: some View {
        VStack(spacing: 6) {
            Canvas { context, size in
                let plotWidth = size.width - chartLabelGutter
                let x = { (time: Date) -> CGFloat in xPosition(time, width: plotWidth) }
                let y = { (bpm: Double) -> CGFloat in
                    let span = chart.highestBPM - chart.lowestBPM
                    return size.height * (1 - (bpm - chart.lowestBPM) / span)
                }
                for bpm in chart.gridlines {
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y(bpm)))
                    line.addLine(to: CGPoint(x: plotWidth, y: y(bpm)))
                    context.stroke(line, with: .color(.secondary.opacity(0.15)), lineWidth: 1)
                    context.draw(
                        Text("\(Int(bpm))").font(.caption2).foregroundStyle(.secondary),
                        at: CGPoint(x: size.width, y: y(bpm)),
                        anchor: .trailing
                    )
                }
                for bout in chart.wakeBouts {
                    let rect = CGRect(
                        x: x(bout.start),
                        y: 0,
                        width: max(x(bout.end) - x(bout.start), 3),
                        height: size.height
                    )
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 2),
                        with: .color(.orange.opacity(0.16))
                    )
                }
                // Each unbroken run of steps, smoothed, with a soft fill down to the chart's foot.
                for run in runs(x: x, y: y) {
                    let line = smoothPath(through: run)
                    var area = line
                    if let first = run.first, let last = run.last {
                        area.addLine(to: CGPoint(x: last.x, y: size.height))
                        area.addLine(to: CGPoint(x: first.x, y: size.height))
                        area.closeSubpath()
                    }
                    context.fill(
                        area,
                        with: .linearGradient(
                            Gradient(colors: [.red.opacity(0.28), .red.opacity(0)]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: 0, y: size.height)
                        )
                    )
                    context.stroke(
                        line,
                        with: .color(.red),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                }
                if let sleepingHR = chart.sleepingHR {
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y(sleepingHR)))
                    line.addLine(to: CGPoint(x: plotWidth, y: y(sleepingHR)))
                    context.stroke(
                        line,
                        with: .color(.primary.opacity(0.45)),
                        style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2, 4])
                    )
                    if let label = chart.sleepingHRLabel {
                        // Under its right end, where the trace has risen above it toward waking.
                        context.draw(
                            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(
                                .secondary
                            ),
                            at: CGPoint(x: plotWidth - 4, y: y(sleepingHR) + 9),
                            anchor: .trailing
                        )
                    }
                }
            }
            .frame(height: chartHeight)
            band
            ticks
        }
    }

    /// The steps as points, split where a step is missing.
    private func runs(x: (Date) -> CGFloat, y: (Double) -> CGFloat) -> [[CGPoint]] {
        var runs: [[CGPoint]] = []
        var run: [CGPoint] = []
        for step in chart.steps {
            if let bpm = step.bpm {
                run.append(CGPoint(x: x(step.middle), y: y(bpm)))
            } else if !run.isEmpty {
                runs.append(run)
                run = []
            }
        }
        if !run.isEmpty { runs.append(run) }
        return runs
    }

    /// A smooth line through `points` (Catmull-Rom as cubic Béziers), so 5-minute steps don't
    /// read as a jagged line.
    private func smoothPath(through points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count > 1 else { return path }
        for index in 0..<(points.count - 1) {
            let p0 = points[max(index - 1, 0)]
            let p1 = points[index]
            let p2 = points[index + 1]
            let p3 = points[min(index + 2, points.count - 1)]
            path.addCurve(
                to: p2,
                control1: CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6),
                control2: CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            )
        }
        return path
    }

    /// Time in Bed as a track, Sleep Onset to Final Wake in the accent colour with a gap and an
    /// amber mark at each Wake Bout.
    private var band: some View {
        GeometryReader { geometry in
            let width = geometry.size.width - chartLabelGutter
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.accentSoft).frame(width: width)
                ForEach(asleepSegments, id: \.start) { segment in
                    Capsule()
                        .fill(Theme.accent)
                        .frame(
                            width: max(
                                xPosition(segment.end, width: width)
                                    - xPosition(segment.start, width: width),
                                3
                            )
                        )
                        .offset(x: xPosition(segment.start, width: width))
                }
                ForEach(chart.wakeBouts, id: \.start) { bout in
                    Capsule()
                        .fill(.orange)
                        .frame(
                            width: max(
                                xPosition(bout.end, width: width)
                                    - xPosition(bout.start, width: width),
                                2
                            ),
                            height: 3
                        )
                        .offset(x: xPosition(bout.start, width: width))
                }
            }
        }
        .frame(height: bandHeight)
    }

    /// The hour ticks under the band, at their clock positions.
    private var ticks: some View {
        GeometryReader { geometry in
            let width = geometry.size.width - chartLabelGutter
            ForEach(chart.hourTicks, id: \.time) { tick in
                Text(tick.text)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .position(x: xPosition(tick.time, width: width), y: axisLabelHeight / 2)
            }
        }
        .frame(height: axisLabelHeight)
    }

    /// Where `time` falls across `width`, from the chart's start to its end.
    private func xPosition(_ time: Date, width: CGFloat) -> CGFloat {
        let span = chart.end.timeIntervalSince(chart.start)
        guard span > 0 else { return 0 }
        return width * time.timeIntervalSince(chart.start) / span
    }
}

/// Your week's lane columns: the name's and the Time Asleep's widths, and the gap between
/// columns, points.
private let laneNameWidth: CGFloat = 40
private let laneValueWidth: CGFloat = 52
private let laneSpacing: CGFloat = 6
/// The height of a lane's bar area and of a row of axis labels or hour ticks, points.
private let laneBarHeight: CGFloat = 18
private let axisLabelHeight: CGFloat = 14
/// A Night's chart: its height, the room at its right for bpm labels, and its band's height,
/// points.
private let chartHeight: CGFloat = 150
private let chartLabelGutter: CGFloat = 26
private let bandHeight: CGFloat = 10
