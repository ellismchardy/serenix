import Foundation
import SerenixCore
import Testing

private let london = TimeZone(identifier: "Europe/London")!

/// 30 Nov 2026 12:00 UTC. History Records are kept 30 days, so a Day whose records start before
/// 31 Oct 12:00 UTC, or after this, is not due.
private let endOfNovember2026 = utcDate(2026, 11, 30, 12, 0)

/// The rebuild of `day` in November 2026 (when Europe/London is UTC), reading History Records
/// from its midnight to the next midnight, UTC.
private func novemberRebuild(day: Int) -> DayRebuild {
    DayRebuild(
        day: Day(year: 2026, month: 11, day: day),
        records: DateInterval(
            start: utcDate(2026, 11, day, 0, 0),
            // Day 30 ends on 31 Nov, which the calendar rolls over to 1 Dec.
            end: utcDate(2026, 11, day + 1, 0, 0)
        )
    )
}

/// Spec 005, "When": records at 23:00 on 14 Nov and 07:00 on 15 Nov queue 14 Nov and 15 Nov,
/// each reading local midnight to midnight.
@Test func timesOnTwoDaysRebuildEachDayMidnightToMidnight() {
    let times = [utcDate(2026, 11, 14, 23, 0), utcDate(2026, 11, 15, 7, 0)]

    let found = dayRebuilds(after: times, now: endOfNovember2026, in: london)

    #expect(found == [novemberRebuild(day: 14), novemberRebuild(day: 15)])
}

/// Repeated and unordered record times give the same Days, oldest first, as one ordered time each.
@Test func repeatedAndUnorderedTimesGiveTheSameDayRebuildsOldestFirst() {
    let times = [
        utcDate(2026, 11, 15, 7, 0),
        utcDate(2026, 11, 14, 23, 0),
        utcDate(2026, 11, 15, 7, 0),
        utcDate(2026, 11, 14, 23, 0),
    ]

    let found = dayRebuilds(after: times, now: endOfNovember2026, in: london)

    #expect(found == [novemberRebuild(day: 14), novemberRebuild(day: 15)])
}

/// A sync that stored no History Records rebuilds no Day.
@Test func noTimesRebuildNoDay() {
    let found = dayRebuilds(after: [], now: endOfNovember2026, in: london)

    #expect(found == [])
}

/// Spec 005, "When": with now 30 Nov 2026 12:00, 31 Oct's records start 31 Oct 00:00, more than
/// 30 days earlier, so a record at 31 Oct 13:00 queues nothing.
@Test func dayWhoseRecordsStartMoreThanThirtyDaysAgoIsSkipped() {
    let found = dayRebuilds(
        after: [utcDate(2026, 10, 31, 13, 0)],
        now: endOfNovember2026,
        in: london
    )

    #expect(found == [])
}

/// Spec 005, "When": with now 30 Nov 2026 12:00, 1 Nov's records start 1 Nov 00:00, within 30
/// days, so a record at 1 Nov 01:00 queues 1 Nov.
@Test func dayWhoseRecordsStartWithinThirtyDaysIsQueued() {
    let found = dayRebuilds(
        after: [utcDate(2026, 11, 1, 1, 0)],
        now: endOfNovember2026,
        in: london
    )

    #expect(found == [novemberRebuild(day: 1)])
}

/// Spec 005, "When": with now 30 Nov 2026 12:00, today's records started at midnight, so a record
/// at 30 Nov 13:00 queues 30 Nov.
@Test func todayIsQueued() {
    let found = dayRebuilds(
        after: [utcDate(2026, 11, 30, 13, 0)],
        now: endOfNovember2026,
        in: london
    )

    #expect(found == [novemberRebuild(day: 30)])
}

/// Spec 005, "When": with now 30 Nov 2026 12:00, 1 Dec's records start in the future (a Strap
/// clock that's wrong), so a record at 1 Dec 01:00 queues nothing.
@Test func dayWhoseRecordsStartAfterNowIsSkipped() {
    let found = dayRebuilds(
        after: [utcDate(2026, 12, 1, 1, 0)],
        now: endOfNovember2026,
        in: london
    )

    #expect(found == [])
}

/// Spec 005, "Profile changes": every Day whose History Records are still on the phone is worked
/// out again. With now 30 Nov 2026 12:00 those are the 30 Days 1 Nov to 30 Nov, oldest first.
@Test func profileChangeRebuildsEveryDayOfTheLastThirtyDaysOldestFirst() {
    let found = dayRebuildsDue(now: endOfNovember2026, in: london)

    #expect(found == (1...30).map { novemberRebuild(day: $0) })
}

/// Spec 005: a Day runs local midnight to local midnight, 23 hours across a clock change.
/// Europe/London springs forward at 01:00 UTC on 29 Mar 2026, so 29 Mar reads from 00:00 UTC to
/// 23:00 UTC. Now (1 Apr 2026) is late enough that nothing is skipped.
@Test func dayFollowsLocalMidnightAcrossTheClockChange() {
    let found = dayRebuilds(
        after: [utcDate(2026, 3, 29, 12, 0)],
        now: utcDate(2026, 4, 1, 12, 0),
        in: london
    )

    #expect(
        found == [
            DayRebuild(
                day: Day(year: 2026, month: 3, day: 29),
                records: DateInterval(
                    start: utcDate(2026, 3, 29, 0, 0),
                    end: utcDate(2026, 3, 29, 23, 0)
                )
            )
        ]
    )
}
