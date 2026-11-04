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
        let openLane = chosenLane ?? sleep.week.firstOpenLane
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
            if !sleep.standouts.isEmpty {
                standoutsCard(sleep.standouts)
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

    /// What stood out (spec 012): up to three rows about the Night, each a line and a smaller
    /// detail.
    private func standoutsCard(_ standouts: [SleepStandout]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What stood out").font(.headline).padding(.bottom, 4)
            ForEach(Array(standouts.enumerated()), id: \.offset) { index, standout in
                if index > 0 { Divider() }
                VStack(alignment: .leading, spacing: 4) {
                    Text(standout.text).font(.subheadline.weight(.semibold))
                    if !standout.detail.isEmpty {
                        Text(standout.detail).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
            }
        }
        .padding(16)
        .themeCard()
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

    /// One lane: its name, its Night's block on the axis (or "no Night"), and its Time Asleep, in
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
                    axisGridlines(width: width)
                    if let noNight = lane.noNightText {
                        Text(noNight).font(.caption2).foregroundStyle(.secondary)
                    }
                    if let timeInBed = lane.timeInBed {
                        Capsule()
                            .fill(Theme.accentSoft)
                            .frame(
                                width: max(x(timeInBed.end) - x(timeInBed.start), 4),
                                height: laneBlockHeight
                            )
                            .offset(x: x(timeInBed.start))
                    }
                    if let asleep = lane.asleep {
                        // Lighter at Sleep Onset, the accent colour by Final Wake.
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.accentMiddle, Theme.accent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: max(x(asleep.end) - x(asleep.start), 4),
                                height: laneBlockHeight
                            )
                            .offset(x: x(asleep.start))
                    }
                    // Each Wake Bout as an amber notch standing above and below the block.
                    ForEach(lane.wakeNotches, id: \.self) { notch in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(.orange)
                            .frame(
                                width: max(x(notch.end) - x(notch.start), 2.5),
                                height: laneNotchHeight
                            )
                            .offset(x: x(notch.start))
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

    /// Faint lines down a lane at each axis label, across `width`.
    private func axisGridlines(width: CGFloat) -> some View {
        ForEach(week.axisLabels, id: \.text) { label in
            Rectangle()
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 1)
                .offset(x: label.fraction * width)
        }
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
                    axisGridlines(width: width)
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
                SleepChartView(chart: chart)
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

/// A Night's chart (spec 012), one picture: the asleep stretch shaded behind it with its times,
/// Wake Bouts as amber columns, the smoothed Heart Rate Trace as a curve in the accent colour with
/// a fill fading to the chart's foot, and a dotted line at Sleeping HR with its tag; hour ticks
/// under it.
private struct SleepChartView: View {
    let chart: SleepChart

    var body: some View {
        VStack(spacing: 6) {
            Canvas { context, size in
                let width = size.width
                let x = { (time: Date) -> CGFloat in xPosition(time, width: width) }
                // The plot sits under the asleep labels.
                let top = chartLabelRoom
                let y = { (bpm: Double) -> CGFloat in
                    let span = chart.highestBPM - chart.lowestBPM
                    return top + (size.height - top) * (1 - (bpm - chart.lowestBPM) / span)
                }
                let asleep = CGRect(
                    x: x(chart.asleepStart),
                    y: 0,
                    width: max(x(chart.asleepEnd) - x(chart.asleepStart), 4),
                    height: size.height
                )
                context.fill(
                    Path(roundedRect: asleep, cornerRadius: 12),
                    with: .color(Theme.accentSoft.opacity(0.55))
                )
                context.draw(
                    Text(chart.asleepStartText).font(.caption2).foregroundStyle(.secondary),
                    at: CGPoint(x: asleep.minX + 8, y: top / 2 + 2),
                    anchor: .leading
                )
                context.draw(
                    Text(chart.asleepEndText).font(.caption2).foregroundStyle(.secondary),
                    at: CGPoint(x: asleep.maxX - 8, y: top / 2 + 2),
                    anchor: .trailing
                )
                for bout in chart.wakeBouts {
                    // Under the label strip, so a Wake Bout near either end never covers a label.
                    let rect = CGRect(
                        x: x(bout.start),
                        y: top,
                        width: max(x(bout.end) - x(bout.start), 3),
                        height: size.height - top
                    )
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 1.5),
                        with: .color(.orange.opacity(0.22))
                    )
                }
                // Each unbroken run of smoothed values, with a fill fading to the chart's foot.
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
                            Gradient(stops: [
                                .init(color: Theme.accent.opacity(0.45), location: 0),
                                .init(color: Theme.accent.opacity(0), location: 1),
                            ]),
                            startPoint: CGPoint(x: 0, y: top),
                            endPoint: CGPoint(x: 0, y: size.height)
                        )
                    )
                    context.stroke(
                        line,
                        with: .color(Theme.accent),
                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                    )
                }
                if let sleepingHR = chart.sleepingHR {
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y(sleepingHR)))
                    line.addLine(to: CGPoint(x: width, y: y(sleepingHR)))
                    context.stroke(
                        line,
                        with: .color(.primary.opacity(0.45)),
                        style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [1, 4])
                    )
                    if let label = chart.sleepingHRLabel {
                        // A tag on a pill at the line's right end.
                        let text = context.resolve(
                            Text(label).font(.caption2.weight(.bold)).foregroundStyle(.primary)
                        )
                        let textSize = text.measure(in: size)
                        let pill = CGRect(
                            x: width - textSize.width - 14,
                            y: y(sleepingHR) - 9,
                            width: textSize.width + 12,
                            height: 18
                        )
                        context.fill(
                            Path(roundedRect: pill, cornerRadius: 9),
                            with: .color(Theme.card)
                        )
                        context.draw(text, at: CGPoint(x: pill.midX, y: pill.midY))
                    }
                }
            }
            .frame(height: chartHeight)
            ticks
        }
    }

    /// The steps' smoothed values as points, split where a step is missing.
    private func runs(x: (Date) -> CGFloat, y: (Double) -> CGFloat) -> [[CGPoint]] {
        var runs: [[CGPoint]] = []
        var run: [CGPoint] = []
        for step in chart.steps {
            if let bpm = step.smoothedBPM {
                run.append(CGPoint(x: x(step.middle), y: y(bpm)))
            } else if !run.isEmpty {
                runs.append(run)
                run = []
            }
        }
        if !run.isEmpty { runs.append(run) }
        return runs
    }

    /// A smooth curve through `points` that never rises above or dips below the two points it
    /// joins (a monotone cubic, Fritsch–Carlson), so it doesn't invent highs or lows (spec 012).
    private func smoothPath(through points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        let count = points.count
        guard count > 1 else { return path }
        // Each segment's slope, then a tangent at each point: flat at a peak or trough, else the
        // mean of its two segments, cut back where it would overshoot.
        var slopes: [CGFloat] = []
        for index in 0..<(count - 1) {
            let dx = points[index + 1].x - points[index].x
            slopes.append(dx == 0 ? 0 : (points[index + 1].y - points[index].y) / dx)
        }
        var tangents = [CGFloat](repeating: 0, count: count)
        tangents[0] = slopes[0]
        tangents[count - 1] = slopes[count - 2]
        for index in 1..<(count - 1) {
            tangents[index] =
                slopes[index - 1] * slopes[index] <= 0
                ? 0 : (slopes[index - 1] + slopes[index]) / 2
        }
        for index in 0..<(count - 1) where slopes[index] != 0 {
            let a = tangents[index] / slopes[index]
            let b = tangents[index + 1] / slopes[index]
            let length = a * a + b * b
            if length > 9 {
                let scale = 3 / length.squareRoot()
                tangents[index] = scale * a * slopes[index]
                tangents[index + 1] = scale * b * slopes[index]
            }
        }
        for index in 0..<(count - 1) {
            let p0 = points[index]
            let p1 = points[index + 1]
            let third = (p1.x - p0.x) / 3
            path.addCurve(
                to: p1,
                control1: CGPoint(x: p0.x + third, y: p0.y + tangents[index] * third),
                control2: CGPoint(x: p1.x - third, y: p1.y - tangents[index + 1] * third)
            )
        }
        return path
    }

    /// The hour ticks under the chart, at their clock positions.
    private var ticks: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
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
/// The height of a lane's block, points.
private let laneBlockHeight: CGFloat = 12
/// The height of a Wake Bout notch, standing 3 points above and below the block, points.
private let laneNotchHeight: CGFloat = 18
private let axisLabelHeight: CGFloat = 14
/// The height of a Night's chart, points.
private let chartHeight: CGFloat = 170
/// The room at the top of a Night's chart for the asleep labels, above the plot, points.
private let chartLabelRoom: CGFloat = 18
