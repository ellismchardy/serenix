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
                    if let readiness = today.readinessPopup {
                        ReadinessPopupView(popup: readiness, date: today.shownDate)
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
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.popupBackground)
    }
}

/// The Readiness popup (spec 012), the layout of prototype variant E (branch
/// `prototype/readiness-popup-ui`): the ring with its band and verdict, why, biggest effect first,
/// Your week, and Sleep Score.
private struct ReadinessPopupView: View {
    let popup: ReadinessPopup
    let date: Date

    var body: some View {
        HStack {
            Text("Readiness").font(.headline)
            Spacer()
            Text(date, format: .dateTime.weekday(.abbreviated).day().month())
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        bandScaleCard
        if !popup.whyRows.isEmpty {
            PopupSectionTitle("Why, biggest effect first")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(popup.whyRows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { Divider() }
                    ReadinessWhyRowView(row: row)
                }
            }
            .popupCard()
        }
        PopupSectionTitle("Your week")
        ReadinessWeekView(bars: popup.week)
        if let sleepScore = popup.sleepScoreText {
            LabeledContent("Sleep Score", value: sleepScore).popupCard()
        }
    }

    /// The number large in its band's colour with the band word, the verdict, and the band scale
    /// (spec 012, header prototype variant B). Greyed with no marker while Calibrating or missing.
    private var bandScaleCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(popup.readinessText)
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(popup.band?.colour ?? .secondary)
                if let band = popup.band {
                    Text(band.word).font(.title3.bold())
                }
            }
            if let verdict = popup.verdictText {
                Text(verdict).font(.subheadline.weight(.semibold))
            }
            ReadinessBandScaleView(
                segments: popup.scaleSegments,
                band: popup.band,
                marker: popup.scaleMarker,
                usualTick: popup.usualTick
            )
            .padding(.top, 8)
        }
        .popupCard()
    }
}

/// The Readiness popup's band scale: the three bands from 0 to 100, the Night's at full colour,
/// a marker at its Readiness and a "usual 70" tick, with each band's word under its segment.
private struct ReadinessBandScaleView: View {
    let segments: [ReadinessScaleSegment]
    /// Nil while Calibrating or missing: every segment is faded.
    let band: ReadinessBand?
    let marker: Double?
    let usualTick: Double?
    /// How much a band other than the Night's is faded, 0 to 1.
    private let fadedOpacity = 0.25
    /// The bar's height, in points.
    private let barHeight: CGFloat = 12

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
                    .clipShape(Capsule())
                    if let usualTick {
                        Rectangle()
                            .fill(.secondary)
                            .frame(width: 1, height: barHeight + 8)
                            .offset(x: usualTick * width - 0.5)
                    }
                    if let marker {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.primary)
                            .frame(width: 4, height: barHeight + 10)
                            .offset(x: max(0, min(marker * width - 2, width - 4)))
                    }
                }
                .frame(height: barHeight + 10)
                if let usualTick {
                    Text("usual \(Int((usualTick * 100).rounded()))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        .position(x: usualTick * width, y: barHeight + 18)
                }
            }
            .frame(height: barHeight + 26)
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(segments, id: \.from) { segment in
                        Text(segment.band.word)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
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

/// One input in the Readiness popup's Why list: name, weight, value, points, reason and gauge.
private struct ReadinessWhyRowView: View {
    let row: ReadinessWhyRow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.name).bold()
                Text(row.weightText).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(row.valueText).bold().monospacedDigit()
                if let points = row.pointsText {
                    Text(points).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
            }
            Text(row.reasonText).font(.footnote).foregroundStyle(.secondary)
            if let position = row.gaugePosition { gauge(at: position) }
        }
        .padding(.vertical, 10)
    }

    /// Worse on the left, usual in the middle, better on the right.
    private func gauge(at position: Double) -> some View {
        VStack(spacing: 3) {
            GeometryReader { geometry in
                let width = geometry.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .red, location: 0),
                                    .init(color: .orange, location: 0.3),
                                    .init(color: Theme.accentSoft, location: 0.45),
                                    .init(color: Theme.accentSoft, location: 0.55),
                                    .init(color: .green, location: 0.7),
                                    .init(color: .green, location: 1),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 8)
                    Rectangle()
                        .fill(.secondary)
                        .frame(width: 1, height: 12)
                        .offset(x: width / 2)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.primary)
                        .frame(width: 4, height: 16)
                        .offset(x: max(0, min(position * width - 2, width - 4)))
                }
                .frame(height: 16)
            }
            .frame(height: 16)
            HStack {
                Text("worse")
                Spacer()
                Text("usual")
                Spacer()
                Text("better")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.reasonText)
    }
}

/// The Readiness popup's Your week: a bar per Day, oldest first, its height the Day's Readiness.
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
                    RoundedRectangle(cornerRadius: 5)
                        .fill(bar.band?.colour ?? .clear)
                        .overlay {
                            if bar.band == nil {
                                Hatch()
                                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                        }
                        .overlay {
                            if bar.isDayShown {
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(Color.primary, lineWidth: 2)
                            }
                        }
                        .frame(height: height(of: bar))
                    Text(bar.weekdayText).font(.caption2).foregroundStyle(.secondary)
                    Text(bar.readinessText).font(.caption2).monospacedDigit()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .popupCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            bars.map { "\($0.weekdayText) \($0.readinessText)" }.joined(separator: ", ")
        )
    }

    private func height(of bar: ReadinessWeekBar) -> CGFloat {
        guard bar.band != nil else { return noReadinessHeight }
        return max(4, fullHeight * bar.fill)
    }
}

private struct SleepPopupView: View {
    let popup: SleepPopup

    var body: some View {
        Text("Sleep").font(.headline)
        // Three cards (spec 010, Sleep popup): Sleep Score, When you slept, How much you slept.
        sleepScore.popupCard()
        whenYouSlept.popupCard()
        howMuchYouSlept.popupCard()
    }

    /// The Sleep Score as a big number with a key of its parts, and the parts as nested rings:
    /// Sleep Sufficiency outside, Sleep Efficiency in the middle, Sleep Consistency inside.
    private var sleepScore: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sleep Score").font(.footnote).foregroundStyle(.secondary)
                Text(popup.sleepScoreText)
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                ForEach(Array(zip(popup.parts, Self.partShades)), id: \.0.name) { part, shade in
                    HStack(spacing: 6) {
                        Circle().fill(shade).frame(width: 10, height: 10)
                        Text(part.name).font(.caption)
                        Text(part.scoreText).font(.caption.bold()).monospacedDigit()
                    }
                }
            }
            Spacer(minLength: 0)
            ZStack {
                ForEach(Array(zip(popup.parts, Self.partShades).enumerated()), id: \.element.0.name)
                { index, pair in
                    RingArc(fill: pair.0.fill, colour: pair.1, lineWidth: Self.ringLineWidth)
                        .frame(width: ringDiameter(index), height: ringDiameter(index))
                }
            }
            // The outer stroke reaches half a line past its circle.
            .frame(width: ringDiameter(0), height: ringDiameter(0))
            .padding(Self.ringLineWidth / 2)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                popup.parts.map { "\($0.name) \($0.scoreText)" }.joined(separator: ", ")
            )
        }
    }

    /// Each part's shade, in the parts' order: the accent outside, lighter inwards.
    private static let partShades = [Theme.accent, Theme.accentMiddle, Theme.accentInner]
    /// The nested rings' stroke, points.
    private static let ringLineWidth: CGFloat = 11
    /// The outer ring's diameter, points.
    private static let outerRingDiameter: CGFloat = 131
    /// The gap between nested rings, points.
    private static let ringGap: CGFloat = 3

    /// The nested ring at `index`'s diameter, outermost first, each a stroke and a gap inside
    /// the last on either side.
    private func ringDiameter(_ index: Int) -> CGFloat {
        Self.outerRingDiameter - CGFloat(index) * 2 * (Self.ringLineWidth + Self.ringGap)
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
            // The amount level with its label, and which Nights it's from under the amount.
            HStack(alignment: .firstTextBaseline) {
                Text("Sleep Debt")
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(popup.sleepDebtText).bold().monospacedDigit()
                    Text(popup.sleepDebtCaption).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)
        }
    }

    /// The Night's Sleep Period on its timeline, with how far off the usual times it was beside
    /// the heading, a key, and Time in Bed, minutes awake and Sleep Efficiency's detail under it.
    private var whenYouSlept: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("When you slept").font(.subheadline.bold())
                Spacer()
                if let note = popup.whenYouSleptNote {
                    Text(note)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.accentSoft, in: Capsule())
                }
            }
            if let timeline = popup.timeline {
                SleepTimelineView(timeline: timeline).frame(height: 104)
                timelineKey(timeline)
            } else {
                Text("No Sleep Period for this Night").foregroundStyle(.secondary)
            }
            Divider()
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
            keyItem("Asleep") { RoundedRectangle(cornerRadius: 3).fill(Theme.accent) }
            if timeline.timeInBed != nil {
                keyItem("In bed") { RoundedRectangle(cornerRadius: 3).fill(Theme.accentSoft) }
            }
            if timeline.usualSleepOnset != nil || timeline.usualFinalWake != nil {
                keyItem("Usual") {
                    Path { path in
                        path.move(to: CGPoint(x: 6, y: 0))
                        path.addLine(to: CGPoint(x: 6, y: 12))
                    }
                    .stroke(.secondary, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                }
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
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
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.footnote.weight(.semibold)).monospacedDigit()
            if let detail {
                Text(detail).font(.caption2).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The Sleep popup's timeline (spec 010): the Sleep Period as an accent bar between its labelled
/// ends, over faint hour lines and their labels. Every position comes from `SleepTimeline`.
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
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Theme.accentSoft)
                        .frame(width: (bed.end - bed.start) * width, height: Self.bandHeight)
                        .offset(x: bed.start * width, y: Self.bandTop)
                }
                Capsule()
                    .fill(Theme.accent)
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
                        .foregroundStyle(.secondary)
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
        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
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
            .stroke(Color.primary.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            inwardLabel(
                Text("usual \(mark.text)").font(.caption2).foregroundStyle(.secondary),
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
    /// One card of a popup, the same inset on every popup.
    fileprivate func popupCard() -> some View {
        padding(16).frame(maxWidth: .infinity, alignment: .leading).themeCard()
    }
}

/// The Nightly Metric popup (spec 011), the layout of prototype variant E (branch
/// `prototype/vital-signs-popup`): value and pill, the Zone scale and verdict, the last 14 Nights,
/// facts, what it is, Your Zones and what moves it.
private struct MetricPopupView: View {
    let popup: MetricPopup

    var body: some View {
        PopupHeading(icon: popup.metric.icon, name: popup.metric.name, detail: popup.nightText)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(popup.valueText).font(.largeTitle.bold()).monospacedDigit()
                Spacer()
                statusPill
            }
            if let scale = popup.scale {
                ZoneScaleView(scale: scale, zone: popup.zone, valueText: popup.valueText)
                    .frame(height: 60)
            }
            verdict
        }
        .popupCard()
        PopupSectionTitle("Last 14 Nights")
        PopupBlocksView(
            blocks: popup.blocks.map {
                PopupBlock(letter: $0.weekdayLetter, fill: $0.state.fill, outlined: $0.isNightShown)
            }
        )
        PopupFactsView(facts: facts)
        PopupSectionTitle("What it is")
        PopupTextCard(text: popup.whatItIsText)
        if let heading = popup.zonesHeading {
            PopupSectionTitle(heading)
            zonesTable
        }
        PopupSectionTitle("What moves it")
        PopupBulletsCard(items: popup.whatMovesItTexts)
    }

    /// Baseline (none for SpO2), Lowest and Highest.
    private var facts: [(name: String, value: String)] {
        var facts: [(name: String, value: String)] = []
        if let baseline = popup.baselineText { facts.append((name: "Baseline", value: baseline)) }
        facts.append((name: "Lowest", value: popup.lowestText))
        facts.append((name: "Highest", value: popup.highestText))
        return facts
    }

    /// The tile's status word: a ✓ and the Zone's colour, or plain grey with no Zone.
    @ViewBuilder private var statusPill: some View {
        if let colour = popup.zone?.colour {
            Label(popup.statusText, systemImage: "checkmark")
                .font(.footnote.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(colour, in: Capsule())
        } else {
            Text(popup.statusText).font(.footnote).foregroundStyle(.secondary)
        }
    }

    /// The verdict, its words after the colon in the Zone's colour.
    private var verdict: some View {
        let text = popup.verdictText
        guard let colour = popup.zone?.colour, let colon = text.range(of: ": ") else {
            return Text(text)
        }
        return Text(text[..<colon.upperBound])
            + Text(text[colon.upperBound...]).bold().foregroundStyle(colour)
    }

    /// In range, Watch and Out of range with their ranges, the Night's row bold.
    private var zonesTable: some View {
        VStack(spacing: 0) {
            ForEach(Array(popup.zoneRows.enumerated()), id: \.offset) { index, row in
                if index > 0 { Divider() }
                HStack(spacing: 8) {
                    Circle().fill(row.zone.colour).frame(width: 10, height: 10)
                    Text(row.nameText)
                    Spacer()
                    Text(row.rangeText).monospacedDigit().multilineTextAlignment(.trailing)
                }
                .font(.subheadline)
                .fontWeight(row.isThisNight ? .bold : .regular)
                .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .themeCard()
    }
}

/// The Resting HR popup (spec 011): the Nightly Metric popup's layout without anything that needs
/// a Baseline or Zone, so no pill, scale or Your Zones, and its blocks all one colour.
private struct RestingHRPopupView: View {
    let popup: RestingHRPopup

    var body: some View {
        PopupHeading(
            icon: NightlyMetric.sleepingHR.icon,
            name: "Resting HR",
            detail: popup.dateText
        )
        VStack(alignment: .leading, spacing: 12) {
            Text(popup.valueText).font(.largeTitle.bold()).monospacedDigit()
            if let sentence = popup.sentenceText { Text(sentence) }
        }
        .popupCard()
        PopupSectionTitle("Last 14 Days")
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
        PopupFactsView(
            facts: [
                (name: "Lowest", value: popup.lowestText),
                (name: "Highest", value: popup.highestText),
            ]
        )
        PopupSectionTitle("What it is")
        PopupTextCard(text: popup.whatItIsText)
        PopupSectionTitle("What moves it")
        PopupBulletsCard(items: popup.whatMovesItTexts)
    }
}

/// The Zone scale (spec 011): the Zone segments, the Night's at full colour and the rest faded, a
/// marker at the value labelled with it, and a tick under the bar at the Baseline.
private struct ZoneScaleView: View {
    let scale: MetricPopupScale
    let zone: Zone?
    let valueText: String

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            // Keeps a label at an end from running off the card.
            let x = { (position: Double) in min(max(width * position, 24), width - 24) }
            ZStack {
                HStack(spacing: 0) {
                    ForEach(Array(scale.segments.enumerated()), id: \.offset) { _, segment in
                        Rectangle()
                            .fill(segment.zone.colour.opacity(segment.zone == zone ? 1 : 0.3))
                            .frame(width: width * (segment.to - segment.from))
                    }
                }
                .frame(width: width, height: 12)
                .clipShape(Capsule())
                .position(x: width / 2, y: 26)
                VStack(spacing: 2) {
                    Text(valueText).font(.caption2.bold()).monospacedDigit()
                    Capsule().fill(Color.primary).frame(width: 4, height: 22)
                }
                .fixedSize()
                .position(x: x(scale.valuePosition), y: 19)
                if let baseline = scale.baselinePosition, let label = scale.baselineLabel {
                    VStack(spacing: 1) {
                        Rectangle().fill(Color.secondary).frame(width: 2, height: 6)
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .fixedSize()
                    .position(x: x(baseline), y: 48)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// A popup's heading: the icon and name, and the Night or Day on the right.
private struct PopupHeading: View {
    let icon: String
    let name: String
    let detail: String

    var body: some View {
        HStack {
            Label {
                Text(name)
            } icon: {
                Image(systemName: icon).foregroundStyle(Theme.accent)
            }
            .font(.headline)
            Spacer()
            Text(detail).font(.footnote).foregroundStyle(.secondary)
        }
    }
}

/// A small grey heading over a popup's card.
private struct PopupSectionTitle: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title.uppercased()).font(.caption).foregroundStyle(.secondary).padding(.top, 4)
    }
}

/// One block in a popup's last 14 Nights or Days.
private struct PopupBlock {
    let letter: String
    /// Nil for no value, drawn hatched.
    let fill: Color?
    let outlined: Bool
}

/// A row of blocks, oldest on the left, each with its weekday initial.
private struct PopupBlocksView: View {
    let blocks: [PopupBlock]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(block.fill ?? .clear)
                        .overlay {
                            if block.fill == nil {
                                Hatch()
                                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                        }
                        .overlay {
                            if block.outlined {
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(Color.primary, lineWidth: 2)
                            }
                        }
                        .frame(height: 18)
                    Text(block.letter).font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .popupCard()
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

/// Facts side by side: a small grey name over each value.
private struct PopupFactsView: View {
    let facts: [(name: String, value: String)]

    var body: some View {
        HStack(alignment: .top) {
            ForEach(Array(facts.enumerated()), id: \.offset) { _, fact in
                VStack(alignment: .leading, spacing: 2) {
                    Text(fact.name).font(.caption).foregroundStyle(.secondary)
                    Text(fact.value).font(.headline).monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .popupCard()
    }
}

/// A card of plain text.
private struct PopupTextCard: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .popupCard()
    }
}

/// A card of bullet points.
private struct PopupBulletsCard: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("•")
                    Text(item)
                }
            }
        }
        .font(.subheadline)
        .popupCard()
    }
}

extension MetricPopupBlockState {
    /// The block's colour: its Zone's, grey with no Zone, nil (hatched) with no value.
    fileprivate var fill: Color? {
        switch self {
        case .zone(let zone): zone.colour
        case .noZone: Color.secondary.opacity(0.4)
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
        HStack {
            if popup.showsLiveHR { LiveHRPillView(connection: connection) }
            Spacer()
            Text(popup.dateText).font(.footnote).foregroundStyle(.secondary)
        }
        againstTypicalCard
        if let note = popup.note {
            Text(note).foregroundStyle(.secondary).popupCard()
        } else {
            PopupSectionTitle("How hard")
            howHardCard
            PopupSectionTitle("When")
            hourlyBars.frame(height: 160).popupCard()
            VStack(alignment: .leading, spacing: 4) {
                if let highest = popup.highestHRText { Text(highest) }
                if let maxHR = popup.maxHRText {
                    Text(maxHR).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .popupCard()
        }
    }

    /// The sentence, the typical line, the Load bar (or, while typical Load is learned, the Day's
    /// Load in its place) and, on today, when the last sync ended.
    private var againstTypicalCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(popup.comparisonText).font(.title3.bold())
            Text(popup.typicalText).font(.subheadline).foregroundStyle(.secondary)
            if let fill = popup.loadBarFill {
                LoadBarView(fill: fill, loadText: popup.loadText).padding(.vertical, 10)
            } else if let learningLoad = popup.learningLoadText {
                Text(learningLoad).font(.largeTitle.bold()).monospacedDigit()
                    .padding(.vertical, 4)
            }
            if let lastSync = popup.lastSyncText {
                Text(lastSync).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .popupCard()
    }

    /// The HR Zone mix as one bar split by HR Zone, then each HR Zone's time, hardest first.
    private var howHardCard: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                .frame(height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.bottom, 8)
                .accessibilityHidden(true)
            }
            ForEach(Array(popup.zoneRows.enumerated()), id: \.offset) { index, row in
                if index > 0 { Divider() }
                HStack {
                    Circle().fill(row.zone.colour).frame(width: 9, height: 9)
                    Text(row.label)
                    Spacer()
                    Text(row.timeText).monospacedDigit()
                }
                .padding(.vertical, 8)
            }
        }
        .popupCard()
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

/// The Load popup's bar from 0 to twice typical Load (spec 006): filled to the Day's Load with the
/// Load written at its end, and a "typical" marker at its middle.
private struct LoadBarView: View {
    /// 0 to 1.
    let fill: Double
    let loadText: String

    /// The narrowest a filled bar draws, so the Load written inside it still fits.
    private static let minimumFillWidth: CGFloat = 44

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10).fill(Theme.accentSoft)
                    if fill > 0 {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.accent)
                            .frame(width: max(Self.minimumFillWidth, geometry.size.width * fill))
                            .overlay(alignment: .trailing) {
                                Text(loadText).font(.subheadline.bold()).monospacedDigit()
                                    .foregroundStyle(.white).padding(.trailing, 10)
                            }
                    } else {
                        // An empty bar (a Load of 0, or none) still says its Load, at the start.
                        Text(loadText).font(.subheadline.bold()).monospacedDigit()
                            .foregroundStyle(.secondary).padding(.leading, 10)
                    }
                }
            }
            .frame(height: 34)
            // The typical marker at the middle, standing a little proud of the bar.
            .overlay { Capsule().fill(.primary).frame(width: 3, height: 46) }
            Text("typical").font(.caption2).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Load \(loadText)")
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
