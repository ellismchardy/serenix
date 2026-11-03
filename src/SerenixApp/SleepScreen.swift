import SerenixCore
import SwiftUI

/// The Sleep tab (spec 011): draws the Sleep view for the Day shown, inside the same top bar and
/// sync pill as the Today tab.
struct SleepScreen: View {
    @ObservedObject var connection: StrapConnection
    @ObservedObject var profile: ProfileStore
    /// The Day shown, shared with the Today tab; nil is today.
    @Binding var pickedDay: Day?
    /// The sync pill swiped away, shared with the other tab so there is one pill.
    @Binding var dismissedPill: SyncPill?
    @State private var showsProfileMenu = false
    @State private var showsSleepPopup = false
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
            connection: connection,
            profile: profile,
            pickedDay: $pickedDay,
            showsProfileMenu: $showsProfileMenu,
            dismissedPill: $dismissedPill,
            today: today
        ) {
            WeekStripView(strip: sleep.weekStrip) { pickedDay = shownSelection($0) }
            if let tonight = sleep.tonight {
                tonightCard(tonight)
            }
            if let lastNight = sleep.lastNight {
                lastNightCard(lastNight)
            } else if let message = sleep.noNightMessage {
                Text(message)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showsSleepPopup) {
            TodayPopupView(popup: .sleep, today: today, connection: connection)
        }
        // Back from the background, the tabs show today (spec 002); the popup described the Day
        // being left, so it closes, as on the Today tab.
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if oldPhase == .background, newPhase != .background { showsSleepPopup = false }
        }
    }

    /// Tonight (spec 011): when to be asleep, tonight's Sleep Need and the usual wake time, or
    /// that a bedtime needs more Nights.
    private func tonightCard(_ tonight: SleepTonight) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tonight").font(.footnote).foregroundStyle(.secondary)
            if let waiting = tonight.waitingText {
                Text(waiting).font(.subheadline)
            }
            if let beAsleepBy = tonight.beAsleepByText {
                Text(beAsleepBy).font(.title2.bold())
            }
            if let sleepNeed = tonight.sleepNeedText {
                Text(sleepNeed).font(.subheadline)
            }
            if let usualWake = tonight.usualWakeText {
                Text([usualWake, tonight.sleepDebtText].compactMap { $0 }.joined(separator: " "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .themeCard()
    }

    /// Last night (spec 011): its title, Time Asleep and the Sleep Score button, then Time in Bed.
    private func lastNightCard(_ lastNight: SleepLastNight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lastNight.title).font(.headline)
                    Text(lastNight.timeAsleepText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Sleep Score \u{203A}") { showsSleepPopup = true }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.accentSoft, in: Capsule())
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.accent)
            }
            if let chart = lastNight.chart {
                SleepChartView(chart: chart)
            } else if let notKept = lastNight.notKeptText {
                Text(notKept)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .multilineTextAlignment(.center)
            }
            if let inBed = lastNight.inBedText {
                Text(inBed)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let summary = lastNight.wakeSummary {
                VStack(alignment: .leading, spacing: 6) {
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    ForEach(lastNight.wakeBoutRows, id: \.start) { row in
                        HStack {
                            Text(row.startText)
                            Spacer()
                            Text(row.lengthText).foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .themeCard()
    }
}

/// Last night's chart (spec 011): the Heart Rate Trace as a line, broken at missing steps, with a
/// dotted line at Sleeping HR, over the sleep/wake band with Sleep Onset's and Final Wake's times.
private struct SleepChartView: View {
    let chart: SleepChart

    var body: some View {
        VStack(spacing: 4) {
            Canvas { context, size in
                let x = { (time: Date) -> CGFloat in xPosition(time, width: size.width) }
                let y = { (bpm: Double) -> CGFloat in
                    let span = chart.highestBPM - chart.lowestBPM
                    return size.height * (1 - (bpm - chart.lowestBPM) / span)
                }
                if let sleepingHR = chart.sleepingHR {
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y(sleepingHR)))
                    line.addLine(to: CGPoint(x: size.width, y: y(sleepingHR)))
                    context.stroke(
                        line,
                        with: .color(.secondary),
                        style: StrokeStyle(lineWidth: 1, dash: [1, 4])
                    )
                }
                var trace = Path()
                var penDown = false
                for step in chart.steps {
                    guard let bpm = step.bpm else {
                        penDown = false
                        continue
                    }
                    let point = CGPoint(x: x(step.middle), y: y(bpm))
                    if penDown { trace.addLine(to: point) } else { trace.move(to: point) }
                    penDown = true
                }
                context.stroke(trace, with: .color(.red), lineWidth: 1.8)
            }
            .frame(height: 140)
            .overlay(alignment: .topTrailing) {
                if let label = chart.sleepingHRLabel {
                    Text(label).font(.caption2).foregroundStyle(.secondary)
                }
            }
            band
            HStack {
                Text(chart.sleepOnsetText)
                Spacer()
                Text(chart.finalWakeText)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    /// Sleep Onset to Final Wake in the accent colour, each Wake Bout in amber.
    private var band: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.accentSoft)
                Capsule()
                    .fill(Theme.accent)
                    .frame(
                        width: xPosition(chart.asleepEnd, width: width)
                            - xPosition(chart.asleepStart, width: width)
                    )
                    .offset(x: xPosition(chart.asleepStart, width: width))
                ForEach(chart.wakeBouts, id: \.start) { bout in
                    Rectangle()
                        .fill(.orange)
                        .frame(
                            width: max(
                                3,
                                xPosition(bout.end, width: width)
                                    - xPosition(bout.start, width: width)
                            )
                        )
                        .offset(x: xPosition(bout.start, width: width))
                }
            }
        }
        .frame(height: 8)
    }

    /// Where `time` falls across `width`, from the chart's start to its end.
    private func xPosition(_ time: Date, width: CGFloat) -> CGFloat {
        let span = chart.end.timeIntervalSince(chart.start)
        guard span > 0 else { return 0 }
        return width * time.timeIntervalSince(chart.start) / span
    }
}
