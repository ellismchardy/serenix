import Charts
import SerenixCore
import SwiftUI

/// Which popup is open over the Today screen (spec 002, Popups).
enum TodayPopup: Identifiable, Hashable {
    case readiness
    case sleep
    case metric(NightlyMetric)
    case restingHR
    case load

    var id: Self { self }
}

/// The open popup's content, drawn from the Today view. Each slides up and closes on a tap
/// outside or a swipe down: a sheet of paper with a short heavy grab bar and the masthead, the
/// popup's name on the left and the Day on the right (spec 018, Popups).
struct TodayPopupView: View {
    let popup: TodayPopup
    let today: TodayView
    /// For the Live HR pill on today's Load popup, which observes it; the popup itself doesn't,
    /// so it isn't redrawn on every sync tick.
    let connection: StrapConnection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // The short heavy grab bar, in place of the system's.
                Rectangle()
                    .fill(Poster.ink)
                    .frame(width: 40, height: 4)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
                Masthead(title: name, detail: detail)
                switch popup {
                case .readiness:
                    if let readiness = today.readinessPopup {
                        ReadinessPopupView(popup: readiness, verdict: today.readinessVerdict)
                    }
                case .sleep:
                    if let sleep = today.sleepPopup { SleepPopupView(popup: sleep) }
                case .metric(let metric):
                    if let content = today.metricPopup(metric) { MetricPopupView(popup: content) }
                case .restingHR:
                    if let content = today.restingHRPopup { RestingHRPopupView(popup: content) }
                case .load:
                    if let load = today.loadPopup {
                        LoadPopupView(popup: load, connection: connection)
                    }
                }
            }
            .padding()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Poster.paper)
    }

    /// The popup's name in its masthead.
    private var name: String {
        switch popup {
        case .readiness: "Readiness"
        case .sleep: "Sleep Score"
        case .metric(let metric): metric.name
        case .restingHR: "Resting HR"
        case .load: "Load"
        }
    }

    /// The Night or Day on the masthead's right, as each popup's spec words it ("Today" on
    /// today's Load popup, spec 006); the Day shown where a popup has no wording of its own.
    private var detail: String {
        switch popup {
        case .metric(let metric): today.metricPopup(metric)?.nightText ?? shownDayText
        case .restingHR: today.restingHRPopup?.dateText ?? shownDayText
        case .load: today.loadPopup?.dateText ?? shownDayText
        case .readiness, .sleep: shownDayText
        }
    }

    private var shownDayText: String { Poster.dayText(today.shownDate) }
}

/// The Readiness popup (spec 012) in the Poster look (spec 018): the Readiness headline with its
/// band verdict, captioned by spec 012's verdict sentence, and the band word as a solid tag in its
/// colour; the band scale as flat segments; why, biggest effect first; Your week; and Sleep Score.
private struct ReadinessPopupView: View {
    let popup: ReadinessPopup
    /// The Today headline's verdict, the same in the popup (spec 018).
    let verdict: Verdict?

    var body: some View {
        PosterHeadline(
            number: popup.readinessText,
            verdict: verdict,
            caption: popup.verdictText,
            size: Poster.bodyHeadlineSize
        )
        // The band word beside the number (spec 012), as a solid tag.
        if let band = popup.band {
            PosterTag(text: band.word, colour: band.colour)
        }
        RuledSection(name: "Band") {
            ReadinessBandScaleView(
                segments: popup.scaleSegments,
                band: popup.band,
                marker: popup.scaleMarker,
                usualTick: popup.usualTick
            )
        }
        if !popup.whyRows.isEmpty {
            RuledSection(name: "Why, biggest effect first") {
                ForEach(Array(popup.whyRows.enumerated()), id: \.offset) { _, row in
                    RuledRow { ReadinessWhyRowView(row: row) }
                }
            }
        }
        RuledSection(name: "Your week") {
            ReadinessWeekView(bars: popup.week)
        }
        if let sleepScore = popup.sleepScoreText {
            RuledRow {
                LabeledContent("Sleep Score", value: sleepScore)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Poster.ink)
            }
        }
    }
}

/// The Readiness popup's band scale: the three bands from 0 to 100 as flat segments, the Night's
/// at full colour, an ink marker at its Readiness and a "usual 70" tick, with each band's word
/// under its segment.
private struct ReadinessBandScaleView: View {
    let segments: [ReadinessScaleSegment]
    /// Nil while Calibrating or missing: every segment is faded.
    let band: ReadinessBand?
    let marker: Double?
    let usualTick: Double?
    /// How much a band other than the Night's is faded, 0 to 1.
    private let fadedOpacity = 0.25
    /// The bar's height, in points.
    private let barHeight: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geometry in
                let width = geometry.size.width
                ZStack(alignment: .leading) {
                    HStack(spacing: 2) {
                        ForEach(segments, id: \.from) { segment in
                            Rectangle()
                                .fill(segment.band.colour)
                                .opacity(segment.band == band ? 1 : fadedOpacity)
                                .frame(width: max(0, (segment.to - segment.from) * width - 2))
                        }
                    }
                    .frame(height: barHeight)
                    if let usualTick {
                        Rectangle()
                            .fill(Poster.ink)
                            .frame(width: 1, height: barHeight + 8)
                            .offset(x: usualTick * width - 0.5)
                    }
                    if let marker {
                        Rectangle()
                            .fill(Poster.ink)
                            .frame(width: 3, height: barHeight + 12)
                            .offset(x: max(0, min(marker * width - 1.5, width - 3)))
                    }
                }
                .frame(height: barHeight + 12)
                if let usualTick {
                    Text("usual \(Int((usualTick * 100).rounded()))")
                        .font(.caption2)
                        .foregroundStyle(Poster.secondary)
                        .fixedSize()
                        .position(x: usualTick * width, y: barHeight + 20)
                }
            }
            .frame(height: barHeight + 28)
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(segments, id: \.from) { segment in
                        Text(segment.band.word.uppercased())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Poster.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(width: (segment.to - segment.from) * geometry.size.width)
                    }
                }
            }
            .frame(height: 14)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(band.map { "Readiness band: \($0.word)" } ?? "No Readiness band yet")
    }
}

/// One input in the Readiness popup's Why list: name, weight, value, points as a tag, reason and
/// a thin gauge.
private struct ReadinessWhyRowView: View {
    let row: ReadinessWhyRow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.name).bold()
                Text(row.weightText).font(.caption).foregroundStyle(Poster.secondary)
                Spacer()
                Text(row.valueText).bold().monospacedDigit()
                if let points = row.pointsText {
                    PosterTag(text: points, colour: Poster.ink)
                }
            }
            .foregroundStyle(Poster.ink)
            Text(row.reasonText).font(.footnote).foregroundStyle(Poster.secondary)
            if let position = row.gaugePosition { gauge(at: position) }
        }
    }

    /// Worse on the left, usual in the middle, better on the right: a thin flat bar, an ink tick
    /// at usual and an ink marker at the input.
    private func gauge(at position: Double) -> some View {
        VStack(spacing: 3) {
            GeometryReader { geometry in
                let width = geometry.size.width
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: Poster.red, location: 0),
                                    .init(color: Poster.amber, location: 0.3),
                                    .init(color: Poster.track, location: 0.45),
                                    .init(color: Poster.track, location: 0.55),
                                    .init(color: Poster.green, location: 0.7),
                                    .init(color: Poster.green, location: 1),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 4)
                    Rectangle()
                        .fill(Poster.ink)
                        .frame(width: 1, height: 10)
                        .offset(x: width / 2)
                    Rectangle()
                        .fill(Poster.ink)
                        .frame(width: 3, height: 14)
                        .offset(x: max(0, min(position * width - 1.5, width - 3)))
                }
                .frame(height: 14)
            }
            .frame(height: 14)
            HStack {
                Text("worse")
                Spacer()
                Text("usual")
                Spacer()
                Text("better")
            }
            .font(.caption2)
            .foregroundStyle(Poster.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.reasonText)
    }
}

/// The Readiness popup's Your week: a flat bar per Day, oldest first, its height the Day's
/// Readiness; the Day shown in the type colour.
private struct ReadinessWeekView: View {
    let bars: [ReadinessWeekBar]
    /// The height of a bar at Readiness 100, in points.
    private let fullHeight: CGFloat = 70
    /// The height of a hatched bar for a Day with no Readiness, in points.
    private let noReadinessHeight: CGFloat = 18

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
                VStack(spacing: 3) {
                    Rectangle()
                        .fill(fill(of: bar))
                        .overlay {
                            if bar.band == nil {
                                Hatch().stroke(Poster.hairline, lineWidth: 1).clipped()
                            }
                        }
                        // With no Readiness the Day shown is still marked (spec 012: outlined).
                        .overlay {
                            if bar.band == nil, bar.isDayShown {
                                Rectangle().strokeBorder(Poster.ink, lineWidth: 2)
                            }
                        }
                        .frame(height: height(of: bar))
                    Text(bar.weekdayText).font(.caption2).foregroundStyle(Poster.secondary)
                    Text(bar.readinessText).font(.caption2).monospacedDigit()
                        .foregroundStyle(Poster.ink)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            bars.map { "\($0.weekdayText) \($0.readinessText)" }.joined(separator: ", ")
        )
    }

    /// The Day shown in ink, every other Day in its band's colour; none without a Readiness.
    private func fill(of bar: ReadinessWeekBar) -> Color {
        guard let band = bar.band else { return .clear }
        return bar.isDayShown ? Poster.ink : band.colour
    }

    private func height(of bar: ReadinessWeekBar) -> CGFloat {
        guard bar.band != nil else { return noReadinessHeight }
        return max(4, fullHeight * bar.fill)
    }
}

/// The Sleep Score popup (spec 010) in the Poster look (spec 018): the Sleep Score headline and
/// verdict; its parts as rows with a big number and a thin bar; When you slept; How much you
/// slept.
private struct SleepPopupView: View {
    let popup: SleepPopup

    var body: some View {
        PosterHeadline(
            number: popup.sleepScoreText,
            verdict: popup.verdict,
            size: Poster.bodyHeadlineSize
        )
        RuledSection(name: "Sleep Score") {
            ForEach(popup.parts, id: \.name) { part in
                RuledRow {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(part.name).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(part.scoreText)
                                .font(Poster.headlineFont(size: 28))
                                .monospacedDigit()
                        }
                        .foregroundStyle(Poster.ink)
                        PosterBar(fill: part.fill, colour: Poster.ink, height: 5)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        whenYouSlept
        howMuchYouSlept
    }

    /// Time Asleep as a red bar with a marker at Sleep Need, then Sleep Debt (spec 010).
    private var howMuchYouSlept: some View {
        RuledSection(name: "How much you slept") {
            SleepNeedBarView(bar: popup.sleepNeedBar).frame(height: 16)
            HStack {
                Text(popup.sleepNeedBar.asleepText).monospacedDigit()
                    .foregroundStyle(Poster.ink)
                Spacer()
                Text(popup.sleepNeedBar.neededText).monospacedDigit()
                    .foregroundStyle(Poster.secondary)
            }
            .font(.subheadline)
            // The amount level with its label, and which Nights it's from under the amount.
            RuledRow {
                HStack(alignment: .firstTextBaseline) {
                    Text("Sleep Debt")
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(popup.sleepDebtText).bold().monospacedDigit()
                        Text(popup.sleepDebtCaption).font(.footnote)
                            .foregroundStyle(Poster.secondary)
                    }
                }
                .foregroundStyle(Poster.ink)
            }
        }
    }

    /// The Night's Sleep Period on its timeline, with how far off the usual times it was as the
    /// section's note, a key, and Time in Bed, minutes awake and Sleep Efficiency's detail under it.
    private var whenYouSlept: some View {
        RuledSection(name: "When you slept", note: popup.whenYouSleptNote) {
            if let timeline = popup.timeline {
                SleepTimelineView(timeline: timeline).frame(height: 104)
                timelineKey(timeline)
            } else {
                Text("No Sleep Period for this Night").foregroundStyle(Poster.secondary)
            }
            PosterRule(width: Poster.rowRule, colour: Poster.hairline)
            HStack(alignment: .top) {
                stat(
                    "Time in Bed",
                    popup.timeInBedText,
                    detail: popup.timeInBedDurationText
                )
                stat("Awake in the night", popup.minutesAwakeText)
                stat("Sleep Efficiency", popup.sleepEfficiencyDetailText)
            }
        }
    }

    /// What the timeline's marks mean: the Sleep Period, and Time in Bed and the usual times when
    /// they're drawn.
    private func timelineKey(_ timeline: SleepTimeline) -> some View {
        HStack(spacing: 12) {
            keyItem("Asleep") { Rectangle().fill(Poster.ink) }
            if timeline.timeInBed != nil {
                keyItem("In bed") { Rectangle().fill(Poster.track) }
            }
            if timeline.usualSleepOnset != nil || timeline.usualFinalWake != nil {
                keyItem("Usual") {
                    Path { path in
                        path.move(to: CGPoint(x: 6, y: 0))
                        path.addLine(to: CGPoint(x: 6, y: 12))
                    }
                    .stroke(Poster.green, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                }
            }
        }
        .font(.caption2)
        .foregroundStyle(Poster.secondary)
        .accessibilityHidden(true)
    }

    private func keyItem<Swatch: View>(
        _ name: String,
        @ViewBuilder swatch: () -> Swatch
    ) -> some View {
        HStack(spacing: 4) {
            swatch().frame(width: 12, height: 12)
            Text(name)
        }
    }

    /// One fact under the timeline: a small label over its value, and an optional detail.
    private func stat(_ label: String, _ value: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.bold))
                .foregroundStyle(Poster.secondary)
            Text(value).font(.footnote.weight(.semibold)).monospacedDigit()
                .foregroundStyle(Poster.ink)
            if let detail {
                Text(detail).font(.caption2).foregroundStyle(Poster.secondary).monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The Sleep popup's timeline (spec 010): the Sleep Period as an ink bar between its labelled
/// ends, Time in Bed in grey behind it, the usual times as dashed green lines, over hairline hour
/// lines and their labels. Every position comes from `SleepTimeline`.
private struct SleepTimelineView: View {
    let timeline: SleepTimeline

    // Rows, top to bottom, in points: "usual" labels, the band and bar, end labels, hours.
    private static let usualLabelY: CGFloat = 7
    private static let barTop: CGFloat = 26
    private static let barHeight: CGFloat = 22
    /// How far Time in Bed's band reaches above and below the bar, points.
    private static let bandOverhang: CGFloat = 6
    private static let endLabelY: CGFloat = 70
    private static let hourLabelY: CGFloat = 96
    /// Time in Bed's band: the bar with `bandOverhang` above and below.
    private static let bandTop: CGFloat = barTop - bandOverhang
    private static let bandHeight: CGFloat = barHeight + 2 * bandOverhang
    /// Where the hour and usual lines start: just above the band.
    private static let linesTop: CGFloat = barTop - bandOverhang - 4
    /// Where a usual line ends: just below the band, clear of the end labels.
    private static let usualLineBottom: CGFloat = barTop + barHeight + bandOverhang + 4
    /// Where an hour line ends: just above the hour labels.
    private static let hourLineBottom: CGFloat = hourLabelY - 10

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let periodWidth: CGFloat =
                (timeline.finalWake.position - timeline.sleepOnset.position) * width
            ZStack(alignment: .topLeading) {
                ForEach(timeline.hours, id: \.position) { hour in
                    hourLine(at: hour.position * width)
                }
                // Time in Bed as a light band behind the Sleep Period.
                if let bed = timeline.timeInBed {
                    Rectangle()
                        .fill(Poster.track)
                        .frame(width: (bed.end - bed.start) * width, height: Self.bandHeight)
                        .offset(x: bed.start * width, y: Self.bandTop)
                }
                Rectangle()
                    .fill(Poster.ink)
                    .frame(width: max(periodWidth, 2), height: Self.barHeight)
                    .offset(x: timeline.sleepOnset.position * width, y: Self.barTop)
                if let usual = timeline.usualSleepOnset { usualLine(usual, width: width) }
                if let usual = timeline.usualFinalWake { usualLine(usual, width: width) }
                inwardLabel(
                    Text(timeline.sleepOnset.text).font(.caption.bold()).monospacedDigit(),
                    at: timeline.sleepOnset.position * width,
                    y: Self.endLabelY,
                    width: width
                )
                inwardLabel(
                    Text(timeline.finalWake.text).font(.caption.bold()).monospacedDigit(),
                    at: timeline.finalWake.position * width,
                    y: Self.endLabelY,
                    width: width
                )
                ForEach(timeline.hours, id: \.position) { hour in
                    Text(hour.text)
                        .font(.caption2)
                        .foregroundStyle(Poster.secondary)
                        .monospacedDigit()
                        .fixedSize()
                        .position(x: hour.position * width, y: Self.hourLabelY)
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

    /// A faint vertical line at a labelled hour, from above the band to above the end labels.
    private func hourLine(at x: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: x, y: Self.linesTop))
            path.addLine(to: CGPoint(x: x, y: Self.hourLineBottom))
        }
        .stroke(Poster.hairline, lineWidth: 1)
    }

    /// A usual Sleep Onset or Final Wake: a dashed line across the band and bar, labelled
    /// "usual" and its clock time above it.
    private func usualLine(_ mark: TimelineMark, width: CGFloat) -> some View {
        let x = mark.position * width
        return ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: x, y: Self.linesTop))
                path.addLine(to: CGPoint(x: x, y: Self.usualLineBottom))
            }
            .stroke(Poster.green, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            inwardLabel(
                Text("usual \(mark.text)").font(.caption2).foregroundStyle(Poster.secondary),
                at: x,
                y: Self.usualLabelY,
                width: width
            )
        }
    }

    /// The widest a timeline label can be, points: room for "usual 23:00" in a large text size.
    private static let labelSlot: CGFloat = 120

    /// `label` beside `x`, reading inwards so it never runs off the card: starting at `x` in the
    /// timeline's left half, ending at `x` in its right half.
    private func inwardLabel(
        _ label: some View,
        at x: CGFloat,
        y: CGFloat,
        width: CGFloat
    ) -> some View {
        let startsAtX: Bool = x < width / 2
        let halfSlot: CGFloat = Self.labelSlot / 2
        let centreX: CGFloat = startsAtX ? x + halfSlot : x - halfSlot
        let alignment: Alignment = startsAtX ? .leading : .trailing
        return
            label
            .fixedSize()
            .frame(width: Self.labelSlot, alignment: alignment)
            .position(x: centreX, y: y)
    }
}

/// The Sleep Need bar (spec 010): Time Asleep as a flat red bar, with an ink marker at Sleep Need.
/// Fill and marker come from `SleepNeedBar`.
private struct SleepNeedBarView: View {
    let bar: SleepNeedBar

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let markerX: CGFloat = max(0, min(bar.marker * width - 1.5, width - 3))
            ZStack(alignment: .leading) {
                Rectangle().fill(Poster.track)
                Rectangle()
                    .fill(Poster.red)
                    .frame(width: bar.fill * width)
                Rectangle()
                    .fill(Poster.ink)
                    .frame(width: 3, height: geometry.size.height + 10)
                    .offset(x: markerX)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(bar.asleepText), \(bar.neededText)")
    }
}

/// The Nightly Metric popup (spec 011) in the Poster look (spec 018): the value headline with
/// its verdict and spec 011's verdict sentence; the Zone scale; the last 14 Nights; Baseline,
/// Lowest and Highest; what it is, Your Zones and what moves it, each a ruled section.
private struct MetricPopupView: View {
    let popup: MetricPopup

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PosterHeadline(
                number: popup.valueText,
                verdict: popup.verdict,
                size: Poster.bodyHeadlineSize
            )
            verdictSentence
            statusTag
        }
        // The Zone scale only when the value has a Zone (spec 011).
        if let scale = popup.scale {
            RuledSection(name: "Zone") {
                ZoneScaleView(scale: scale, zone: popup.zone, valueText: popup.valueText)
                    .frame(height: 60)
            }
        }
        RuledSection(name: "Last 14 Nights") {
            PopupBlocksView(
                blocks: popup.blocks.map {
                    PopupBlock(
                        letter: $0.weekdayLetter,
                        fill: $0.state.fill,
                        outlined: $0.isNightShown
                    )
                }
            )
        }
        PopupFactsView(facts: facts)
        PopupTextSection(name: "What it is", text: popup.whatItIsText)
        if let heading = popup.zonesHeading {
            RuledSection(name: heading) { zonesRows }
        }
        PopupBulletsSection(name: "What moves it", items: popup.whatMovesItTexts)
    }

    /// Baseline (none for SpO2), Lowest and Highest.
    private var facts: [(name: String, value: String)] {
        var facts: [(name: String, value: String)] = []
        if let baseline = popup.baselineText { facts.append((name: "Baseline", value: baseline)) }
        facts.append((name: "Lowest", value: popup.lowestText))
        facts.append((name: "Highest", value: popup.highestText))
        return facts
    }

    /// Spec 011's verdict sentence as the headline's caption, its words after the colon in the
    /// Zone's colour.
    private var verdictSentence: some View {
        let text = popup.verdictText
        let caption: Text
        if let colour = popup.zone?.colour, let colon = text.range(of: ": ") {
            caption =
                Text(text[..<colon.upperBound])
                + Text(text[colon.upperBound...]).bold().foregroundStyle(colour)
        } else {
            caption = Text(text)
        }
        return
            caption
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Poster.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The tile's status word as a solid tag in the Zone's colour, or plain grey with no Zone.
    @ViewBuilder private var statusTag: some View {
        if let colour = popup.zone?.colour {
            PosterTag(text: popup.statusText, colour: colour)
        } else {
            Text(popup.statusText).font(.footnote).foregroundStyle(Poster.secondary)
        }
    }

    /// In range, Watch and Out of range with their ranges as hairline rows, the Night's row bold.
    private var zonesRows: some View {
        ForEach(popup.zoneRows, id: \.zone) { row in
            RuledRow {
                HStack(spacing: 8) {
                    Rectangle().fill(row.zone.colour).frame(width: 10, height: 10)
                    Text(row.nameText)
                    Spacer()
                    Text(row.rangeText).monospacedDigit().multilineTextAlignment(.trailing)
                }
                .font(.subheadline)
                .fontWeight(row.isThisNight ? .bold : .regular)
                .foregroundStyle(Poster.ink)
            }
        }
    }
}

/// The Resting HR popup (spec 011) in the Poster look: the Nightly Metric popup's layout without
/// anything that needs a Baseline or Zone, so no verdict, scale or Your Zones, and its blocks all
/// one colour.
private struct RestingHRPopupView: View {
    let popup: RestingHRPopup

    var body: some View {
        PosterHeadline(
            number: popup.valueText,
            verdict: nil,
            caption: popup.sentenceText,
            size: Poster.bodyHeadlineSize
        )
        RuledSection(name: "Last 14 Days") {
            PopupBlocksView(
                blocks: popup.blocks.map {
                    PopupBlock(
                        letter: $0.weekdayLetter,
                        // One neutral colour: the grey of a block with no Zone.
                        fill: $0.hasValue ? MetricPopupBlockState.noZone.fill : nil,
                        outlined: $0.isDayShown
                    )
                }
            )
        }
        PopupFactsView(
            facts: [
                (name: "Lowest", value: popup.lowestText),
                (name: "Highest", value: popup.highestText),
            ]
        )
        PopupTextSection(name: "What it is", text: popup.whatItIsText)
        PopupBulletsSection(name: "What moves it", items: popup.whatMovesItTexts)
    }
}

/// The Zone scale (spec 011) in the Poster look: flat Zone segments, the Night's at full colour
/// and the rest faded, an ink marker at the value labelled with it, and an ink tick under the bar
/// at the Baseline.
private struct ZoneScaleView: View {
    let scale: MetricPopupScale
    let zone: Zone?
    let valueText: String

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            // Keeps a label at an end from running off the screen.
            let x = { (position: Double) in min(max(width * position, 24), width - 24) }
            ZStack {
                HStack(spacing: 0) {
                    ForEach(Array(scale.segments.enumerated()), id: \.offset) { _, segment in
                        Rectangle()
                            .fill(segment.zone.colour.opacity(segment.zone == zone ? 1 : 0.25))
                            .frame(width: width * (segment.to - segment.from))
                    }
                }
                .frame(width: width, height: 14)
                .position(x: width / 2, y: 26)
                VStack(spacing: 2) {
                    Text(valueText).font(.caption2.bold()).monospacedDigit()
                        .foregroundStyle(Poster.ink)
                    Rectangle().fill(Poster.ink).frame(width: 3, height: 26)
                }
                .fixedSize()
                .position(x: x(scale.valuePosition), y: 19)
                if let baseline = scale.baselinePosition, let label = scale.baselineLabel {
                    VStack(spacing: 1) {
                        Rectangle().fill(Poster.ink).frame(width: 2, height: 6)
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(Poster.secondary)
                    }
                    .fixedSize()
                    .position(x: x(baseline), y: 48)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// One block in a popup's last 14 Nights or Days.
private struct PopupBlock {
    let letter: String
    /// Nil for no value, drawn hatched.
    let fill: Color?
    let outlined: Bool
}

/// A row of flat blocks, oldest on the left, each with its weekday initial; the Night or Day
/// shown outlined in ink.
private struct PopupBlocksView: View {
    let blocks: [PopupBlock]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                VStack(spacing: 3) {
                    Rectangle()
                        .fill(block.fill ?? .clear)
                        .overlay {
                            if block.fill == nil {
                                Hatch().stroke(Poster.hairline, lineWidth: 1).clipped()
                            }
                        }
                        .overlay {
                            if block.outlined {
                                Rectangle().strokeBorder(Poster.ink, lineWidth: 2)
                            }
                        }
                        .frame(height: 18)
                    Text(block.letter).font(.caption2).foregroundStyle(Poster.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Diagonal lines, for a block with no value.
private struct Hatch: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = rect.minX - rect.height
        while x < rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            x += 4
        }
        return path
    }
}

/// Facts in columns, each under a heavy rule: its name, then its value large.
private struct PopupFactsView: View {
    let facts: [(name: String, value: String)]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(Array(facts.enumerated()), id: \.offset) { _, fact in
                VStack(alignment: .leading, spacing: 6) {
                    PosterRule()
                    Text(fact.name.uppercased())
                        .font(Poster.labelFont)
                        .foregroundStyle(Poster.ink)
                    Text(fact.value)
                        .font(Poster.headlineFont(size: 28))
                        .monospacedDigit()
                        .foregroundStyle(Poster.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// A ruled section of plain text.
private struct PopupTextSection: View {
    let name: String
    let text: String

    var body: some View {
        RuledSection(name: name) {
            Text(text).font(.subheadline).foregroundStyle(Poster.ink)
        }
    }
}

/// A ruled section of bullet points.
private struct PopupBulletsSection: View {
    let name: String
    let items: [String]

    var body: some View {
        RuledSection(name: name) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                        Text(item)
                    }
                }
            }
            .font(.subheadline)
            .foregroundStyle(Poster.ink)
        }
    }
}

extension MetricPopupBlockState {
    /// The block's colour: its Zone's, grey with no Zone, nil (hatched) with no value.
    fileprivate var fill: Color? {
        switch self {
        case .zone(let zone): zone.colour
        case .noZone: Poster.waiting.opacity(0.5)
        case .noValue: nil
        }
    }
}

/// The Load popup (spec 006), the layout of prototype variant C (branch
/// `prototype/load-popup-ui`): the Live HR pill on today and the date; the sentence, typical line
/// and Load bar against typical Load; how hard, as the HR Zone mix and its rows; when, as the
/// hourly bars; then Highest HR and the Max HR used.
private struct LoadPopupView: View {
    let popup: LoadPopup
    let connection: StrapConnection

    var body: some View {
        if popup.showsLiveHR { LiveHRPillView(connection: connection) }
        // The Day's Load with its verdict, captioned by spec 006's sentence and the last sync
        // (spec 018, Popups).
        PosterHeadline(
            number: popup.loadText,
            verdict: popup.verdict,
            caption: [popup.comparisonText, popup.lastSyncText].compactMap { $0 }
                .joined(separator: "\n"),
            size: Poster.bodyHeadlineSize
        )
        againstTypicalSection
        if let note = popup.note {
            Text(note).foregroundStyle(Poster.secondary)
        } else {
            howHardSection
            RuledSection(name: "When") {
                hourlyBars.frame(height: 160)
            }
            VStack(alignment: .leading, spacing: 4) {
                PosterRule()
                if let highest = popup.highestHRText {
                    Text(highest).font(.subheadline.weight(.bold)).foregroundStyle(Poster.ink)
                }
                if let maxHR = popup.maxHRText {
                    Text(maxHR).font(.footnote).foregroundStyle(Poster.secondary)
                }
            }
        }
    }

    /// The bar from 0 to twice typical Load with a tick at typical Load, the typical line as its
    /// note (spec 006). While typical Load is learned there's no bar; the headline already shows
    /// the Day's Load.
    private var againstTypicalSection: some View {
        RuledSection(name: "Against typical", note: popup.typicalText) {
            if let fill = popup.loadBarFill {
                PosterBar(fill: fill, tick: LoadPopup.typicalLoadTick)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Load \(popup.loadText)")
            }
        }
    }

    /// The HR Zone mix as one flat bar split by HR Zone, then each HR Zone's time as hairline
    /// rows, hardest first.
    private var howHardSection: some View {
        RuledSection(name: "How hard") {
            if !popup.zoneMix.isEmpty {
                GeometryReader { geometry in
                    let gaps = CGFloat(popup.zoneMix.count - 1) * 2
                    HStack(spacing: 2) {
                        ForEach(popup.zoneMix, id: \.zone) { part in
                            Rectangle()
                                .fill(part.zone.colour)
                                .frame(width: (geometry.size.width - gaps) * part.share)
                        }
                    }
                }
                .frame(height: 16)
                .accessibilityHidden(true)
            }
            ForEach(popup.zoneRows, id: \.zone) { row in
                RuledRow {
                    HStack {
                        Rectangle().fill(row.zone.colour).frame(width: 10, height: 10)
                        Text(row.label).foregroundStyle(Poster.ink)
                        Spacer()
                        Text(row.timeText).monospacedDigit().foregroundStyle(Poster.ink)
                    }
                    .font(.subheadline)
                }
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
    /// Cool to hot, HR Zone 1 to 5, in the Poster look's colours (spec 018): grey, blue, green,
    /// amber, red.
    var colour: Color {
        switch self {
        case .one: Poster.hrZoneOne
        case .two: Poster.hrZoneTwo
        case .three: Poster.green
        case .four: Poster.amber
        case .five: Poster.red
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
                    .foregroundStyle(pill == .unavailable ? Poster.secondary : Poster.red)
                    .symbolEffect(.pulse, isActive: pill == .connecting)
                Text(pill.text).monospacedDigit()
            }
            .font(.subheadline.bold())
            .foregroundStyle(Poster.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .overlay(Rectangle().stroke(Poster.ink, lineWidth: Poster.sectionRule))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Live heart rate \(pill.text)")
        }
        .onAppear { connection.setLiveHRShown(true) }
        .onDisappear { connection.setLiveHRShown(false) }
    }
}
