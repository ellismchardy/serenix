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

/// `hour`:`minute` UTC (and so London local time) on `day` Nov 2026.
private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar.date(
        from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute)
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
