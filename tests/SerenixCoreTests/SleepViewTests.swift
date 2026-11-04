import Foundation
import SerenixCore
import Testing

// The Sleep tab's view (spec 012, Behavior: Sleep tab, Last night). Expected values are spec
// 011's success criteria under "Last night", worked by hand from its rules.

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

/// The Night dated 3 Nov: Time in Bed 22:50 (2 Nov) to 07:10, Sleep Onset 23:00, Final Wake
/// 07:00, Time Asleep 7 h 45 m, Sleeping HR 52, `traceFrom2250` and `twoWakeBouts`.
private func nightOn3Nov(
    sleepingHR: Double? = 52,
    timeAsleep: TimeInterval? = 7 * oneHour + 45 * oneMinute,
    timeInBedStart: Date? = at(2, 22, 50),
    timeInBedEnd: Date? = at(3, 7, 10),
    heartRateTrace: HeartRateTrace? = traceFrom2250,
    wakeBouts: [WakeBout]? = twoWakeBouts
) -> Night {
    Night(
        day: nov3,
        sleepingHR: sleepingHR,
        sleepOnset: at(2, 23),
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

// MARK: Last night

@Test func lastNightTodayIsSummarisedAndReadsInBedUp() {
    let view = sleepView(nights: [nightOn3Nov()])

    // Last night's old title and "7h 45m asleep" header are now the Summary's (spec 012).
    #expect(view.summary?.label == "Last night")
    #expect(view.summary?.sentence == "You slept 7h 45m, 15 minutes short of what you needed.")
    #expect(view.lastNight?.inBedText == "In bed 22:50 \u{00B7} Up 07:10")
    #expect(view.noNightMessage == nil)
}

@Test func lastNightsChartRunsFromTimeInBedsStartToItsEnd() {
    let chart = sleepView(nights: [nightOn3Nov()]).lastNight?.chart

    #expect(chart?.start == at(2, 22, 50))
    #expect(chart?.end == at(3, 7, 10))
}

@Test func lastNightsChartHasTheHeartRateTracesStepsFiveMinutesApart() {
    let steps = sleepView(nights: [nightOn3Nov()]).lastNight?.chart?.steps ?? []

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
    let steps =
        sleepView(nights: [nightOn3Nov(timeInBedEnd: at(3, 7, 6))]).lastNight?.chart?.steps
        ?? []

    #expect(steps.first?.middle == at(2, 22, 52) + 30)
    #expect(steps.last?.middle == at(3, 7, 6))
}

@Test func aMissingStepBreaksTheChartsLine() {
    let steps = sleepView(nights: [nightOn3Nov()]).lastNight?.chart?.steps ?? []

    #expect(steps.count == 100)
    let third = steps.dropFirst(2).first
    #expect(third?.start == at(2, 23))
    #expect(third != nil && third?.bpm == nil)
}

@Test func theChartsYAxisRunsFromTheLowestStepLessThreeToTheHighestPlusThree() {
    let chart = sleepView(nights: [nightOn3Nov()]).lastNight?.chart

    #expect(chart?.lowestBPM == 47)
    #expect(chart?.highestBPM == 73)
}

/// A Sleeping HR below every step widens the y-axis to take it in, so its line stays on the
/// chart: steps 50 to 70 with Sleeping HR 44 run 41 to 73.
@Test func aSleepingHROutsideTheStepsWidensTheYAxis() {
    let chart = sleepView(nights: [nightOn3Nov(sleepingHR: 44)]).lastNight?.chart

    #expect(chart?.lowestBPM == 41)
    #expect(chart?.highestBPM == 73)
}

@Test func theSleepingHRLineIsAtTheNightsSleepingHRAndLabelled() {
    let chart = sleepView(nights: [nightOn3Nov()]).lastNight?.chart

    #expect(chart?.sleepingHR == 52)
    #expect(chart?.sleepingHRLabel == "Sleeping HR 52")
}

@Test func withNoSleepingHRThereIsNoSleepingHRLineOrLabel() {
    let chart = sleepView(nights: [nightOn3Nov(sleepingHR: nil)]).lastNight?.chart

    #expect(chart != nil)
    #expect(chart?.sleepingHR == nil)
    #expect(chart?.sleepingHRLabel == nil)
}

@Test func theSleepWakeBandRunsFromSleepOnsetToFinalWakeWithEachWakeBout() {
    let chart = sleepView(nights: [nightOn3Nov()]).lastNight?.chart

    #expect(chart?.asleepStart == at(2, 23))
    #expect(chart?.asleepEnd == at(3, 7))
    #expect(
        chart?.wakeBouts == [
            DateInterval(start: at(3, 2, 10), end: at(3, 2, 18)),
            DateInterval(start: at(3, 4, 30), end: at(3, 4, 37)),
        ]
    )
    #expect(chart?.sleepOnsetText == "23:00")
    #expect(chart?.finalWakeText == "07:00")
}

@Test func theWakeBoutsListReadsHowOftenAndHowLongWithARowPerWakeBout() {
    let lastNight = sleepView(nights: [nightOn3Nov()]).lastNight

    #expect(lastNight?.wakeSummary == "Woke 2 times \u{00B7} 15 min awake")
    #expect(lastNight?.wakeBoutRows.map(\.startText) == ["02:10", "04:30"])
    #expect(lastNight?.wakeBoutRows.map(\.lengthText) == ["8 min", "7 min"])
    #expect(lastNight?.notKeptText == nil)
}

/// Spec 012: the total is the Sleep popup's minutes awake (Final Wake − Sleep Onset − Time
/// Asleep), not the Wake Bouts' own sum: Time Asleep 7 h 40 m gives 20 though the bouts add to 15.
@Test func theWakeBoutsTotalIsTheSleepPopupsMinutesAwake() {
    let night = nightOn3Nov(timeAsleep: 7 * oneHour + 40 * oneMinute)
    let lastNight = sleepView(nights: [night]).lastNight

    #expect(lastNight?.wakeSummary == "Woke 2 times \u{00B7} 20 min awake")
}

/// Where the Sleep popup has no minutes awake (Time Asleep implausible), the list gives no total
/// either, so the two never disagree.
@Test func withNoMinutesAwakeTheWakeBoutsHaveNoTotal() {
    let night = nightOn3Nov(timeAsleep: -oneHour)
    let lastNight = sleepView(nights: [night]).lastNight

    #expect(lastNight?.wakeSummary == "Woke 2 times")
}

@Test func oneWakeBoutReadsWokeOneTime() {
    // Time Asleep 7 h 52 m, so the minutes awake (8 h − 7 h 52 m) are the one Wake Bout's 8.
    let night = nightOn3Nov(
        timeAsleep: 7 * oneHour + 52 * oneMinute,
        wakeBouts: [WakeBout(start: at(3, 2, 10), minutes: 8)]
    )
    let lastNight = sleepView(nights: [night]).lastNight

    #expect(lastNight?.wakeSummary == "Woke 1 time \u{00B7} 8 min awake")
    #expect(lastNight?.wakeBoutRows.map(\.startText) == ["02:10"])
    #expect(lastNight?.wakeBoutRows.map(\.lengthText) == ["8 min"])
}

@Test func noWakeBoutsReadsDidntWake() {
    let night = nightOn3Nov(timeAsleep: 8 * oneHour, wakeBouts: [])
    let lastNight = sleepView(nights: [night]).lastNight

    #expect(lastNight?.wakeSummary == "Didn't wake")
    #expect(lastNight?.wakeBoutRows.isEmpty == true)
    #expect(lastNight?.chart?.wakeBouts == [])
}

@Test func withNoHeartRateTraceTheChartAndWakeBoutsAreReplacedByTheNotKeptNote() {
    let night = nightOn3Nov(heartRateTrace: nil, wakeBouts: nil)
    let view = sleepView(nights: [night])
    let lastNight = view.lastNight

    #expect(lastNight?.notKeptText == "Heart rate isn't kept for Nights older than 30 days.")
    #expect(lastNight?.chart == nil)
    #expect(lastNight?.wakeSummary == nil)
    #expect(lastNight?.wakeBoutRows.isEmpty == true)
    #expect(view.summary?.sentence == "You slept 7h 45m, 15 minutes short of what you needed.")
    #expect(lastNight?.inBedText == "In bed 22:50 \u{00B7} Up 07:10")
}

@Test func lastNightWithNoTimeInBedHasNoInBedUp() {
    let view = sleepView(nights: [nightOn3Nov(timeInBedStart: nil, timeInBedEnd: nil)])

    #expect(view.lastNight?.inBedText == nil)
    #expect(view.summary?.sentence == "You slept 7h 45m, 15 minutes short of what you needed.")
    #expect(view.lastNight?.chart?.start == at(2, 23))
    #expect(view.lastNight?.chart?.end == at(3, 7))
}

/// The label is the Day's name as the week strip writes it (spec 002), "Sun 1 Nov".
@Test func theSummaryOnAnEarlierDayIsLabelledWithThatDaysName() {
    let view = sleepView(nights: [nightOn1Nov, nightOn3Nov()], showing: nov1)

    #expect(view.summary?.label == "Sun 1 Nov")
}

@Test func noNightTodayReadsNoNightYet() {
    let view = sleepView(nights: [nightOn1Nov])

    #expect(view.summary == nil)
    #expect(view.lastNight == nil)
    #expect(view.noNightMessage == "No Night yet")
}

@Test func noNightOnAnEarlierDayReadsNoNightRecorded() {
    let view = sleepView(nights: [nightOn3Nov()], showing: nov1)

    #expect(view.summary == nil)
    #expect(view.lastNight == nil)
    #expect(view.noNightMessage == "No Night recorded")
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

    #expect(tonight.beAsleepByText == "Be asleep by 23:00")
    #expect(tonight.sleepNeedText == "Sleep Need 8h 0m")
    #expect(tonight.usualWakeText == "You usually wake at 07:00")
    #expect(tonight.sleepDebtText == nil)
    #expect(tonight.waitingText == nil)
}

/// Sleep Debt 7 h (1 h short each Night) would add 1 h 45 m, but Sleep Need is capped at 9 h.
@Test func tonightWithSleepDebtAimsEarlierAndShowsTheSleepDebt() throws {
    let tonight = try #require(sleepView(nights: weekOfNights(timeAsleep: 7 * oneHour)).tonight)

    #expect(tonight.beAsleepByText == "Be asleep by 22:00")
    #expect(tonight.sleepNeedText == "Sleep Need 9h 0m")
    #expect(tonight.usualWakeText == "You usually wake at 07:00")
    #expect(tonight.sleepDebtText == "\u{00B7} 7h 0m of Sleep Debt this week")
    #expect(tonight.waitingText == nil)
}

@Test func tonightsUsualWakeTimeIsTheMedianFinalWake() {
    let nights = [
        tonightNight(month: 11, 1, wakeHour: 6, wakeMinute: 50, timeAsleep: 8 * oneHour),
        tonightNight(month: 11, 2, wakeHour: 7, wakeMinute: 10, timeAsleep: 8 * oneHour),
        tonightNight(month: 11, 3, wakeHour: 7, wakeMinute: 0, timeAsleep: 8 * oneHour),
    ]
    let tonight = sleepView(nights: nights).tonight

    #expect(tonight?.usualWakeText == "You usually wake at 07:00")
    #expect(tonight?.beAsleepByText == "Be asleep by 23:00")
}

@Test func withFewerThanThreeNightsTonightReadsOnlyThatABedtimeAppearsAfterThree() throws {
    let nights = [
        tonightNight(month: 11, 2, timeAsleep: 8 * oneHour),
        tonightNight(month: 11, 3, timeAsleep: 8 * oneHour),
    ]
    let tonight = try #require(sleepView(nights: nights).tonight)

    #expect(tonight.waitingText == "A bedtime to aim for appears after 3 Nights")
    #expect(tonight.beAsleepByText == nil)
    #expect(tonight.sleepNeedText == nil)
    #expect(tonight.usualWakeText == nil)
    #expect(tonight.sleepDebtText == nil)
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

    #expect(tonight.usualWakeText == "You usually wake at 07:00")
    #expect(tonight.beAsleepByText == "Be asleep by 23:00")
}

/// The bedtime wraps round midnight: a usual wake of 06:00 with Sleep Need 9 h is 21:00.
@Test func theBedtimeWrapsRoundMidnight() throws {
    let nights =
        (28...31).map {
            tonightNight(month: 10, $0, wakeHour: 6, timeAsleep: 7 * oneHour)
        }
        + (1...3).map { tonightNight(month: 11, $0, wakeHour: 6, timeAsleep: 7 * oneHour) }
    let tonight = try #require(sleepView(nights: nights).tonight)

    #expect(tonight.usualWakeText == "You usually wake at 06:00")
    #expect(tonight.beAsleepByText == "Be asleep by 21:00")
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

@Test func yourWeekDaysWithNoNightReadNoNightAndHaveNoBar() {
    let lanes = sleepView(nights: yourWeekNights).week.lanes

    #expect(lanes.count == 7)
    let noNightTexts: [String?] = [nil, nil, nil, "no Night", "no Night", "no Night", "no Night"]
    #expect(lanes.map(\.noNightText) == noNightTexts)
    for lane in lanes.suffix(4) {
        #expect(lane.timeAsleepText == nil)
        #expect(lane.asleepSegments.isEmpty)
        #expect(lane.timeInBed == nil)
        #expect(lane.isShort == false)
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

/// A Night whose Time Asleep wasn't worked out still has its bar; its Time Asleep reads "—" and
/// it isn't marked short. With no Time Asleep in the week there's no Sleep Debt either, so the
/// title reads only "Your week".
@Test func aNightWithNoTimeAsleepReadsADashAndIsntShort() {
    var night = weekNight(3, timeAsleep: 8 * oneHour)
    night.timeAsleep = nil
    let week = sleepView(nights: [night]).week

    #expect(week.lanes.first?.timeAsleepText == "\u{2014}")
    #expect(week.lanes.first?.isShort == false)
    #expect(week.lanes.first?.asleepSegments == [DateInterval(start: at(2, 23), end: at(3, 7))])
    #expect(week.summaryText == nil)
}

/// Without Wake Bouts each Night's bar is one segment, Sleep Onset to Final Wake, on its Time in
/// Bed track.
@Test func eachNightsBarRunsFromSleepOnsetToFinalWakeOnItsTimeInBedTrack() {
    let lanes = sleepView(nights: yourWeekNights).week.lanes

    #expect(lanes.count == 7)
    #expect(
        lanes.prefix(3).map(\.asleepSegments) == [
            [DateInterval(start: at(2, 23), end: at(3, 7))],
            [DateInterval(start: at(1, 23), end: at(2, 7))],
            [DateInterval(start: at(month: 10, 31, 23), end: at(1, 7))],
        ]
    )
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

/// Spec 012, "A Night's lane and chart": the bar is split at each Wake Bout (02:10 for 8 min,
/// 04:30 for 7 min) and sits on the Time in Bed track.
@Test func aNightsBarBreaksAtEachWakeBoutOnItsTimeInBedTrack() {
    let lane = sleepView(nights: [nightOn3Nov()]).week.lanes.first

    #expect(
        lane?.asleepSegments == [
            DateInterval(start: at(2, 23), end: at(3, 2, 10)),
            DateInterval(start: at(3, 2, 18), end: at(3, 4, 30)),
            DateInterval(start: at(3, 4, 37), end: at(3, 7)),
        ]
    )
    #expect(lane?.timeInBed == DateInterval(start: at(2, 22, 50), end: at(3, 7, 10)))
}
