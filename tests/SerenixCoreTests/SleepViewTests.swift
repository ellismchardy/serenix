import Foundation
import SerenixCore
import Testing

// The Sleep tab's view (spec 012). Expected values are spec 012's success criteria under
// "Summary", "Your week", "A Night's lane and chart", "Tonight" and "What stood out", worked by
// hand from its rules.

/// 1–3 Nov 2026 is in GMT here (BST ended on 25 Oct), so local time equals UTC.
private let london = TimeZone(identifier: "Europe/London")!

private let oneHour: TimeInterval = 3_600

private let oneMinute: TimeInterval = 60

private let nov1 = Day(year: 2026, month: 11, day: 1)

private let nov3 = Day(year: 2026, month: 11, day: 3)

/// `hour`:`minute` UTC (and so London local time) on `month`/`day` 2026 (November by default).
private func at(month: Int = 11, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar.date(
        from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)
    )!
}

/// 3 Nov 2026 08:12 in London, so today is 3 Nov.
private let now = at(3, 8, 12)

/// A Heart Rate Trace from 22:50 (2 Nov) to 07:10 in 100 5-minute steps: the first 50 bpm, the
/// second 70, the third (from 23:00) missing, the rest 60.
private let traceFrom2250 = HeartRateTrace(
    start: at(2, 22, 50),
    steps: [50, 70, nil] + Array(repeating: 60, count: 97)
)

/// Wake Bouts at 02:10 for 8 minutes and 04:30 for 7 minutes.
private let twoWakeBouts = [
    WakeBout(start: at(3, 2, 10), minutes: 8),
    WakeBout(start: at(3, 4, 30), minutes: 7),
]

/// The Night dated 3 Nov: Time in Bed 22:50 (2 Nov) to 07:10, Sleep Onset `sleepOnset` (23:00 by
/// default), Final Wake 07:00, Time Asleep 7 h 45 m, Sleeping HR 52, `traceFrom2250` and
/// `twoWakeBouts`.
private func nightOn3Nov(
    sleepingHR: Double? = 52,
    sleepOnset: Date? = at(2, 23),
    timeAsleep: TimeInterval? = 7 * oneHour + 45 * oneMinute,
    timeInBedStart: Date? = at(2, 22, 50),
    timeInBedEnd: Date? = at(3, 7, 10),
    heartRateTrace: HeartRateTrace? = traceFrom2250,
    wakeBouts: [WakeBout]? = twoWakeBouts
) -> Night {
    Night(
        day: nov3,
        sleepingHR: sleepingHR,
        sleepOnset: sleepOnset,
        finalWake: at(3, 7),
        timeAsleep: timeAsleep,
        timeInBedStart: timeInBedStart,
        timeInBedEnd: timeInBedEnd,
        heartRateTrace: heartRateTrace,
        wakeBouts: wakeBouts
    )
}

/// A Night dated 1 Nov: Sleep Onset 23:00 (31 Oct), Final Wake 07:00, Time Asleep 7 h 45 m.
private let nightOn1Nov = Night(
    day: nov1,
    sleepOnset: at(1, 7) - 8 * oneHour,
    finalWake: at(1, 7),
    timeAsleep: 7 * oneHour + 45 * oneMinute
)

private func sleepView(nights: [Night], showing day: Day = nov3) -> SleepView {
    SleepView(nights: nights, showing: day, now: now, timeZone: london)
}

// MARK: Summary

// Spec 012's success criteria under "Summary": the 3 Nov Night (Sleep Onset 23:00, Final Wake
// 07:00) and Nights dated 27 Oct to 2 Nov each with Time Asleep 8 h, so its Sleep Need is 8h 0m
// (spec 009: no Sleep Debt in its week, no birth year).

/// The Nights dated 27 Oct to 2 Nov, each 23:00 to 07:00 with Time Asleep 8 h, and the 3 Nov
/// Night with `timeAsleep`.
private func summaryNights(timeAsleep: TimeInterval?) -> [Night] {
    (27...31).map { tonightNight(month: 10, $0, timeAsleep: 8 * oneHour) }
        + (1...2).map { tonightNight(month: 11, $0, timeAsleep: 8 * oneHour) }
        + [nightOn3Nov(timeAsleep: timeAsleep)]
}

@Test func theSummaryTodayIsLastNightFifteenMinutesShortWithItsSleepOnsetToFinalWake() throws {
    let view = sleepView(nights: summaryNights(timeAsleep: 7 * oneHour + 45 * oneMinute))
    let summary = try #require(view.summary)

    #expect(summary.label == "Last night")
    #expect(summary.sentence == "You slept 7h 45m, 15 minutes short of what you needed.")
    #expect(summary.onsetWakeText == "23:00 \u{2013} 07:00")
    #expect(view.noNightMessage == nil)
}

@Test func theSummaryWithinFifteenMinutesOfSleepNeedReadsAboutWhatYouNeeded() {
    let view = sleepView(nights: summaryNights(timeAsleep: 7 * oneHour + 50 * oneMinute))

    #expect(view.summary?.sentence == "You slept 7h 50m, about what you needed.")
}

@Test func theSummaryFifteenMinutesOrMoreOverSleepNeedReadsMoreThanYouNeeded() {
    let view = sleepView(nights: summaryNights(timeAsleep: 8 * oneHour + 30 * oneMinute))

    #expect(view.summary?.sentence == "You slept 8h 30m, 30 minutes more than you needed.")
}

/// From an hour up the gap reads in hours and minutes, "1h 0m" at exactly an hour.
@Test func theSummarysGapFromAnHourUpReadsInHoursAndMinutes() {
    let short = sleepView(nights: summaryNights(timeAsleep: 6 * oneHour + 9 * oneMinute))
    let anHourShort = sleepView(nights: summaryNights(timeAsleep: 7 * oneHour))

    #expect(short.summary?.sentence == "You slept 6h 9m, 1h 51m short of what you needed.")
    #expect(anHourShort.summary?.sentence == "You slept 7h 0m, 1h 0m short of what you needed.")
}

/// The gap is taken from the times as shown: 7 h 45 m 30 s reads "7h 46m", 14 minutes under a
/// Sleep Need of 8h 0m, so "about", not "15 minutes short" from the unrounded 14.5.
@Test func theSummarysGapIsTakenFromTimeAsleepAsShown() {
    let view = sleepView(nights: summaryNights(timeAsleep: 7 * oneHour + 45 * oneMinute + 30))

    #expect(view.summary?.sentence == "You slept 7h 46m, about what you needed.")
}

@Test func theSummaryWithNoTimeAsleepReadsThatItWasntWorkedOut() {
    let view = sleepView(nights: summaryNights(timeAsleep: nil))

    #expect(view.summary?.sentence == "Time Asleep wasn't worked out for this Night.")
}

@Test func aNightTodayIsSummarisedAsLastNight() {
    let view = sleepView(nights: [nightOn3Nov()])

    #expect(view.summary?.label == "Last night")
    #expect(view.summary?.sentence == "You slept 7h 45m, 15 minutes short of what you needed.")
    #expect(view.noNightMessage == nil)
}

/// The label is the Day's name as the week strip writes it (spec 002), "Sun 1 Nov".
@Test func theSummaryOnAnEarlierDayIsLabelledWithThatDaysName() {
    let view = sleepView(nights: [nightOn1Nov, nightOn3Nov()], showing: nov1)

    #expect(view.summary?.label == "Sun 1 Nov")
}

@Test func noNightTodayReadsNoNightYet() {
    let view = sleepView(nights: [nightOn1Nov])

    #expect(view.summary == nil)
    #expect(view.week.lanes.first?.chart == nil)
    #expect(view.noNightMessage == "No Night yet")
}

@Test func noNightOnAnEarlierDayReadsNoNightRecorded() {
    let view = sleepView(nights: [nightOn3Nov()], showing: nov1)

    #expect(view.summary == nil)
    #expect(view.week.lanes.first?.chart == nil)
    #expect(view.noNightMessage == "No Night recorded")
}

// MARK: A Night's chart

// Spec 012's success criteria under "A Night's lane and chart": the Night dated 3 Nov
// (`nightOn3Nov`), its chart in its lane, the first of Your week's lanes.

/// The chart in the lane of `nightOn3Nov`-like `night`, the Day shown's.
private func laneChart(_ night: Night) -> SleepChart? {
    sleepView(nights: [night]).week.lanes.first?.chart
}

@Test func aNightsChartRunsFromTimeInBedsStartToItsEndWithHourTicksEveryTwoHours() {
    let chart = laneChart(nightOn3Nov())

    #expect(chart?.start == at(2, 22, 50))
    #expect(chart?.end == at(3, 7, 10))
    #expect(chart?.hourTicks.map(\.text) == ["00:00", "02:00", "04:00", "06:00"])
    #expect(chart?.hourTicks.map(\.time) == [at(3, 0), at(3, 2), at(3, 4), at(3, 6)])
}

/// Each Night's lane carries its own chart, not only the Day shown's.
@Test func anEarlierNightsLaneCarriesItsOwnChart() {
    let nightOn2Nov = Night(
        day: Day(year: 2026, month: 11, day: 2),
        sleepingHR: 55,
        sleepOnset: at(1, 23),
        finalWake: at(2, 7),
        timeAsleep: 8 * oneHour,
        timeInBedStart: at(1, 22, 50),
        timeInBedEnd: at(2, 7, 10),
        heartRateTrace: HeartRateTrace(
            start: at(1, 22, 50),
            steps: Array(repeating: 60, count: 100)
        ),
        wakeBouts: []
    )
    let lanes = sleepView(nights: [nightOn2Nov, nightOn3Nov()]).week.lanes

    #expect(lanes.count == 7)
    let chart = lanes.dropFirst().first?.chart
    #expect(chart?.start == at(1, 22, 50))
    #expect(chart?.end == at(2, 7, 10))
    #expect(chart?.sleepingHRLabel == "55 bpm")
}

@Test func aNightsChartHasTheHeartRateTracesStepsFiveMinutesApart() {
    let steps = laneChart(nightOn3Nov())?.steps ?? []

    #expect(steps.count == 100)
    #expect(steps.first?.start == at(2, 22, 50))
    #expect(steps.first?.bpm == 50)
    #expect(steps.dropFirst().first?.start == at(2, 22, 55))
    #expect(steps.dropFirst().first?.bpm == 70)
    #expect(steps.last?.start == at(3, 7, 5))
    #expect(steps.last?.bpm == 60)
}

/// Each step is drawn at its middle (22:52:30 for the first), but never past the chart's end:
/// with Time in Bed ending 07:06, the last step (07:05) is drawn at 07:06, not 07:07:30.
@Test func eachChartStepIsDrawnAtItsMiddleWithinTheChart() {
    let steps = laneChart(nightOn3Nov(timeInBedEnd: at(3, 7, 6)))?.steps ?? []

    #expect(steps.first?.middle == at(2, 22, 52) + 30)
    #expect(steps.last?.middle == at(3, 7, 6))
}

@Test func aMissingStepBreaksTheChartsLine() {
    let steps = laneChart(nightOn3Nov())?.steps ?? []

    #expect(steps.count == 100)
    let third = steps.dropFirst(2).first
    #expect(third?.start == at(2, 23))
    #expect(third != nil && third?.bpm == nil)
}

@Test func theChartsYAxisRunsFromTheLowestStepLessThreeToTheHighestPlusThree() {
    let chart = laneChart(nightOn3Nov())

    #expect(chart?.lowestBPM == 47)
    #expect(chart?.highestBPM == 73)
}

/// A Sleeping HR below every step widens the y-axis to take it in, so its line stays on the
/// chart: steps 50 to 70 with Sleeping HR 44 run 41 to 73.
@Test func aSleepingHROutsideTheStepsWidensTheYAxis() {
    let chart = laneChart(nightOn3Nov(sleepingHR: 44))

    #expect(chart?.lowestBPM == 41)
    #expect(chart?.highestBPM == 73)
}

/// `value` rounded to 2 decimal places, as spec 012's smoothed values are given.
private func twoDP(_ value: Double?) -> Double? {
    value.map { ($0 * 100).rounded() / 100 }
}

/// 100 steps from 22:50, all 60 but the 51st (index 50, 03:00), which is 74: far enough from both
/// ends that every step within 3 of it is 60.
private let traceWithOne74 = HeartRateTrace(
    start: at(2, 22, 50),
    steps: Array(repeating: 60, count: 50) + [74] + Array(repeating: 60, count: 49)
)

/// Spec 012's criterion: steps all 60 but one of 74 draw that step at 63.58, the steps 1, 2 and 3
/// away at 62.95, 61.64 and 60.62, and the rest at 60.
@Test func eachChartStepIsDrawnAtItsSmoothedValue() throws {
    let steps = laneChart(nightOn3Nov(sleepingHR: 60, heartRateTrace: traceWithOne74))?.steps ?? []

    try #require(steps.count == 100)
    let smoothed = steps.map { twoDP($0.smoothedBPM) }
    #expect(smoothed[50] == 63.58)
    #expect(smoothed[49] == 62.95)
    #expect(smoothed[51] == 62.95)
    #expect(smoothed[48] == 61.64)
    #expect(smoothed[52] == 61.64)
    #expect(smoothed[47] == 60.62)
    #expect(smoothed[53] == 60.62)
    let rest = Array(smoothed[..<47]) + Array(smoothed[54...])
    #expect(rest.count == 93)
    #expect(rest.allSatisfy { $0 == 60 })
}

/// Smoothing is for drawing only: the y-axis still runs from the steps as kept (60 to 74: 57 to
/// 77), not the smoothed values (60 to 63.58). Sleeping HR 60 lies inside the steps.
@Test func theChartsYAxisRunsFromTheStepsAsKeptNotTheSmoothedValues() {
    let chart = laneChart(nightOn3Nov(sleepingHR: 60, heartRateTrace: traceWithOne74))

    #expect(chart?.lowestBPM == 57)
    #expect(chart?.highestBPM == 77)
    #expect(chart?.steps.dropFirst(50).first?.bpm == 74)
}

/// Spec 012's criterion: a missing step among 60s stays missing and its neighbours draw at 60
/// (the missing step is left out of their means, not counted as 0).
@Test func aMissingStepStaysMissingWhenSmoothedAndItsNeighboursDrawAt60() throws {
    let trace = HeartRateTrace(
        start: at(2, 22, 50),
        steps: Array(repeating: 60, count: 50) + [nil] + Array(repeating: 60, count: 49)
    )
    let steps = laneChart(nightOn3Nov(sleepingHR: 60, heartRateTrace: trace))?.steps ?? []

    try #require(steps.count == 100)
    let missing = steps.dropFirst(50).first
    #expect(missing != nil && missing?.smoothedBPM == nil)
    let smoothed = steps.map { twoDP($0.smoothedBPM) }
    #expect(smoothed[49] == 60)
    #expect(smoothed[51] == 60)
    let rest = Array(smoothed[..<50]) + Array(smoothed[51...])
    #expect(rest.allSatisfy { $0 == 60 })
}

/// Near the trace's start a step has fewer than 3 steps on one side, so its mean is over the
/// steps that exist. Weights w_d = e^(−d²/(2·1.6²)) = e^(−d²/5.12): w0 = 1, w1 = 0.82258,
/// w2 = 0.45783, w3 = 0.17242. Steps 74, 60, 60, 60, …:
/// - first step (no steps before it): (74·1 + 60·(w1 + w2 + w3)) / (1 + w1 + w2 + w3)
///   = 60 + 14 / 2.45283 = 65.708 → 65.71;
/// - second step (one before it, the 74 at d = 1; three after it):
///   (74·w1 + 60·(1 + w1 + w2 + w3)) / (w1 + 1 + w1 + w2 + w3)
///   = 60 + 14·0.82258 / 3.27541 = 63.516 → 63.52.
@Test func aStepNearTheTracesStartIsSmoothedOverTheStepsThatExist() throws {
    let trace = HeartRateTrace(
        start: at(2, 22, 50),
        steps: [74] + Array(repeating: 60, count: 99)
    )
    let steps = laneChart(nightOn3Nov(sleepingHR: 60, heartRateTrace: trace))?.steps ?? []

    try #require(steps.count == 100)
    #expect(twoDP(steps.first?.smoothedBPM) == 65.71)
    #expect(twoDP(steps.dropFirst().first?.smoothedBPM) == 63.52)
}

/// Steps 44 to 80 give a 41 to 83 axis, the lowest step − 3 to the highest + 3.
@Test func stepsFrom44To80GiveAYAxisFrom41To83() {
    let trace = HeartRateTrace(
        start: at(2, 22, 50),
        steps: [44, 80] + Array(repeating: 60, count: 98)
    )
    let chart = laneChart(nightOn3Nov(heartRateTrace: trace))

    #expect(chart?.lowestBPM == 41)
    #expect(chart?.highestBPM == 83)
}

@Test func theSleepingHRLineIsAtTheNightsSleepingHRWithItsBPMTag() {
    let chart = laneChart(nightOn3Nov())

    #expect(chart?.sleepingHR == 52)
    #expect(chart?.sleepingHRLabel == "52 bpm")
}

@Test func withNoSleepingHRThereIsNoSleepingHRLineOrLabel() {
    let chart = laneChart(nightOn3Nov(sleepingHR: nil))

    #expect(chart != nil)
    #expect(chart?.sleepingHR == nil)
    #expect(chart?.sleepingHRLabel == nil)
}

@Test func theAsleepShadingRunsSleepOnsetToFinalWakeLabelledWithWakeBoutsAndHowOftenTheyWoke() {
    let lane = sleepView(nights: [nightOn3Nov()]).week.lanes.first

    #expect(lane?.chart?.asleepStart == at(2, 23))
    #expect(lane?.chart?.asleepEnd == at(3, 7))
    #expect(lane?.chart?.asleepStartText == "asleep 23:00")
    #expect(lane?.chart?.asleepEndText == "07:00")
    #expect(
        lane?.chart?.wakeBouts == [
            DateInterval(start: at(3, 2, 10), end: at(3, 2, 18)),
            DateInterval(start: at(3, 4, 30), end: at(3, 4, 37)),
        ]
    )
    #expect(lane?.wakeText == "Woke 2 times \u{00B7} 15 min awake")
    #expect(lane?.notKeptText == nil)
}

/// Spec 012: the total is the Sleep popup's minutes awake (Final Wake − Sleep Onset − Time
/// Asleep), not the Wake Bouts' own sum: Time Asleep 7 h 40 m gives 20 though the bouts add to 15.
@Test func theWokeTextsTotalIsTheSleepPopupsMinutesAwake() {
    let night = nightOn3Nov(timeAsleep: 7 * oneHour + 40 * oneMinute)
    let lane = sleepView(nights: [night]).week.lanes.first

    #expect(lane?.wakeText == "Woke 2 times \u{00B7} 20 min awake")
}

/// Where the Sleep popup has no minutes awake (Time Asleep implausible), the "Woke" text gives no
/// total either, so the two never disagree.
@Test func withNoMinutesAwakeTheWokeTextHasNoTotal() {
    let night = nightOn3Nov(timeAsleep: -oneHour)
    let lane = sleepView(nights: [night]).week.lanes.first

    #expect(lane?.wakeText == "Woke 2 times")
}

@Test func oneWakeBoutReadsWokeOneTime() {
    // Time Asleep 7 h 52 m, so the minutes awake (8 h − 7 h 52 m) are the one Wake Bout's 8.
    let night = nightOn3Nov(
        timeAsleep: 7 * oneHour + 52 * oneMinute,
        wakeBouts: [WakeBout(start: at(3, 2, 10), minutes: 8)]
    )
    let lane = sleepView(nights: [night]).week.lanes.first

    #expect(lane?.wakeText == "Woke 1 time \u{00B7} 8 min awake")
}

@Test func noWakeBoutsReadsDidntWake() {
    let night = nightOn3Nov(timeAsleep: 8 * oneHour, wakeBouts: [])
    let lane = sleepView(nights: [night]).week.lanes.first

    #expect(lane?.wakeText == "Didn't wake")
    #expect(lane?.chart?.wakeBouts == [])
}

/// With a Heart Rate Trace but no Wake Bouts kept, the chart shows and there's no "Woke" text.
@Test func withNoWakeBoutsKeptThereIsNoWokeText() {
    let lane = sleepView(nights: [nightOn3Nov(wakeBouts: nil)]).week.lanes.first

    #expect(lane?.chart != nil)
    #expect(lane?.wakeText == nil)
}

@Test func withNoTimeInBedTheChartRunsFromSleepOnsetToFinalWakeAndTheBlockHasNoTrack() {
    let view = sleepView(nights: [nightOn3Nov(timeInBedStart: nil, timeInBedEnd: nil)])
    let lane = view.week.lanes.first

    #expect(lane?.chart?.start == at(2, 23))
    #expect(lane?.chart?.end == at(3, 7))
    #expect(lane != nil && lane?.timeInBed == nil)
    #expect(view.summary?.sentence == "You slept 7h 45m, 15 minutes short of what you needed.")
}

@Test func withNoHeartRateTraceTheChartIsReplacedByTheNotKeptNoteAndTheBlockHasNoNotches() {
    let night = nightOn3Nov(heartRateTrace: nil, wakeBouts: nil)
    let lane = sleepView(nights: [night]).week.lanes.first

    #expect(lane?.notKeptText == "Heart rate isn't kept for Nights older than 30 days.")
    #expect(lane != nil && lane?.chart == nil)
    #expect(lane?.wakeText == nil)
    #expect(lane?.asleep == DateInterval(start: at(2, 23), end: at(3, 7)))
    #expect(lane?.wakeNotches == [])
    #expect(lane?.timeAsleepText == "7h 45m")
}

/// The not-kept rule follows the Heart Rate Trace: with Wake Bouts still on the Night, its block
/// still has no notches and there's no "Woke" text (spec 012, Not kept).
@Test func withNoHeartRateTraceButWakeBoutsTheBlockStillHasNoNotchesOrWokeText() {
    let lane = sleepView(nights: [nightOn3Nov(heartRateTrace: nil)]).week.lanes.first

    #expect(lane?.notKeptText == "Heart rate isn't kept for Nights older than 30 days.")
    #expect(lane?.wakeText == nil)
    #expect(lane?.asleep == DateInterval(start: at(2, 23), end: at(3, 7)))
    #expect(lane?.wakeNotches == [])
}

/// Hour ticks sit strictly inside the chart: Time in Bed 22:00–08:00 has none at 22:00 or 08:00.
@Test func aChartsHourTicksAreNeverAtItsEnds() {
    let night = nightOn3Nov(timeInBedStart: at(2, 22), timeInBedEnd: at(3, 8))

    #expect(laneChart(night)?.hourTicks.map(\.text) == ["00:00", "02:00", "04:00", "06:00"])
}

// MARK: Sleep tab

@Test func theWeekStripIsTheSameAsTodaysForTheSameDay() {
    let nights = [nightOn1Nov, nightOn3Nov()]
    let today = TodayView(
        nights: nights,
        dayLoads: [],
        showing: nov1,
        now: now,
        timeZone: london,
        sync: .idle
    )

    #expect(sleepView(nights: nights, showing: nov1).weekStrip == today.weekStrip)
}

// MARK: Tonight

// Spec 012's success criteria under "Tonight": Nights dated 28 Oct to 3 Nov, each Sleep Onset
// 23:00 the evening before. London is on GMT throughout (BST ended on 25 Oct), so local = UTC.

/// The Night dated `month`/`day` 2026: Sleep Onset 23:00 the evening before, Final Wake
/// `wakeHour`:`wakeMinute`, and `timeAsleep`.
private func tonightNight(
    month: Int,
    _ day: Int,
    wakeHour: Int = 7,
    wakeMinute: Int = 0,
    timeAsleep: TimeInterval
) -> Night {
    Night(
        day: Day(year: 2026, month: month, day: day),
        sleepOnset: at(month: month, day, 0) - oneHour,
        finalWake: at(month: month, day, wakeHour, wakeMinute),
        timeAsleep: timeAsleep
    )
}

/// The seven Nights dated 28 Oct to 3 Nov, each Final Wake 07:00 with `timeAsleep`.
private func weekOfNights(timeAsleep: TimeInterval) -> [Night] {
    (28...31).map { tonightNight(month: 10, $0, timeAsleep: timeAsleep) }
        + (1...3).map { tonightNight(month: 11, $0, timeAsleep: timeAsleep) }
}

@Test func tonightWithNoSleepDebtIsUsualWakeLessUsualNeed() throws {
    let tonight = try #require(sleepView(nights: weekOfNights(timeAsleep: 8 * oneHour)).tonight)

    #expect(tonight.sentence == "To get 8h 0m before your usual 07:00 wake, be asleep by 23:00.")
}

@Test func tonightsLaneRunsFromBeAsleepByTonightToTheUsualWakeTomorrow() throws {
    let tonight = try #require(sleepView(nights: weekOfNights(timeAsleep: 8 * oneHour)).tonight)
    let lane = try #require(tonight.lane)

    #expect(lane.start == at(3, 23))
    #expect(lane.end == at(4, 7))
    #expect(lane.text == "23:00")
}

/// Sleep Debt 7 h (1 h short each Night) would add 1 h 45 m, but Sleep Need is capped at 9 h.
@Test func tonightWithSleepDebtAimsEarlier() throws {
    let tonight = try #require(sleepView(nights: weekOfNights(timeAsleep: 7 * oneHour)).tonight)

    #expect(tonight.sentence == "To get 9h 0m before your usual 07:00 wake, be asleep by 22:00.")
}

@Test func tonightsLaneWithSleepDebtStartsEarlier() throws {
    let tonight = try #require(sleepView(nights: weekOfNights(timeAsleep: 7 * oneHour)).tonight)
    let lane = try #require(tonight.lane)

    #expect(lane.start == at(3, 22))
    #expect(lane.end == at(4, 7))
    #expect(lane.text == "22:00")
}

@Test func tonightsUsualWakeTimeIsTheMedianFinalWake() {
    let nights = [
        tonightNight(month: 11, 1, wakeHour: 6, wakeMinute: 50, timeAsleep: 8 * oneHour),
        tonightNight(month: 11, 2, wakeHour: 7, wakeMinute: 10, timeAsleep: 8 * oneHour),
        tonightNight(month: 11, 3, wakeHour: 7, wakeMinute: 0, timeAsleep: 8 * oneHour),
    ]
    let tonight = sleepView(nights: nights).tonight

    #expect(
        tonight?.sentence == "To get 8h 0m before your usual 07:00 wake, be asleep by 23:00."
    )
}

@Test func withFewerThanThreeNightsTonightReadsOnlyThatABedtimeAppearsAfterThree() throws {
    let nights = [
        tonightNight(month: 11, 2, timeAsleep: 8 * oneHour),
        tonightNight(month: 11, 3, timeAsleep: 8 * oneHour),
    ]
    let tonight = try #require(sleepView(nights: nights).tonight)

    #expect(tonight.sentence == "A bedtime to aim for appears after 3 Nights")
    #expect(tonight.lane == nil)
}

@Test func anEarlierDayShownHasNoTonight() {
    let nights = weekOfNights(timeAsleep: 8 * oneHour)

    #expect(sleepView(nights: nights, showing: Day(year: 2026, month: 11, day: 2)).tonight == nil)
}

/// An even count of Final Wakes averages the middle two: 07:00 and 07:01 give 07:00:30, shown cut
/// to 07:00, and the bedtime is worked out from the time shown, so the two agree (23:00).
@Test func anEvenCountOfFinalWakesAveragesTheMiddleTwoAndTheTimesAgree() throws {
    let nights = [
        tonightNight(month: 10, 31, wakeHour: 7, wakeMinute: 0, timeAsleep: 8 * oneHour),
        tonightNight(month: 11, 1, wakeHour: 7, wakeMinute: 0, timeAsleep: 8 * oneHour),
        tonightNight(month: 11, 2, wakeHour: 7, wakeMinute: 1, timeAsleep: 8 * oneHour),
        tonightNight(month: 11, 3, wakeHour: 7, wakeMinute: 1, timeAsleep: 8 * oneHour),
    ]
    let tonight = try #require(sleepView(nights: nights).tonight)

    #expect(tonight.sentence == "To get 8h 0m before your usual 07:00 wake, be asleep by 23:00.")
}

/// The bedtime wraps round midnight: a usual wake of 06:00 with Sleep Need 9 h is 21:00.
@Test func theBedtimeWrapsRoundMidnight() throws {
    let nights =
        (28...31).map {
            tonightNight(month: 10, $0, wakeHour: 6, timeAsleep: 7 * oneHour)
        }
        + (1...3).map { tonightNight(month: 11, $0, wakeHour: 6, timeAsleep: 7 * oneHour) }
    let tonight = try #require(sleepView(nights: nights).tonight)

    #expect(tonight.sentence == "To get 9h 0m before your usual 06:00 wake, be asleep by 21:00.")
    #expect(tonight.lane?.start == at(3, 21))
    #expect(tonight.lane?.end == at(4, 6))
}

/// A bedtime after midnight puts the Tonight lane's start on tomorrow's date: born 1950 (76, so
/// Usual Need 7h 30m, spec 009), each Night 7h 30m asleep (no Sleep Debt) waking 08:00, so be
/// asleep by 00:30 on 4 Nov.
@Test func aBedtimeAfterMidnightStartsTonightsLaneTomorrow() throws {
    let nights =
        (28...31).map {
            tonightNight(month: 10, $0, wakeHour: 8, timeAsleep: 7.5 * oneHour)
        }
        + (1...3).map { tonightNight(month: 11, $0, wakeHour: 8, timeAsleep: 7.5 * oneHour) }
    let view = SleepView(nights: nights, showing: nov3, now: now, timeZone: london, birthYear: 1950)
    let tonight = try #require(view.tonight)

    #expect(tonight.sentence == "To get 7h 30m before your usual 08:00 wake, be asleep by 00:30.")
    #expect(tonight.lane?.start == at(4, 0, 30))
    #expect(tonight.lane?.end == at(4, 8))
    #expect(tonight.lane?.text == "00:30")
}

// MARK: Your week

// Spec 012's success criteria under "Your week": Nights dated 1 Nov (Time Asleep 6 h), 2 and
// 3 Nov (8 h), each Sleep Onset 23:00 the evening before, Final Wake 07:00, Time in Bed
// 22:50–07:10. No birth year, so Usual Need is 8 h.

/// The Night dated `month`/`day` 2026: Time in Bed 22:50 (the evening before) to 07:10, Sleep
/// Onset 23:00, Final Wake 07:00, and `timeAsleep`.
private func weekNight(month: Int = 11, _ day: Int, timeAsleep: TimeInterval) -> Night {
    Night(
        day: Day(year: 2026, month: month, day: day),
        sleepOnset: at(month: month, day, 0) - oneHour,
        finalWake: at(month: month, day, 7),
        timeAsleep: timeAsleep,
        timeInBedStart: at(month: month, day, 0) - oneHour - 10 * oneMinute,
        timeInBedEnd: at(month: month, day, 7, 10)
    )
}

/// The Nights dated 1 Nov (Time Asleep 6 h), 2 Nov and 3 Nov (8 h).
private let yourWeekNights = [
    weekNight(1, timeAsleep: 6 * oneHour),
    weekNight(2, timeAsleep: 8 * oneHour),
    weekNight(3, timeAsleep: 8 * oneHour),
]

@Test func yourWeekHasSevenLanesFromTheDayShownBackToSixDaysBefore() {
    let lanes = sleepView(nights: yourWeekNights).week.lanes

    #expect(
        lanes.map(\.day) == [
            Day(year: 2026, month: 11, day: 3),
            Day(year: 2026, month: 11, day: 2),
            Day(year: 2026, month: 11, day: 1),
            Day(year: 2026, month: 10, day: 31),
            Day(year: 2026, month: 10, day: 30),
            Day(year: 2026, month: 10, day: 29),
            Day(year: 2026, month: 10, day: 28),
        ]
    )
}

/// Today's lane is "Last"; the rest are their weekdays' short names (3 Nov 2026 is a Tuesday).
@Test func yourWeeksLanesAreNamedLastThenByWeekday() {
    let lanes = sleepView(nights: yourWeekNights).week.lanes

    #expect(lanes.map(\.name) == ["Last", "Mon", "Sun", "Sat", "Fri", "Thu", "Wed"])
}

@Test func yourWeekDaysWithNoNightReadNoNightAndHaveNoBlock() {
    let lanes = sleepView(nights: yourWeekNights).week.lanes

    #expect(lanes.count == 7)
    let noNightTexts: [String?] = [nil, nil, nil, "no Night", "no Night", "no Night", "no Night"]
    #expect(lanes.map(\.noNightText) == noNightTexts)
    for lane in lanes.suffix(4) {
        #expect(lane.timeAsleepText == nil)
        #expect(lane.asleep == nil)
        #expect(lane.wakeNotches.isEmpty)
        #expect(lane.timeInBed == nil)
        #expect(lane.isShort == false)
        #expect(lane.chart == nil)
        #expect(lane.notKeptText == nil)
        #expect(lane.wakeText == nil)
    }
}

/// The mean Time Asleep of 6 h, 8 h and 8 h is 7 h 20 m; 1 Nov's 2 h short of Usual Need is the
/// week's Sleep Debt (spec 009).
@Test func yourWeeksTitleReadsTheAverageTimeAsleepAndTheWeeksSleepDebt() {
    let week = sleepView(nights: yourWeekNights).week

    #expect(week.titleText == "Your week")
    #expect(week.summaryText == "avg 7h 20m \u{00B7} Sleep Debt 2h 0m")
}

/// No Night falls short of Usual Need, so there's no Sleep Debt to write.
@Test func withNoSleepDebtYourWeeksTitleReadsOnlyTheAverage() {
    let nights = [
        weekNight(1, timeAsleep: 8 * oneHour),
        weekNight(2, timeAsleep: 8 * oneHour),
        weekNight(3, timeAsleep: 8 * oneHour),
    ]
    let week = sleepView(nights: nights).week

    #expect(week.titleText == "Your week")
    #expect(week.summaryText == "avg 8h 0m")
}

@Test func withNoNightInTheWeekYourWeeksTitleReadsOnlyYourWeek() {
    let week = sleepView(nights: []).week

    #expect(week.titleText == "Your week")
    #expect(week.summaryText == nil)
    let noNightTexts: [String?] = Array(repeating: "no Night", count: 7)
    #expect(week.lanes.map(\.noNightText) == noNightTexts)
}

/// A Night whose Time Asleep wasn't worked out still has its block; its Time Asleep reads "—" and
/// it isn't marked short. With no Time Asleep in the week there's no Sleep Debt either, so the
/// title reads only "Your week".
@Test func aNightWithNoTimeAsleepReadsADashAndIsntShort() {
    var night = weekNight(3, timeAsleep: 8 * oneHour)
    night.timeAsleep = nil
    let week = sleepView(nights: [night]).week

    #expect(week.lanes.first?.timeAsleepText == "\u{2014}")
    #expect(week.lanes.first?.isShort == false)
    #expect(week.lanes.first?.asleep == DateInterval(start: at(2, 23), end: at(3, 7)))
    #expect(week.summaryText == nil)
}

/// Without Wake Bouts each Night's block runs Sleep Onset to Final Wake with no notches, on its
/// Time in Bed track.
@Test func eachNightsBlockRunsFromSleepOnsetToFinalWakeOnItsTimeInBedTrack() {
    let lanes = sleepView(nights: yourWeekNights).week.lanes

    #expect(lanes.count == 7)
    let blocks: [DateInterval?] = [
        DateInterval(start: at(2, 23), end: at(3, 7)),
        DateInterval(start: at(1, 23), end: at(2, 7)),
        DateInterval(start: at(month: 10, 31, 23), end: at(1, 7)),
    ]
    #expect(lanes.prefix(3).map(\.asleep) == blocks)
    let noNotches: [[DateInterval]] = [[], [], []]
    #expect(lanes.prefix(3).map(\.wakeNotches) == noNotches)
    let tracks: [DateInterval?] = [
        DateInterval(start: at(2, 22, 50), end: at(3, 7, 10)),
        DateInterval(start: at(1, 22, 50), end: at(2, 7, 10)),
        DateInterval(start: at(month: 10, 31, 22, 50), end: at(1, 7, 10)),
    ]
    #expect(lanes.prefix(3).map(\.timeInBed) == tracks)
}

@Test func yourWeeksAxisRunsTwentyToTenLabelledEveryTwoHours() {
    let week = sleepView(nights: yourWeekNights).week

    #expect(week.axisStartHour == 20)
    #expect(week.axisEndHour == 10)
    #expect(week.axisLabels.map(\.text) == ["22", "00", "02", "04", "06", "08"])
}

/// On the 20:00–10:00 axis (14 h), 23:00 sits 3/14 of the way along and 07:00 the next morning
/// 11/14.
@Test func yourWeekPlacesEachTimeAlongTheAxis() {
    let week = sleepView(nights: yourWeekNights).week

    #expect(week.axisFraction(of: at(2, 23)) == 3.0 / 14)
    #expect(week.axisFraction(of: at(3, 7)) == 11.0 / 14)
}

/// A Final Wake after 10:00 widens the axis' end to the next whole hour (10:15 → 11:00); a Sleep
/// Onset after midnight is a morning time and leaves its start at 20:00.
@Test func aLateFinalWakeWidensTheAxisEndAndAnOnsetAfterMidnightDoesNot() {
    let lateNight = Night(
        day: Day(year: 2026, month: 10, day: 31),
        sleepOnset: at(month: 10, 31, 0, 30),
        finalWake: at(month: 10, 31, 10, 15),
        timeAsleep: 8 * oneHour
    )
    let week = sleepView(nights: yourWeekNights + [lateNight]).week

    #expect(week.axisStartHour == 20)
    #expect(week.axisEndHour == 11)
}

@Test func aNightFromNineteenThirtyWidensYourWeeksAxisToNineteen() {
    let earlyNight = Night(
        day: Day(year: 2026, month: 10, day: 31),
        sleepOnset: at(month: 10, 30, 19, 30),
        finalWake: at(month: 10, 31, 7),
        timeAsleep: 8 * oneHour
    )
    let week = sleepView(nights: [earlyNight] + yourWeekNights).week

    #expect(week.axisStartHour == 19)
    #expect(week.axisEndHour == 10)
}

/// Each Night's own Sleep Need (spec 009): 1 Nov has no Nights before it, so 8h 0m; 2 and 3 Nov
/// each repay 1 Nov's 2 h of Sleep Debt, so 8h 30m. All three fall 15 min or more short.
@Test func eachNightsTimeAsleepIsMarkedShortAgainstItsOwnSleepNeed() {
    let lanes = sleepView(nights: yourWeekNights).week.lanes

    #expect(lanes.count == 7)
    let timeAsleepTexts: [String?] = ["8h 0m", "8h 0m", "6h 0m"]
    #expect(lanes.prefix(3).map(\.timeAsleepText) == timeAsleepTexts)
    #expect(lanes.prefix(3).map(\.isShort) == [true, true, true])
}

/// 3 Nov's Sleep Need is 8h 30m: 8 h 15 m is 15 min short, so marked; 8 h 16 m is 14 min short,
/// so not.
@Test func aNightIsMarkedShortFromFifteenMinutesUnderItsSleepNeed() {
    let fifteenShort = sleepView(nights: [
        weekNight(1, timeAsleep: 6 * oneHour),
        weekNight(2, timeAsleep: 8 * oneHour),
        weekNight(3, timeAsleep: 8 * oneHour + 15 * oneMinute),
    ])
    let fourteenShort = sleepView(nights: [
        weekNight(1, timeAsleep: 6 * oneHour),
        weekNight(2, timeAsleep: 8 * oneHour),
        weekNight(3, timeAsleep: 8 * oneHour + 16 * oneMinute),
    ])

    #expect(fifteenShort.week.lanes.first?.isShort == true)
    #expect(fourteenShort.week.lanes.first?.isShort == false)
}

@Test func theDayShownsLaneOpensFirst() {
    #expect(sleepView(nights: yourWeekNights).week.firstOpenLane == nov3)
}

@Test func withNoNightOnTheDayShownNoLaneOpensFirst() {
    let week = sleepView(nights: Array(yourWeekNights.prefix(2))).week

    #expect(week.firstOpenLane == nil)
}

/// 2 Nov 2026 is a Monday; it isn't today, so its lane takes its weekday's name.
@Test func withAnEarlierDayShownYourWeeksLanesRunBackFromIt() {
    let lanes =
        sleepView(nights: yourWeekNights, showing: Day(year: 2026, month: 11, day: 2)).week.lanes

    #expect(lanes.count == 7)
    #expect(lanes.first?.day == Day(year: 2026, month: 11, day: 2))
    #expect(lanes.last?.day == Day(year: 2026, month: 10, day: 27))
    #expect(lanes.first?.name == "Mon")
}

// MARK: A Night's lane

/// Spec 012, "A Night's lane and chart": the block runs Sleep Onset to Final Wake unbroken, with a
/// notch at each Wake Bout (02:10 for 8 min, 04:30 for 7 min), on the Time in Bed track.
@Test func aNightsBlockIsUnbrokenWithANotchAtEachWakeBoutOnItsTimeInBedTrack() {
    let lane = sleepView(nights: [nightOn3Nov()]).week.lanes.first

    #expect(lane?.asleep == DateInterval(start: at(2, 23), end: at(3, 7)))
    #expect(
        lane?.wakeNotches == [
            DateInterval(start: at(3, 2, 10), end: at(3, 2, 18)),
            DateInterval(start: at(3, 4, 30), end: at(3, 4, 37)),
        ]
    )
    #expect(lane?.timeInBed == DateInterval(start: at(2, 22, 50), end: at(3, 7, 10)))
}

/// Wake Bouts stored out of order still give their notches oldest first.
@Test func aNightsNotchesRunOldestFirstWhateverOrderItsWakeBoutsAreIn() {
    let night = nightOn3Nov(wakeBouts: [
        WakeBout(start: at(3, 4, 30), minutes: 7),
        WakeBout(start: at(3, 2, 10), minutes: 8),
    ])
    let lane = sleepView(nights: [night]).week.lanes.first

    #expect(
        lane?.wakeNotches == [
            DateInterval(start: at(3, 2, 10), end: at(3, 2, 18)),
            DateInterval(start: at(3, 4, 30), end: at(3, 4, 37)),
        ]
    )
}

/// A Wake Bout at 06:55 for 10 min runs past Final Wake (07:00), so its notch stops at 07:00,
/// inside the block.
@Test func aWakeBoutRunningPastFinalWakeHasItsNotchClampedToTheBlock() {
    let night = nightOn3Nov(wakeBouts: [WakeBout(start: at(3, 6, 55), minutes: 10)])
    let lane = sleepView(nights: [night]).week.lanes.first

    #expect(lane?.asleep == DateInterval(start: at(2, 23), end: at(3, 7)))
    #expect(lane?.wakeNotches == [DateInterval(start: at(3, 6, 55), end: at(3, 7))])
    // The chart's column for it is clamped the same way, so the two never disagree.
    #expect(lane?.chart?.wakeBouts == [DateInterval(start: at(3, 6, 55), end: at(3, 7))])
}

// MARK: What stood out

// Spec 012's success criteria under "What stood out": the 3 Nov Night (`nightOn3Nov`) and Nights
// dated 28 Oct to 2 Nov each with Sleep Onset 23:00 the evening before (`tonightNight`).

/// The Nights dated 28 Oct to 2 Nov, each Sleep Onset 23:00 the evening before.
private let sixEarlierNights =
    (28...31).map { tonightNight(month: 10, $0, timeAsleep: 8 * oneHour) }
    + (1...2).map { tonightNight(month: 11, $0, timeAsleep: 8 * oneHour) }

@Test func whatStoodOutReadsWakeBoutsThenBedtimeThenHeartRate() {
    let standouts = sleepView(nights: sixEarlierNights + [nightOn3Nov()]).standouts

    #expect(
        standouts.map(\.text) == [
            "Woke 2 times \u{00B7} 15 min awake",
            "Fell asleep around your usual time",
            "Heart rate settled to 52 bpm",
        ]
    )
    #expect(
        standouts.map(\.detail) == [
            "02:10 \u{00B7} 8 min \u{00B7} 04:30 \u{00B7} 7 min",
            "Usual 23:00, last night 23:00",
            "Its lowest stretch: your Sleeping HR",
        ]
    )
}

/// The bedtime row with 3 Nov's Sleep Onset at `sleepOnset`, against a usual 23:00.
private func bedtimeStandout(sleepOnset: Date) -> SleepStandout? {
    let night = nightOn3Nov(sleepOnset: sleepOnset)
    return sleepView(nights: sixEarlierNights + [night]).standouts
        .first { $0.text.hasPrefix("Fell asleep") }
}

@Test func fallingAsleepFortyMinutesAfterTheUsualSleepOnsetReadsLaterThanUsual() {
    let row = bedtimeStandout(sleepOnset: at(2, 23, 40))

    #expect(row?.text == "Fell asleep 40 min later than usual")
    #expect(row?.detail == "Usual 23:00, last night 23:40")
}

@Test func fallingAsleepFortyMinutesBeforeTheUsualSleepOnsetReadsEarlierThanUsual() {
    #expect(
        bedtimeStandout(sleepOnset: at(2, 22, 20))?.text == "Fell asleep 40 min earlier than usual"
    )
}

/// 30 minutes apart is not "more than 30 min apart".
@Test func fallingAsleepThirtyMinutesFromTheUsualSleepOnsetIsAroundYourUsualTime() {
    #expect(
        bedtimeStandout(sleepOnset: at(2, 23, 30))?.text == "Fell asleep around your usual time"
    )
}

/// With an earlier Day shown, the detail names "that night": 2 Nov shown, against the Nights dated
/// 26 Oct to 1 Nov.
@Test func theBedtimeRowOnAnEarlierDaySaysThatNight() {
    let nights =
        (26...31).map { tonightNight(month: 10, $0, timeAsleep: 8 * oneHour) }
        + (1...2).map { tonightNight(month: 11, $0, timeAsleep: 8 * oneHour) }
    let view = sleepView(nights: nights, showing: Day(year: 2026, month: 11, day: 2))

    #expect(view.standouts.map(\.text) == ["Fell asleep around your usual time"])
    #expect(view.standouts.map(\.detail) == ["Usual 23:00, that night 23:00"])
}

@Test func withOnlyTwoEarlierNightsThereIsNoBedtimeRow() {
    let nights = [
        tonightNight(month: 11, 1, timeAsleep: 8 * oneHour),
        tonightNight(month: 11, 2, timeAsleep: 8 * oneHour),
        nightOn3Nov(),
    ]

    #expect(
        sleepView(nights: nights).standouts.map(\.text) == [
            "Woke 2 times \u{00B7} 15 min awake",
            "Heart rate settled to 52 bpm",
        ]
    )
}

/// Without a Sleep Onset there's no minutes awake either (spec 002), so the Wake Bouts row reads
/// without a total, as under the chart.
@Test func withNoSleepOnsetThereIsNoBedtimeRow() {
    let view = sleepView(nights: sixEarlierNights + [nightOn3Nov(sleepOnset: nil)])

    #expect(
        view.standouts.map(\.text) == [
            "Woke 2 times",
            "Heart rate settled to 52 bpm",
        ]
    )
}

@Test func withNoWakeBoutsKeptThereIsNoWakeBoutsRow() {
    let view = sleepView(nights: sixEarlierNights + [nightOn3Nov(wakeBouts: nil)])

    #expect(
        view.standouts.map(\.text) == [
            "Fell asleep around your usual time",
            "Heart rate settled to 52 bpm",
        ]
    )
}

/// The not-kept rule follows the Heart Rate Trace, as under the chart: Wake Bouts still on the
/// Night give no Wake Bouts row without a Heart Rate Trace.
@Test func withNoHeartRateTraceThereIsNoWakeBoutsRow() {
    let view = sleepView(nights: sixEarlierNights + [nightOn3Nov(heartRateTrace: nil)])

    #expect(
        view.standouts.map(\.text) == [
            "Fell asleep around your usual time",
            "Heart rate settled to 52 bpm",
        ]
    )
}

@Test func withNoSleepingHRThereIsNoHeartRateRow() {
    let view = sleepView(nights: sixEarlierNights + [nightOn3Nov(sleepingHR: nil)])

    #expect(
        view.standouts.map(\.text) == [
            "Woke 2 times \u{00B7} 15 min awake",
            "Fell asleep around your usual time",
        ]
    )
}

@Test func withNoNightOnTheDayShownThereIsNoWhatStoodOut() {
    #expect(sleepView(nights: sixEarlierNights).standouts.isEmpty)
}

/// The bedtime is compared the shortest way round the clock: against a usual 23:50, 00:10 is 20
/// minutes later ("around"), 00:40 is 50 minutes later.
@Test func theBedtimeRowComparesRoundMidnightTheShortWay() {
    let earlier =
        (28...31).map { day in
            Night(
                day: Day(year: 2026, month: 10, day: day),
                sleepOnset: at(month: 10, day, 0) - 10 * oneMinute
            )
        }
        + (1...2).map { day in
            Night(
                day: Day(year: 2026, month: 11, day: day),
                sleepOnset: at(day, 0) - 10 * oneMinute
            )
        }
    let row = { (onset: Date) in
        sleepView(nights: earlier + [nightOn3Nov(sleepOnset: onset)]).standouts
            .first { $0.text.hasPrefix("Fell asleep") }
    }

    #expect(row(at(3, 0, 10))?.text == "Fell asleep around your usual time")
    #expect(row(at(3, 0, 10))?.detail == "Usual 23:50, last night 00:10")
    #expect(row(at(3, 0, 40))?.text == "Fell asleep 50 min later than usual")
}

/// The Wake Bouts row lists them oldest first, whatever order the Night holds them in.
@Test func theWakeBoutsRowListsThemOldestFirst() {
    let night = nightOn3Nov(wakeBouts: twoWakeBouts.reversed())

    #expect(
        sleepView(nights: sixEarlierNights + [night]).standouts.first?.detail
            == "02:10 \u{00B7} 8 min \u{00B7} 04:30 \u{00B7} 7 min"
    )
}

/// A Night with its Wake Bouts kept but none reads "Didn't wake", with nothing more to add.
@Test func aNightWithNoWakeBoutsReadsDidntWakeWithNoDetail() {
    let night = nightOn3Nov(wakeBouts: [])
    let first = sleepView(nights: sixEarlierNights + [night]).standouts.first

    #expect(first?.text == "Didn't wake")
    #expect(first?.detail == "")
}
