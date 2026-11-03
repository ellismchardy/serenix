import Foundation

/// Everything the Sleep tab shows for the Day shown (spec 011), worked out from the stored Nights
/// each time, never stored. The shell draws it.
public struct SleepView: Equatable, Sendable {
    /// The same week strip as the Today tab's for the same Day (spec 002, Week strip).
    public let weekStrip: WeekStrip
    /// A bedtime to aim for tonight; nil when the Day shown isn't today.
    public let tonight: SleepTonight?
    /// About the Night dated the Day shown; nil when that Day has no Night.
    public let lastNight: SleepLastNight?
    /// "No Night yet" for today, "No Night recorded" for an earlier Day, in place of Last night;
    /// nil when there's a Night (spec 002, as on the Today tab).
    public let noNightMessage: String?

    /// `birthYear` is the Profile's, for Sleep Need (spec 009).
    public init(
        nights: [Night],
        showing day: Day,
        now: Date,
        timeZone: TimeZone,
        birthYear: Int? = nil
    ) {
        let today = Day(containing: now, in: timeZone)
        let isToday = day == today
        weekStrip = WeekStrip(
            showing: day,
            today: today,
            earliest: WeekStrip.earliest(among: nights, today: today),
            nights: Set(nights.map(\.day))
        )
        tonight =
            isToday
            ? SleepTonight(today: day, nights: nights, timeZone: timeZone, birthYear: birthYear)
            : nil
        let night = nights.first { $0.day == day }
        lastNight = night.map {
            SleepLastNight($0, title: isToday ? "Last night" : day.text, timeZone: timeZone)
        }
        noNightMessage = night != nil ? nil : TodayView.noNightMessage(isToday: isToday)
    }
}

/// The Sleep tab's Tonight section (spec 011, Tonight): when to be asleep tonight to get the
/// Sleep Need of the Night that will be dated tomorrow, against the usual Final Wake.
public struct SleepTonight: Equatable, Sendable {
    /// e.g. "Be asleep by 23:00"; nil before there are enough Nights.
    public let beAsleepByText: String?
    /// e.g. "Sleep Need 8h 0m"; nil before there are enough Nights.
    public let sleepNeedText: String?
    /// e.g. "You usually wake at 07:00"; nil before there are enough Nights.
    public let usualWakeText: String?
    /// e.g. "· 2h 0m of Sleep Debt this week"; nil with no Sleep Debt or before enough Nights.
    public let sleepDebtText: String?
    /// "A bedtime to aim for appears after 3 Nights" in place of the rest; nil once there's one.
    public let waitingText: String?

    /// The fewest Nights with a Final Wake in the week to today that a bedtime needs (spec 011:
    /// 3, as Sleep Consistency's median).
    static let fewestNights = 3

    init(today: Day, nights: [Night], timeZone: TimeZone, birthYear: Int?) {
        let tomorrow = today.adding(days: 1)
        // The week to today, D − 6 to D: Sleep Need's look-back for tomorrow's Night.
        let window = SleepNeed.window(before: tomorrow)
        let wakes = nights.filter { window.contains($0.day) }.compactMap(\.finalWake)
        guard wakes.count >= Self.fewestNights else {
            beAsleepByText = nil
            sleepNeedText = nil
            usualWakeText = nil
            sleepDebtText = nil
            waitingText = "A bedtime to aim for appears after \(Self.fewestNights) Nights"
            return
        }
        let need = SleepNeed(for: tomorrow, among: nights, birthYear: birthYear)
        // In whole minutes as each is shown, so the three times always agree.
        let usualWake = ClockTime.median(of: wakes, in: timeZone).rounded(.down)
        let needMinutes = (need.sleepNeed / 60).rounded()
        beAsleepByText = "Be asleep by \(ClockTime.text(minutes: usualWake - needMinutes))"
        sleepNeedText = "Sleep Need \(durationText(need.sleepNeed))"
        usualWakeText = "You usually wake at \(ClockTime.text(minutes: usualWake))"
        sleepDebtText =
            need.sleepDebt > 0
            ? "\u{00B7} \(durationText(need.sleepDebt)) of Sleep Debt this week" : nil
        waitingText = nil
    }
}

/// The Sleep tab's Last night section, about one Night (spec 011, Last night).
public struct SleepLastNight: Equatable, Sendable {
    /// "Last night" when the Day shown is today, else the Day, e.g. "Sun 1 Nov".
    public let title: String
    /// e.g. "7h 45m asleep"; "— asleep" without a Time Asleep.
    public let timeAsleepText: String
    /// e.g. "In bed 22:50 · Up 07:10", from Time in Bed; nil without it.
    public let inBedText: String?
    /// The Heart Rate Trace with its sleep/wake band; nil when the Night has no Heart Rate Trace.
    public let chart: SleepChart?
    /// e.g. "Woke 2 times · 15 min awake", "Didn't wake"; nil with no chart or no Wake Bouts kept.
    public let wakeSummary: String?
    /// One per Wake Bout, oldest first; empty with none, or none kept.
    public let wakeBoutRows: [SleepWakeBoutRow]
    /// In place of the chart, band and Wake Bouts when the Night has no Heart Rate Trace.
    public let notKeptText: String?

    init(_ night: Night, title: String, timeZone: TimeZone) {
        self.title = title
        timeAsleepText = "\(night.plausibleTimeAsleep.map(durationText) ?? missingText) asleep"
        inBedText = night.timeInBedStart.flatMap { start in
            night.timeInBedEnd.map { end in
                "In bed \(clockText(start, in: timeZone)) \u{00B7} Up \(clockText(end, in: timeZone))"
            }
        }
        chart = SleepChart(night, timeZone: timeZone)
        notKeptText = chart == nil ? "Heart rate isn't kept for Nights older than 30 days." : nil
        let bouts = chart == nil ? [] : night.wakeBouts ?? []
        wakeBoutRows = bouts.map {
            SleepWakeBoutRow(
                start: $0.start,
                startText: clockText($0.start, in: timeZone),
                lengthText: "\($0.minutes) min"
            )
        }
        let woke = "Woke \(bouts.count) time\(bouts.count == 1 ? "" : "s")"
        wakeSummary =
            if chart == nil || night.wakeBouts == nil {
                nil
            } else if bouts.isEmpty {
                "Didn't wake"
            } else if let awake = night.minutesAwake {
                // The Sleep popup's minutes awake (spec 002), which the Wake Bouts add up to.
                "\(woke) \u{00B7} \(awake) min awake"
            } else {
                // No total where the Sleep popup has none ("—"), so the two never disagree.
                woke
            }
    }
}

/// One Wake Bout in Last night's list (spec 011).
public struct SleepWakeBoutRow: Equatable, Sendable {
    /// UTC: when it started; unique, unlike its clock text across a clock change.
    public let start: Date
    /// When it started, e.g. "02:10".
    public let startText: String
    /// How long it lasted, e.g. "8 min".
    public let lengthText: String
}

/// Last night's chart (spec 011): the Heart Rate Trace against the Night's Sleeping HR, over a
/// sleep/wake band.
public struct SleepChart: Equatable, Sendable {
    /// UTC: the chart's left end, Time in Bed's start (or Sleep Onset without Time in Bed).
    public let start: Date
    /// UTC: the chart's right end, Time in Bed's end (or Final Wake without Time in Bed).
    public let end: Date
    /// The Heart Rate Trace's steps, oldest first.
    public let steps: [SleepChartStep]
    /// The y-axis' bottom, bpm: the lowest step − 3.
    public let lowestBPM: Double
    /// The y-axis' top, bpm: the highest step + 3.
    public let highestBPM: Double
    /// Where the dotted line goes, bpm; nil without a Sleeping HR.
    public let sleepingHR: Double?
    /// e.g. "Sleeping HR 52"; nil without a Sleeping HR.
    public let sleepingHRLabel: String?
    /// UTC: the band's asleep stretch, Sleep Onset to Final Wake.
    public let asleepStart: Date
    /// UTC: the band's asleep stretch's end, Final Wake.
    public let asleepEnd: Date
    /// Each Wake Bout over the band, start to end; empty with none, or none kept.
    public let wakeBouts: [DateInterval]
    /// Under the band's ends, e.g. "23:00" and "07:00".
    public let sleepOnsetText: String
    /// Under the band's right end, e.g. "07:00".
    public let finalWakeText: String

    /// Room above and below the steps on the y-axis, bpm (spec 011: 3).
    static let axisMargin = 3.0

    /// Nil without a Heart Rate Trace, or without Sleep Onset and Final Wake for the band.
    init?(_ night: Night, timeZone: TimeZone) {
        guard let trace = night.heartRateTrace, let onset = night.sleepOnset,
            let wake = night.finalWake
        else { return nil }
        start = night.timeInBedStart ?? onset
        end = night.timeInBedEnd ?? wake
        let chartEnd = night.timeInBedEnd ?? wake
        steps = trace.steps.enumerated().map { index, bpm in
            let stepStart = trace.start + Double(index) * HeartRateTrace.step
            // Drawn at its middle; the last step may be shorter, so never past the chart's end.
            let middle = min(stepStart + HeartRateTrace.step / 2, max(chartEnd, stepStart))
            return SleepChartStep(start: stepStart, middle: middle, bpm: bpm)
        }
        // With every step missing there's no line, and the axis is only −3 to 3.
        let values = trace.steps.compactMap { $0 }
        lowestBPM = (values.min() ?? 0) - Self.axisMargin
        highestBPM = (values.max() ?? 0) + Self.axisMargin
        sleepingHR = night.sleepingHR
        sleepingHRLabel = night.sleepingHR.map { "Sleeping HR \(Int($0.rounded()))" }
        asleepStart = onset
        asleepEnd = wake
        wakeBouts = (night.wakeBouts ?? []).map { DateInterval(start: $0.start, end: $0.end) }
        sleepOnsetText = clockText(onset, in: timeZone)
        finalWakeText = clockText(wake, in: timeZone)
    }
}

/// One 5-minute step of the chart's line.
public struct SleepChartStep: Equatable, Sendable {
    /// UTC.
    public let start: Date
    /// UTC: where the step is drawn, its middle (never past the chart's end).
    public let middle: Date
    /// Nil where the step is missing, which breaks the line.
    public let bpm: Double?
}
