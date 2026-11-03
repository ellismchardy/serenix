import Foundation
import SerenixCore
import Testing

// The Sleep tab's view (spec 011, Behavior: Sleep tab, Last night). Expected values are spec
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
    timeAsleep: TimeInterval = 7 * oneHour + 45 * oneMinute,
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

// MARK: Last night

@Test func lastNightTodayReadsLastNightItsTimeAsleepAndInBedUp() {
    let view = sleepView(nights: [nightOn3Nov()])

    #expect(view.lastNight?.title == "Last night")
    #expect(view.lastNight?.timeAsleepText == "7h 45m asleep")
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

/// Spec 011: the total is the Sleep popup's minutes awake (Final Wake − Sleep Onset − Time
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
    let lastNight = sleepView(nights: [night]).lastNight

    #expect(lastNight?.notKeptText == "Heart rate isn't kept for Nights older than 30 days.")
    #expect(lastNight?.chart == nil)
    #expect(lastNight?.wakeSummary == nil)
    #expect(lastNight?.wakeBoutRows.isEmpty == true)
    #expect(lastNight?.timeAsleepText == "7h 45m asleep")
    #expect(lastNight?.inBedText == "In bed 22:50 \u{00B7} Up 07:10")
}

@Test func lastNightWithNoTimeInBedHasNoInBedUp() {
    let view = sleepView(nights: [nightOn3Nov(timeInBedStart: nil, timeInBedEnd: nil)])

    #expect(view.lastNight?.inBedText == nil)
    #expect(view.lastNight?.timeAsleepText == "7h 45m asleep")
    #expect(view.lastNight?.chart?.start == at(2, 23))
    #expect(view.lastNight?.chart?.end == at(3, 7))
}

@Test func lastNightOnAnEarlierDayIsTitledWithThatDaysName() {
    let view = sleepView(nights: [nightOn1Nov, nightOn3Nov()], showing: nov1)

    #expect(view.lastNight?.title == "Sun 1 Nov")
}

@Test func noNightTodayReadsNoNightYet() {
    let view = sleepView(nights: [nightOn1Nov])

    #expect(view.lastNight == nil)
    #expect(view.noNightMessage == "No Night yet")
}

@Test func noNightOnAnEarlierDayReadsNoNightRecorded() {
    let view = sleepView(nights: [nightOn3Nov()], showing: nov1)

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

// Spec 011's success criteria under "Tonight": Nights dated 28 Oct to 3 Nov, each Sleep Onset
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

// Spec 011's success criteria under "Your week": Nights dated 1 Nov (Time Asleep 6 h), 2 and
// 3 Nov (8 h), each 23:00 the evening before to 07:00. No birth year, so Usual Need is 8 h.

/// The Nights dated 1 Nov (Time Asleep 6 h), 2 Nov and 3 Nov (8 h), each 23:00 to 07:00.
private let yourWeekNights = [
    tonightNight(month: 11, 1, timeAsleep: 6 * oneHour),
    tonightNight(month: 11, 2, timeAsleep: 8 * oneHour),
    tonightNight(month: 11, 3, timeAsleep: 8 * oneHour),
]

@Test func yourWeekHasSevenSlotsFromSixDaysBeforeToTheDayShownOldestFirst() {
    let week = sleepView(nights: yourWeekNights).week

    #expect(
        week.days.map(\.day) == [
            Day(year: 2026, month: 10, day: 28),
            Day(year: 2026, month: 10, day: 29),
            Day(year: 2026, month: 10, day: 30),
            Day(year: 2026, month: 10, day: 31),
            Day(year: 2026, month: 11, day: 1),
            Day(year: 2026, month: 11, day: 2),
            Day(year: 2026, month: 11, day: 3),
        ]
    )
    #expect(week.days.map(\.letter) == ["W", "T", "F", "S", "S", "M", "T"])
}

@Test func yourWeekDaysWithNoNightAreEmptySlots() {
    let days = sleepView(nights: yourWeekNights).week.days

    #expect(days.count == 7)
    for slot in days.prefix(4) {
        #expect(slot.timeAsleepText == nil)
        #expect(slot.sleepNeedText == nil)
        #expect(slot.timeAsleep == nil)
        #expect(slot.sleepNeed == nil)
        #expect(slot.sleepOnset == nil)
        #expect(slot.finalWake == nil)
    }
}

/// Each Night's own Sleep Need (spec 009): 1 Nov has no Nights before it, so 8 h; 2 and 3 Nov
/// each repay 1 Nov's 2 h of Sleep Debt, adding a quarter of it, 30 min.
@Test func yourWeekSetsEachNightsTimeAsleepAgainstItsOwnSleepNeed() {
    let days = sleepView(nights: yourWeekNights).week.days

    #expect(days.count == 7)
    #expect(days.suffix(3).map(\.timeAsleepText) == ["6h 0m", "8h 0m", "8h 0m"])
    #expect(days.suffix(3).map(\.sleepNeedText) == ["8h 0m", "8h 30m", "8h 30m"])
    let timeAsleeps: [TimeInterval?] = [6 * oneHour, 8 * oneHour, 8 * oneHour]
    #expect(days.suffix(3).map(\.timeAsleep) == timeAsleeps)
    let eightAndAHalfHours: TimeInterval = 8 * oneHour + 30 * oneMinute
    let sleepNeeds: [TimeInterval?] = [8 * oneHour, eightAndAHalfHours, eightAndAHalfHours]
    #expect(days.suffix(3).map(\.sleepNeed) == sleepNeeds)
}

@Test func whenYouSleptRunsEachNightFromSleepOnsetToFinalWakeOnATwentyToTenAxis() {
    let week = sleepView(nights: yourWeekNights).week

    #expect(week.days.count == 7)
    let sleepOnsets: [Date?] = [at(month: 10, 31, 23), at(1, 23), at(2, 23)]
    let finalWakes: [Date?] = [at(1, 7), at(2, 7), at(3, 7)]
    #expect(week.days.suffix(3).map(\.sleepOnset) == sleepOnsets)
    #expect(week.days.suffix(3).map(\.finalWake) == finalWakes)
    #expect(week.axisStartHour == 20)
    #expect(week.axisEndHour == 10)
}

/// On the 20:00–10:00 axis (14 h), 23:00 sits 3/14 of the way along and 07:00 the next morning
/// 11/14.
@Test func whenYouSleptPlacesEachTimeAlongTheAxis() {
    let week = sleepView(nights: yourWeekNights).week

    #expect(week.axisFraction(of: at(2, 23)) == 3.0 / 14)
    #expect(week.axisFraction(of: at(3, 7)) == 11.0 / 14)
}

/// The axis' ends read as clock times.
@Test func whenYouSleptsAxisEndsReadAsClockTimes() {
    let week = sleepView(nights: yourWeekNights).week

    #expect(week.axisStartText == "20:00")
    #expect(week.axisEndText == "10:00")
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
    #expect(week.axisEndText == "11:00")
}

@Test func aNightFromNineteenThirtyWidensTheWhenYouSleptAxisToNineteen() {
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

@Test func yourWeekMarksTheDayShown() {
    let days = sleepView(nights: yourWeekNights).week.days

    #expect(days.map(\.isShown) == [false, false, false, false, false, false, true])
}

@Test func withAnEarlierDayShownYourWeekEndsOnItAndMarksIt() {
    let week = sleepView(nights: yourWeekNights, showing: Day(year: 2026, month: 11, day: 2)).week

    #expect(week.days.first?.day == Day(year: 2026, month: 10, day: 27))
    #expect(week.days.last?.day == Day(year: 2026, month: 11, day: 2))
    #expect(week.days.count == 7)
    #expect(week.days.map(\.isShown) == [false, false, false, false, false, false, true])
}
