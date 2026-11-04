import Foundation

/// Everything the Sleep tab shows for the Day shown (spec 012), worked out from the stored Nights
/// each time, never stored. The shell draws it.
public struct SleepView: Equatable, Sendable {
    /// The same week strip as the Today tab's for the same Day (spec 002, Week strip).
    public let weekStrip: WeekStrip
    /// A bedtime to aim for tonight; nil when the Day shown isn't today.
    public let tonight: SleepTonight?
    /// The 7 Days to the Day shown as lanes, each Night's chart inside its lane.
    public let week: SleepWeek
    /// The Night dated the Day shown in one sentence; nil when that Day has no Night.
    public let summary: SleepSummary?
    /// "No Night yet" for today, "No Night recorded" for an earlier Day, in place of the Summary;
    /// nil when there's a Night (spec 002, as on the Today tab).
    public let noNightMessage: String?
    /// What stood out about the Night dated the Day shown, up to three rows in order: Wake Bouts,
    /// bedtime, heart rate; empty when that Day has no Night.
    public let standouts: [SleepStandout]

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
        week = SleepWeek(
            to: day,
            isToday: isToday,
            nights: nights,
            timeZone: timeZone,
            birthYear: birthYear
        )
        let night = nights.first { $0.day == day }
        summary = night.map {
            SleepSummary(
                $0,
                label: isToday ? "Last night" : day.text,
                sleepNeed: SleepNeed(for: day, among: nights, birthYear: birthYear).sleepNeed,
                timeZone: timeZone
            )
        }
        noNightMessage = night != nil ? nil : TodayView.noNightMessage(isToday: isToday)
        standouts =
            night.map {
                SleepStandout.rows(for: $0, among: nights, isToday: isToday, timeZone: timeZone)
            } ?? []
    }
}

/// How many minutes `timeAsleep` falls short of `sleepNeed` (negative when over), each in whole
/// minutes as shown so the gap agrees with the times written; nil when either can't be shown.
func shortfallMinutes(timeAsleep: TimeInterval, sleepNeed: TimeInterval) -> Int? {
    guard let asleep = Int(exactly: (timeAsleep / 60).rounded()),
        let need = Int(exactly: (sleepNeed / 60).rounded())
    else { return nil }
    return need - asleep
}

/// The Sleep tab's Summary (spec 012, Summary): the Night dated the Day shown in one sentence,
/// its Time Asleep against its own Sleep Need.
public struct SleepSummary: Equatable, Sendable {
    /// "Last night" for today, else the Day's name as the week strip writes it.
    public let label: String
    /// e.g. "You slept 7h 45m, 15 minutes short of what you needed."
    public let sentence: String
    /// "23:00 – 07:00", Sleep Onset to Final Wake; nil when either is missing.
    public let onsetWakeText: String?

    /// How far Time Asleep must fall short of, or pass, Sleep Need before the sentence says so,
    /// minutes (spec 012: 15).
    static let aboutWithinMinutes = 15

    init(_ night: Night, label: String, sleepNeed: TimeInterval, timeZone: TimeZone) {
        self.label = label
        if let timeAsleep = night.plausibleTimeAsleep {
            let slept = "You slept \(durationText(timeAsleep))"
            if let gap = shortfallMinutes(timeAsleep: timeAsleep, sleepNeed: sleepNeed) {
                sentence =
                    if gap >= Self.aboutWithinMinutes {
                        "\(slept), \(Self.gapText(gap)) short of what you needed."
                    } else if -gap >= Self.aboutWithinMinutes {
                        "\(slept), \(Self.gapText(-gap)) more than you needed."
                    } else {
                        "\(slept), about what you needed."
                    }
            } else {
                sentence = "\(slept)."
            }
        } else {
            sentence = "Time Asleep wasn't worked out for this Night."
        }
        onsetWakeText =
            if let onset = night.sleepOnset, let wake = night.finalWake {
                "\(clockText(onset, in: timeZone)) \u{2013} \(clockText(wake, in: timeZone))"
            } else {
                nil
            }
    }

    /// "45 minutes" under an hour, "1h 51m" from an hour up (spec 012, Summary).
    private static func gapText(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes) minutes" : durationText(TimeInterval(minutes * 60))
    }
}

/// One row of the Sleep tab's What stood out (spec 012): a line and a smaller detail.
public struct SleepStandout: Equatable, Sendable {
    /// e.g. "Fell asleep 40 min later than usual".
    public let text: String
    /// e.g. "Usual 23:00, last night 23:40"; empty when there's nothing to add.
    public let detail: String

    /// How far from the usual Sleep Onset a bedtime must be to read "earlier" or "later" than
    /// usual, minutes (spec 012: more than 30).
    static let bedtimeOffMinutes = 30.0
    /// The fewest earlier Nights with a Sleep Onset the usual bedtime needs (spec 012, What stood
    /// out: 3).
    static let fewestBedtimeNights = 3

    /// The rows for `night`, each left out when its data is missing: Wake Bouts, bedtime against
    /// the usual Sleep Onset of the Nights dated D − 7 to D − 1, then heart rate.
    static func rows(for night: Night, among nights: [Night], isToday: Bool, timeZone: TimeZone)
        -> [SleepStandout]
    {
        var rows: [SleepStandout] = []
        if let woke = SleepLane.wakeText(of: night) {
            let bouts = (night.wakeBouts ?? []).sorted { $0.start < $1.start }
            let detail = bouts.map {
                "\(clockText($0.start, in: timeZone)) \u{00B7} \($0.minutes) min"
            }
            rows.append(SleepStandout(text: woke, detail: detail.joined(separator: " \u{00B7} ")))
        }
        if let bedtime = bedtimeRow(for: night, among: nights, isToday: isToday, timeZone: timeZone)
        {
            rows.append(bedtime)
        }
        if let sleepingHR = night.sleepingHR {
            rows.append(
                SleepStandout(
                    text: "Heart rate settled to \(Int(sleepingHR.rounded())) bpm",
                    detail: "Its lowest stretch: your Sleeping HR"
                )
            )
        }
        return rows
    }

    /// The bedtime row; nil without a Sleep Onset or with too few earlier Nights to have a usual.
    private static func bedtimeRow(
        for night: Night,
        among nights: [Night],
        isToday: Bool,
        timeZone: TimeZone
    ) -> SleepStandout? {
        let window = SleepNeed.window(before: night.day)
        let earlier = nights.filter { window.contains($0.day) }.compactMap(\.sleepOnset)
        guard let onset = night.sleepOnset, earlier.count >= fewestBedtimeNights else { return nil }
        // In whole minutes as each is shown, so the difference agrees with the two times written.
        let usual = ClockTime.median(of: earlier, in: timeZone).rounded(.down)
        let tonight = ClockTime.minutes(of: onset, in: timeZone).rounded(.down)
        // The shortest way round the clock, so 00:10 is 20 minutes after 23:50.
        let off = (tonight - usual).remainder(dividingBy: ClockTime.minutesPerDay)
        let text =
            if off > bedtimeOffMinutes {
                "Fell asleep \(Int(off)) min later than usual"
            } else if -off > bedtimeOffMinutes {
                "Fell asleep \(Int(-off)) min earlier than usual"
            } else {
                "Fell asleep around your usual time"
            }
        let which = isToday ? "last night" : "that night"
        return SleepStandout(
            text: text,
            detail:
                "Usual \(ClockTime.text(minutes: usual)), \(which) \(clockText(onset, in: timeZone))"
        )
    }
}

/// The Sleep tab's Tonight section (spec 012, Tonight): when to be asleep tonight to get the
/// Sleep Need of the Night that will be dated tomorrow, against the usual Final Wake.
public struct SleepTonight: Equatable, Sendable {
    /// "To get 8h 0m before your usual 07:00 wake, be asleep by 23:00.", or "A bedtime to aim for
    /// appears after 3 Nights" before there are enough Nights.
    public let sentence: String
    /// Your week's Tonight lane, Be asleep by to the usual wake; nil without a bedtime.
    public let lane: SleepTonightLane?

    /// The fewest Nights with a Final Wake in the week to today that a bedtime needs (spec 012:
    /// 3, as Sleep Consistency's median).
    static let fewestNights = 3

    init(today: Day, nights: [Night], timeZone: TimeZone, birthYear: Int?) {
        let tomorrow = today.adding(days: 1)
        // The week to today, D − 6 to D: Sleep Need's look-back for tomorrow's Night.
        let window = SleepNeed.window(before: tomorrow)
        let wakes = nights.filter { window.contains($0.day) }.compactMap(\.finalWake)
        guard wakes.count >= Self.fewestNights else {
            sentence = "A bedtime to aim for appears after \(Self.fewestNights) Nights"
            lane = nil
            return
        }
        let need = SleepNeed(for: tomorrow, among: nights, birthYear: birthYear)
        // In whole minutes as each is shown, so the three times always agree.
        let usualWake = ClockTime.median(of: wakes, in: timeZone).rounded(.down)
        let needMinutes = (need.sleepNeed / 60).rounded()
        let bedtime = ClockTime.wrapped(usualWake - needMinutes)
        let bedtimeText = ClockTime.text(minutes: bedtime)
        sentence =
            "To get \(durationText(need.sleepNeed)) before your usual "
            + "\(ClockTime.text(minutes: usualWake)) wake, be asleep by \(bedtimeText)."
        // A bedtime before noon is after midnight, on tomorrow's date.
        let bedtimeDay = bedtime < ClockTime.noonMinutes ? tomorrow : today
        lane = SleepTonightLane(
            start: bedtimeDay.date(atMinutes: Int(bedtime), in: timeZone),
            end: tomorrow.date(atMinutes: Int(usualWake), in: timeZone),
            text: bedtimeText
        )
    }
}

/// Your week's Tonight lane (spec 012): a dashed bar from tonight's Be asleep by to the usual wake
/// tomorrow morning.
public struct SleepTonightLane: Equatable, Sendable {
    /// UTC: tonight's Be asleep by.
    public let start: Date
    /// UTC: the usual wake time tomorrow morning.
    public let end: Date
    /// The Be asleep by time, e.g. "23:00".
    public let text: String
}

/// The Sleep tab's Your week section (spec 012, Your week): a lane for each of the 7 Days, the
/// Day shown first, on one clock axis.
public struct SleepWeek: Equatable, Sendable {
    /// "Your week".
    public let titleText: String
    /// "avg 7h 20m · Sleep Debt 2h 0m": the mean Time Asleep of the week's Nights and the week's
    /// Sleep Debt ("avg 7h 20m" alone with none); nil with no Night in the week.
    public let summaryText: String?
    /// Seven lanes, the Day shown first, then back to six Days before it.
    public let lanes: [SleepLane]
    /// The evening hour the axis starts: 20, or earlier in whole hours to fit a Night's Sleep
    /// Onset.
    public let axisStartHour: Int
    /// The morning hour the axis ends: 10, or later in whole hours to fit a Night's Final Wake.
    public let axisEndHour: Int
    /// The axis' labels, on the even clock hours inside it: "22", "00" … "08".
    public let axisLabels: [SleepAxisLabel]
    /// The lane open when the tab is shown: the Day shown when it has a Night, else none.
    public let firstOpenLane: Day?
    /// The time zone the axis was worked out in, so times are placed on it the same way.
    let timeZone: TimeZone

    /// How many Days Your week shows (spec 012: 7, D − 6 to D).
    static let length = 7
    /// The axis' usual start, an evening hour (spec 012: 20:00).
    static let usualStartHour = 20
    /// The axis' usual end, a morning hour (spec 012: 10:00).
    static let usualEndHour = 10
    /// Hours between the axis' labels (spec 012: every 2 hours).
    static let labelEveryHours = 2

    init(to shown: Day, isToday: Bool, nights: [Night], timeZone: TimeZone, birthYear: Int?) {
        let days = (0..<Self.length).map { shown.adding(days: -$0) }
        let weekNights = days.compactMap { day in nights.first { $0.day == day } }
        lanes = days.map { day in
            SleepLane(
                day: day,
                name: isToday && day == shown ? "Last" : day.weekdayName,
                night: nights.first { $0.day == day },
                nights: nights,
                birthYear: birthYear,
                timeZone: timeZone
            )
        }
        titleText = "Your week"
        let timesAsleep = weekNights.compactMap(\.plausibleTimeAsleep)
        // The week D − 6 to D is the look-back of the Night dated D + 1 (spec 009), as Tonight's
        // Sleep Need uses.
        let weekDebt = SleepNeed(for: shown.adding(days: 1), among: nights, birthYear: birthYear)
        summaryText =
            timesAsleep.isEmpty
            ? nil
            : Self.summaryText(
                average: timesAsleep.reduce(0, +) / Double(timesAsleep.count),
                sleepDebt: weekDebt.sleepDebt
            )
        firstOpenLane = weekNights.contains { $0.day == shown } ? shown : nil
        // Widened to whole hours for an evening Sleep Onset before 20:00 or a morning Final Wake
        // after 10:00.
        var start = Double(Self.usualStartHour * 60)
        var end = Double(Self.usualEndHour * 60)
        for night in weekNights {
            if let onset = night.sleepOnset {
                let minutes = ClockTime.minutes(of: onset, in: timeZone)
                if minutes >= ClockTime.noonMinutes { start = min(start, minutes) }
            }
            if let wake = night.finalWake {
                let minutes = ClockTime.minutes(of: wake, in: timeZone)
                if minutes < ClockTime.noonMinutes { end = max(end, minutes) }
            }
        }
        let startHour = Int((start / 60).rounded(.down))
        let endHour = Int((end / 60).rounded(.up))
        axisStartHour = startHour
        axisEndHour = endHour
        // Hours past the first midnight run on past 24, so the morning sits after the evening.
        let lastHour = endHour + 24
        axisLabels = ((startHour + 1)..<lastHour)
            .filter { $0 % Self.labelEveryHours == 0 }
            .map { hour in
                SleepAxisLabel(
                    text: hour % 24 < 10 ? "0\(hour % 24)" : "\(hour % 24)",
                    fraction: Double(hour - startHour) / Double(lastHour - startHour)
                )
            }
        self.timeZone = timeZone
    }

    /// "avg 7h 20m · Sleep Debt 2h 0m", or "avg 7h 20m" with no Sleep Debt (under a minute).
    private static func summaryText(average: TimeInterval, sleepDebt: TimeInterval) -> String {
        let averageText = "avg \(durationText(average))"
        guard let debtMinutes = Int(exactly: (sleepDebt / 60).rounded()), debtMinutes > 0 else {
            return averageText
        }
        return "\(averageText) · Sleep Debt \(durationText(sleepDebt))"
    }

    /// Where `time` falls on Your week's axis, 0 at its evening start to 1 at its morning end;
    /// morning times sit on the axis' second day.
    public func axisFraction(of time: Date) -> Double {
        var minutes = ClockTime.minutes(of: time, in: timeZone)
        if minutes < ClockTime.noonMinutes { minutes += ClockTime.minutesPerDay }
        let start = Double(axisStartHour * 60)
        let end = Double(axisEndHour * 60) + ClockTime.minutesPerDay
        return min(max((minutes - start) / (end - start), 0), 1)
    }
}

/// One label under Your week's lanes, e.g. "02", where it sits along the axis.
public struct SleepAxisLabel: Equatable, Sendable {
    public let text: String
    /// 0 at the axis' evening start to 1 at its morning end.
    public let fraction: Double
}

/// One Day's lane in Your week (spec 012): its Night's bar on the shared axis, or "no Night".
public struct SleepLane: Equatable, Sendable {
    public let day: Day
    /// "Last" for the Day shown when it's today, else the weekday's short name, e.g. "Mon".
    public let name: String
    /// "no Night" when the Day has no Night; nil otherwise.
    public let noNightText: String?
    /// Sleep Onset to Final Wake, split at each Wake Bout, UTC; empty with no Night.
    public let asleepSegments: [DateInterval]
    /// Time in Bed, drawn as a thin track under the bar; nil without one.
    public let timeInBed: DateInterval?
    /// The Night's Time Asleep, e.g. "6h 0m", "—" when not worked out; nil with no Night.
    public let timeAsleepText: String?
    /// Whether Time Asleep fell 15 min or more under the Night's own Sleep Need (spec 009).
    public let isShort: Bool
    /// The Night's Heart Rate Trace with its sleep/wake band, shown when the lane is open; nil
    /// with no Night or no Heart Rate Trace.
    public let chart: SleepChart?
    /// In place of the chart when the Night has no Heart Rate Trace; nil otherwise.
    public let notKeptText: String?
    /// Under the chart, e.g. "Woke 2 times · 15 min awake", "Didn't wake"; nil when the Night's
    /// Wake Bouts aren't kept.
    public let wakeText: String?

    /// How far under its Sleep Need a Night's Time Asleep is marked short, minutes (spec 012:
    /// 15, as the Summary's "short").
    static let shortByMinutes = SleepSummary.aboutWithinMinutes

    init(
        day: Day,
        name: String,
        night: Night?,
        nights: [Night],
        birthYear: Int?,
        timeZone: TimeZone
    ) {
        self.day = day
        chart = night.flatMap { SleepChart($0, timeZone: timeZone) }
        notKeptText =
            night != nil && night?.heartRateTrace == nil
            ? "Heart rate isn't kept for Nights older than 30 days." : nil
        wakeText = night.flatMap(Self.wakeText)
        self.name = name
        noNightText = night == nil ? "no Night" : nil
        asleepSegments = night.map(Self.asleepSegments) ?? []
        timeInBed = night.flatMap { night in
            guard let start = night.timeInBedStart, let end = night.timeInBedEnd, end > start
            else { return nil }
            return DateInterval(start: start, end: end)
        }
        let timeAsleep = night?.plausibleTimeAsleep
        timeAsleepText = night.map { _ in timeAsleep.map(durationText) ?? missingText }
        isShort =
            if let timeAsleep,
                let shortfall = shortfallMinutes(
                    timeAsleep: timeAsleep,
                    sleepNeed: SleepNeed(for: day, among: nights, birthYear: birthYear).sleepNeed
                )
            {
                shortfall >= Self.shortByMinutes
            } else {
                false
            }
    }

    /// "Woke 2 times · 15 min awake", "Didn't wake"; nil when the Wake Bouts aren't kept, or the
    /// Night has no Heart Rate Trace (spec 012, Not kept: the note stands in for all of it).
    static func wakeText(of night: Night) -> String? {
        guard night.heartRateTrace != nil, let bouts = night.wakeBouts else { return nil }
        if bouts.isEmpty { return "Didn't wake" }
        let woke = "Woke \(bouts.count) time\(bouts.count == 1 ? "" : "s")"
        // The Sleep popup's minutes awake (spec 002), which the Wake Bouts add up to; no total
        // where the Sleep popup has none ("—"), so the two never disagree.
        return night.minutesAwake.map { "\(woke) \u{00B7} \($0) min awake" } ?? woke
    }

    /// Sleep Onset to Final Wake with each Wake Bout cut out, oldest first.
    private static func asleepSegments(of night: Night) -> [DateInterval] {
        guard let onset = night.sleepOnset, let wake = night.finalWake, wake > onset else {
            return []
        }
        var segments: [DateInterval] = []
        var from = onset
        // A Night with no Heart Rate Trace has no gaps (spec 012, Not kept).
        let bouts = night.heartRateTrace == nil ? [] : night.wakeBouts ?? []
        for bout in bouts.sorted(by: { $0.start < $1.start }) {
            let boutStart = max(bout.start, onset)
            let boutEnd = min(bout.end, wake)
            guard boutEnd > boutStart else { continue }
            if boutStart > from { segments.append(DateInterval(start: from, end: boutStart)) }
            from = max(from, boutEnd)
        }
        if wake > from { segments.append(DateInterval(start: from, end: wake)) }
        return segments
    }
}

/// A Night's chart, opened in its lane (spec 012): the Heart Rate Trace against the Night's
/// Sleeping HR and bpm gridlines, over a sleep/wake band with hour ticks.
public struct SleepChart: Equatable, Sendable {
    /// UTC: the chart's left end, Time in Bed's start (or Sleep Onset without Time in Bed).
    public let start: Date
    /// UTC: the chart's right end, Time in Bed's end (or Final Wake without Time in Bed).
    public let end: Date
    /// The Heart Rate Trace's steps, oldest first.
    public let steps: [SleepChartStep]
    /// The y-axis' bottom, bpm: the lowest step or Sleeping HR − 3.
    public let lowestBPM: Double
    /// The y-axis' top, bpm: the highest step or Sleeping HR + 3.
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
    /// Faint lines across the chart, bpm, e.g. [50, 55, 60, 65, 70] on a 47–73 axis.
    public let gridlines: [Double]
    /// Under the band, on the even clock hours inside the chart: "00:00", "02:00" …
    public let hourTicks: [SleepChartTick]

    /// Room above and below the steps on the y-axis, bpm (spec 012: 3).
    static let axisMargin = 3.0
    /// Gridlines every this many bpm (spec 012: 5) …
    static let gridlineStep = 5.0
    /// … or every this many when the axis spans more than `wideAxisSpan` bpm (spec 012: 10, 30).
    static let wideGridlineStep = 10.0
    static let wideAxisSpan = 30.0
    /// Hours between ticks under the band, on even clock hours (spec 012: 2).
    static let tickEveryHours = 2

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
        // The steps and the Night's Sleeping HR, so its line is always on the chart (spec 012).
        let values = trace.steps.compactMap { $0 } + [night.sleepingHR].compactMap { $0 }
        lowestBPM = (values.min() ?? 0) - Self.axisMargin
        highestBPM = (values.max() ?? 0) + Self.axisMargin
        sleepingHR = night.sleepingHR
        sleepingHRLabel = night.sleepingHR.map { "Sleeping HR \(Int($0.rounded()))" }
        asleepStart = onset
        asleepEnd = wake
        wakeBouts = (night.wakeBouts ?? []).map { DateInterval(start: $0.start, end: $0.end) }
        let step =
            highestBPM - lowestBPM > Self.wideAxisSpan ? Self.wideGridlineStep : Self.gridlineStep
        gridlines = Array(
            stride(from: (lowestBPM / step).rounded(.up) * step, through: highestBPM, by: step)
        )
        hourTicks = Self.hourTicks(from: start, to: end, in: timeZone)
    }

    /// The whole local hours strictly between `start` and `end` that fall on an even clock hour.
    private static func hourTicks(from start: Date, to end: Date, in timeZone: TimeZone)
        -> [SleepChartTick]
    {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard
            var hour = calendar.nextDate(
                after: start,
                matching: DateComponents(minute: 0, second: 0),
                matchingPolicy: .nextTime
            )
        else { return [] }
        var ticks: [SleepChartTick] = []
        while hour < end {
            if calendar.component(.hour, from: hour) % tickEveryHours == 0 {
                ticks.append(SleepChartTick(time: hour, text: clockText(hour, in: timeZone)))
            }
            guard let next = calendar.date(byAdding: .hour, value: 1, to: hour) else { break }
            hour = next
        }
        return ticks
    }
}

/// One hour tick under a Night's chart.
public struct SleepChartTick: Equatable, Sendable {
    /// UTC.
    public let time: Date
    /// e.g. "02:00".
    public let text: String
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
