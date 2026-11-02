import Foundation
import SerenixCore
import Testing

private let london = TimeZone(identifier: "Europe/London")!

/// The History Records of the fixture Day from `start` to `end` inclusive, London local time
/// on 28 Oct 2026.
private func records(
    from start: (hour: Int, minute: Int),
    to end: (hour: Int, minute: Int)
) -> [HistoryRecord] {
    let startDate = londonTime(start)
    let endDate = londonTime(end)
    return DayFixture.day20261028.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
}

/// `time` in London on 28 Oct 2026.
private func londonTime(_ time: (hour: Int, minute: Int)) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = london
    return calendar.date(
        from: DateComponents(year: 2026, month: 10, day: 28, hour: time.hour, minute: time.minute)
    )!
}

/// Spec 007, real-fixture-Day criterion (steps half). The owner sat still 09:50–10:50 London on
/// 28 Oct 2026. Every record in that stretch reads 2688 steps in the fixture CSV, from
/// `2911083,2026-10-28T09:50:00+00:00,…,2688` to `2914683,2026-10-28T10:50:00+00:00,…,2688`.
@Test func fixtureDayStepCountStaysFlatWhileSittingStill() throws {
    let sitting = records(from: (9, 50), to: (10, 50))

    try #require(sitting.count == 3601)
    #expect(sitting.allSatisfy { $0.steps == 2688 })
}

/// Spec 007, real-fixture-Day criterion (steps half). The owner was on their feet at the gym
/// 06:00–08:00 London on 28 Oct 2026. The fixture CSV's first record in that stretch is
/// `2897291,2026-10-28T06:00:08+00:00,…,314` (the Strap recorded nothing 05:55:04–06:00:07) and
/// its last is `2904483,2026-10-28T08:00:00+00:00,…,2244`.
@Test func fixtureDayStepCountRisesWhileWalking() throws {
    let walking = records(from: (6, 0), to: (8, 0))

    let first = try #require(walking.first)
    let last = try #require(walking.last)
    #expect(first.steps == 314)
    #expect(last.steps == 2244)
    #expect(last.steps > first.steps)
}

/// Spec 007, real-fixture-Day criterion (Resting HR half): the fixture Day's Resting HR is
/// present, at least that morning's Night's Sleeping HR and no more than 15 bpm above it. No
/// capture holds the Night of 27–28 Oct, so the owner agreed the reference Night is the one of
/// 28–29 Oct (dated 29 Oct), the Night after the fixture Day. Its Sleep Period starts late on 28
/// Oct, so it overlaps the fixture Day and leaves out the records after its Sleep Onset.
@Test func fixtureDayRestingHRIsWithin15BpmAboveTheNextNightsSleepingHR() throws {
    let night = try #require(
        nights(from: NightFixture.night20261029, in: london)
            .first { $0.day == Day(year: 2026, month: 10, day: 29) }
    )
    let sleepingHR = try #require(night.sleepingHR)

    let restingHR = try #require(
        restingHR(
            of: Day(year: 2026, month: 10, day: 28),
            records: DayFixture.day20261028,
            nights: [night],
            in: london
        )
    )

    #expect(restingHR >= sleepingHR)
    #expect(restingHR <= sleepingHR + 15)
}
