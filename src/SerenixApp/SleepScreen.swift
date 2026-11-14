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
    /// The lane the user opened; nil when none is, and cleared when the Day shown changes. No
    /// lane opens by itself: the shown Night's chart has its own section (spec 018, Sleep).
    @State private var openLane: Day?
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
        ScreenChrome(
            tabName: "Sleep",
            connection: connection,
            profile: profile,
            pickedDay: $pickedDay,
            showsProfileMenu: $showsProfileMenu,
            dismissedPill: $dismissedPill,
            today: today
        ) {
            WeekStripView(strip: sleep.weekStrip) { pickedDay = shownSelection($0) }
            sleepHeadline(sleep, today: today) { sleepPopupDay = shownDay }
            // Spec 018's order: the Night's chart, Your week, What stood out, Tonight.
            if let day = sleep.week.firstOpenLane,
                let lane = sleep.week.lanes.first(where: { $0.day == day }),
                let summary = sleep.summary
            {
                nightChartSection(lane, label: summary.label)
            }
            SleepWeekView(
                week: sleep.week,
                tonightLane: sleep.tonight?.lane,
                openLane: openLane,
                toggle: { day in openLane = openLane == day ? nil : day },
                showSleepScore: { sleepPopupDay = $0 }
            )
            if !sleep.standouts.isEmpty {
                standoutsSection(sleep.standouts)
            }
            if let tonight = sleep.tonight {
                tonightBlock(tonight)
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
        // Another Day shown closes any lane opened on the last one.
        .onChange(of: shownDay) { openLane = nil }
        // Back from the background, the tabs show today (spec 002); the popup described the Day
        // being left, so it closes, as on the Today tab.
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if oldPhase == .background, newPhase != .background { sleepPopupDay = nil }
        }
    }

    /// The Night dated the Day shown, as its own section (spec 018, Sleep): its chart (or the
    /// not-kept note), how often it woke as the note.
    private func nightChartSection(_ lane: SleepLane, label: String) -> some View {
        RuledSection(name: label, note: lane.wakeText) {
            NightChartBody(lane: lane)
        }
    }

    /// Tonight (spec 012): one sentence on when to be asleep, as a solid block in the type colour
    /// with the paper colour as text (spec 018, Sleep).
    private func tonightBlock(_ tonight: SleepTonight) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TONIGHT").font(Poster.labelFont)
            Text(tonight.sentence)
                .font(.title3.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Poster.paper)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Poster.ink)
    }

    /// What stood out (spec 012): up to three hairline rows about the Night, each a line and a
    /// smaller detail.
    private func standoutsSection(_ standouts: [SleepStandout]) -> some View {
        RuledSection(name: "What stood out") {
            ForEach(Array(standouts.enumerated()), id: \.offset) { _, standout in
                RuledRow {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(standout.text)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Poster.ink)
                        if !standout.detail.isEmpty {
                            Text(standout.detail)
                                .font(.footnote)
                                .foregroundStyle(Poster.secondary)
                        }
                    }
                }
            }
        }
    }

    /// The Sleep Score headline with its verdict, captioned by spec 012's Summary sentence (or the
    /// no-Night message), opening the Sleep popup; then Time Asleep, Sleep Need and Sleep Debt in
    /// three columns, Sleep Debt in red when over zero, and Sleep Onset to Final Wake (spec 018,
    /// Sleep).
    private func sleepHeadline(
        _ sleep: SleepView,
        today: TodayView,
        showSleepScore: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Button(action: showSleepScore) {
                PosterHeadline(
                    number: sleep.sleepScoreText,
                    verdict: sleep.sleepScoreVerdict,
                    caption: sleep.summary.map { "\($0.label): \($0.sentence)" }
                        ?? sleep.noNightMessage
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(sleep.summary == nil)
            .accessibilityHint(sleep.summary == nil ? "" : "Shows your Sleep Score")
            if let popup = today.sleepPopup {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 12) {
                        sleepColumn("Time Asleep", popup.timeAsleepText, colour: Poster.ink)
                        sleepColumn("Sleep Need", popup.sleepNeedText, colour: Poster.ink)
                        sleepColumn(
                            "Sleep Debt",
                            popup.sleepDebtText,
                            colour: sleep.hasSleepDebt ? Poster.red : Poster.ink
                        )
                    }
                    if let onsetWake = sleep.summary?.onsetWakeText {
                        Text(onsetWake).font(.footnote).foregroundStyle(Poster.secondary)
                    }
                }
            }
        }
    }

    /// One of the three columns under a heavy rule: its name, then its value.
    private func sleepColumn(_ name: String, _ value: String, colour: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            PosterRule()
            Text(name.uppercased()).font(Poster.labelFont).foregroundStyle(Poster.ink)
            Text(value)
                .font(Poster.headlineFont(size: 26))
                // -0.04 em, as the prototype's three columns.
                .tracking(-1)
                .foregroundStyle(colour)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// "SLEEP SCORE ›" in bold ink, opening the Sleep popup.
private struct SleepScoreButton: View {
    let action: () -> Void

    var body: some View {
        Button("SLEEP SCORE \u{203A}", action: action)
            .font(Poster.labelFont)
            .buttonStyle(.plain)
            .foregroundStyle(Poster.ink)
            .accessibilityLabel("Sleep Score")
    }
}

/// Your week (spec 012) as a ruled section (spec 018): a lane for each of the 7 Days, the Day
/// shown first, each Night as one solid bar with amber Wake Bout notches on one
/// evening-to-morning axis with hairline hours. Tapping a lane opens its Night's chart under it
/// and closes any other.
private struct SleepWeekView: View {
    let week: SleepWeek
    /// Tonight's dashed lane, first; nil when the Day shown isn't today or there's no bedtime.
    let tonightLane: SleepTonightLane?
    /// The lane whose chart is open; nil when none is.
    let openLane: Day?
    let toggle: (Day) -> Void
    let showSleepScore: (Day) -> Void

    var body: some View {
        RuledSection(name: week.titleText, note: week.summaryText) {
            VStack(alignment: .leading, spacing: 0) {
                lanes
                axisLabels
            }
        }
    }

    @ViewBuilder
    private var lanes: some View {
        if let tonightLane {
            tonightRow(tonightLane)
            hairline
        }
        ForEach(week.lanes, id: \.day) { lane in
            laneRow(lane)
            if lane.day == openLane, lane.noNightText == nil {
                openPanel(lane)
            }
            if lane.day != week.lanes.last?.day { hairline }
        }
    }

    private var hairline: some View {
        PosterRule(width: Poster.rowRule, colour: Poster.hairline)
    }

    private var axisLabels: some View {
        HStack(spacing: laneSpacing) {
            Color.clear.frame(width: laneNameWidth, height: 1)
            GeometryReader { geometry in
                ForEach(week.axisLabels, id: \.text) { label in
                    Text(label.text)
                        .font(.caption2)
                        .foregroundStyle(Poster.secondary)
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

    /// One lane: its name, its Night's block on the axis (or "no Night"), and its Time Asleep, in
    /// amber when short of its Sleep Need. A Night's lane opens and closes on tap.
    private func laneRow(_ lane: SleepLane) -> some View {
        HStack(spacing: laneSpacing) {
            Text(lane.name)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(lane.day == openLane ? Poster.red : Poster.ink)
                .frame(width: laneNameWidth, alignment: .leading)
            GeometryReader { geometry in
                let width = geometry.size.width
                let x = { (time: Date) -> CGFloat in week.axisFraction(of: time) * width }
                ZStack(alignment: .leading) {
                    axisGridlines(width: width)
                    if let noNight = lane.noNightText {
                        Text(noNight).font(.caption2).foregroundStyle(Poster.secondary)
                    }
                    if let timeInBed = lane.timeInBed {
                        Rectangle()
                            .fill(Poster.track)
                            .frame(
                                width: max(x(timeInBed.end) - x(timeInBed.start), 4),
                                height: laneBlockHeight
                            )
                            .offset(x: x(timeInBed.start))
                    }
                    if let asleep = lane.asleep {
                        // Each Night a solid bar in the type colour (spec 018, Sleep).
                        Rectangle()
                            .fill(Poster.ink)
                            .frame(
                                width: max(x(asleep.end) - x(asleep.start), 4),
                                height: laneBlockHeight
                            )
                            .offset(x: x(asleep.start))
                    }
                    // Each Wake Bout as an amber notch standing above and below the block.
                    ForEach(lane.wakeNotches, id: \.self) { notch in
                        Rectangle()
                            .fill(Poster.amber)
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
                .foregroundStyle(lane.isShort ? Poster.amber : Poster.ink)
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
                .fill(Poster.hairline)
                .frame(width: 1)
                .offset(x: label.fraction * width)
        }
    }

    /// Tonight's lane: a dashed bar from Be asleep by to the usual wake, the time at its right.
    private func tonightRow(_ lane: SleepTonightLane) -> some View {
        HStack(spacing: laneSpacing) {
            Text("Tonight")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Poster.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: laneNameWidth, alignment: .leading)
            GeometryReader { geometry in
                let width = geometry.size.width
                let start = week.axisFraction(of: lane.start) * width
                let end = week.axisFraction(of: lane.end) * width
                ZStack(alignment: .leading) {
                    axisGridlines(width: width)
                    Rectangle()
                        .fill(Poster.track)
                        .overlay(
                            Rectangle().strokeBorder(
                                Poster.ink,
                                style: StrokeStyle(lineWidth: 1.2, dash: [3, 3])
                            )
                        )
                        .frame(width: max(end - start, 4), height: laneBlockHeight)
                        .offset(x: start)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: laneBarHeight)
            Text(lane.text)
                .font(.footnote.weight(.semibold).monospacedDigit())
                .foregroundStyle(Poster.ink)
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
            NightChartBody(lane: lane)
            HStack {
                if let woke = lane.wakeText {
                    Text(woke).font(.footnote).foregroundStyle(Poster.secondary)
                }
                Spacer()
                SleepScoreButton { showSleepScore(lane.day) }
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 12)
    }
}

/// A Night's chart, or the note saying its heart rate isn't kept: in the shown Night's section
/// and under an opened lane alike.
private struct NightChartBody: View {
    let lane: SleepLane

    var body: some View {
        if let chart = lane.chart {
            SleepChartView(chart: chart)
        } else if let notKept = lane.notKeptText {
            Text(notKept)
                .font(.footnote)
                .foregroundStyle(Poster.secondary)
                .frame(maxWidth: .infinity, minHeight: 80)
                .multilineTextAlignment(.center)
        }
    }
}

/// A Night's chart (spec 012), one picture: the asleep stretch shaded behind it with its times,
/// Wake Bouts as amber columns, the smoothed Heart Rate Trace as a red curve with
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
                context.fill(Path(asleep), with: .color(Poster.track.opacity(0.6)))
                let startLabel = context.resolve(
                    Text(chart.asleepStartText).font(.caption2).foregroundStyle(Poster.secondary)
                )
                let endLabel = context.resolve(
                    Text(chart.asleepEndText).font(.caption2).foregroundStyle(Poster.secondary)
                )
                context.draw(
                    startLabel,
                    at: CGPoint(x: asleep.minX + 8, y: top / 2 + 2),
                    anchor: .leading
                )
                // On a short asleep stretch the two would overlap: the start label wins.
                let labelsWidth =
                    startLabel.measure(in: size).width + endLabel.measure(in: size).width + 24
                if asleep.width >= labelsWidth {
                    context.draw(
                        endLabel,
                        at: CGPoint(x: asleep.maxX - 8, y: top / 2 + 2),
                        anchor: .trailing
                    )
                }
                for bout in chart.wakeBouts {
                    // Under the label strip, so a Wake Bout near either end never covers a label.
                    let rect = CGRect(
                        x: x(bout.start),
                        y: top,
                        width: max(x(bout.end) - x(bout.start), 3),
                        height: size.height - top
                    )
                    context.fill(Path(rect), with: .color(Poster.amber.opacity(0.35)))
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
                                .init(color: Poster.red.opacity(0.3), location: 0),
                                .init(color: Poster.red.opacity(0), location: 1),
                            ]),
                            startPoint: CGPoint(x: 0, y: top),
                            endPoint: CGPoint(x: 0, y: size.height)
                        )
                    )
                    context.stroke(
                        line,
                        with: .color(Poster.red),
                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                    )
                }
                if let sleepingHR = chart.sleepingHR {
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y(sleepingHR)))
                    line.addLine(to: CGPoint(x: width, y: y(sleepingHR)))
                    context.stroke(
                        line,
                        with: .color(Poster.ink.opacity(0.6)),
                        style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [1, 4])
                    )
                    if let label = chart.sleepingHRLabel {
                        // A tag on a paper block at the line's right end.
                        let text = context.resolve(
                            Text(label).font(.caption2.weight(.bold)).foregroundStyle(Poster.ink)
                        )
                        let textSize = text.measure(in: size)
                        let pill = CGRect(
                            x: width - textSize.width - 14,
                            y: y(sleepingHR) - 9,
                            width: textSize.width + 12,
                            height: 18
                        )
                        context.fill(Path(pill), with: .color(Poster.paper))
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
                    .foregroundStyle(Poster.secondary)
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
/// The height of a lane's row and of a row of axis labels or hour ticks, points.
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
