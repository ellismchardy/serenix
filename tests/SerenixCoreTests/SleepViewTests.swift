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

/// The Night dated 3 Nov: Time in Bed 22:50 (2 Nov) to 07:10, Sleep Onset 23:00, Final Wake
/// 07:00, Time Asleep 7 h 45 m.
private func nightOn3Nov(
    timeInBedStart: Date? = at(2, 22, 50),
    timeInBedEnd: Date? = at(3, 7, 10)
) -> Night {
    Night(
        day: nov3,
        sleepOnset: at(2, 23),
        finalWake: at(3, 7),
        timeAsleep: 7 * oneHour + 45 * oneMinute,
        timeInBedStart: timeInBedStart,
        timeInBedEnd: timeInBedEnd
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

@Test func lastNightWithNoTimeInBedHasNoInBedUp() {
    let view = sleepView(nights: [nightOn3Nov(timeInBedStart: nil, timeInBedEnd: nil)])

    #expect(view.lastNight?.inBedText == nil)
    #expect(view.lastNight?.timeAsleepText == "7h 45m asleep")
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
