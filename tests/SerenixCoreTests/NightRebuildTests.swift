import Foundation
import SerenixCore
import Testing

private let londonTime = TimeZone(identifier: "Europe/London")!

/// A `now` well after every record time in the tests that use it, so neither the 30-day
/// retention rule nor the future rule skips anything.
private let afterNovember2026 = utcDate(2026, 12, 1, 12, 0)

/// The rebuild of `day` (in November 2026, when Europe/London is UTC) reading History Records
/// from noon UTC on `startDay` to noon UTC on `endDay`.
private func novemberRebuild(day: Int, from startDay: Int, to endDay: Int) -> NightRebuild {
    NightRebuild(
        day: Day(year: 2026, month: 11, day: day),
        records: DateInterval(
            start: utcDate(2026, 11, startDay, 12, 0),
            end: utcDate(2026, 11, endDay, 12, 0)
        )
    )
}

/// Spec 003, "When": a night window from noon on 14 Nov to noon on 15 Nov can give a Night dated
/// 14 or 15 Nov, so both dates are worked out again, each reading the two windows that can give it.
@Test func timesInOneNightWindowRebuildBothDatesThatWindowCanGive() {
    let times = [utcDate(2026, 11, 15, 1, 0), utcDate(2026, 11, 15, 7, 0)]

    let found = nightRebuilds(after: times, now: afterNovember2026, in: londonTime)

    #expect(
        found == [
            novemberRebuild(day: 14, from: 13, to: 15),
            novemberRebuild(day: 15, from: 14, to: 16),
        ]
    )
}

/// Spec 003, "When": times in the windows 14→15 Nov and 15→16 Nov touch dates 14, 15 and 16 Nov;
/// 15 Nov, which both windows can give, is worked out once.
@Test func timesInNeighbouringNightWindowsRebuildEachDateOnce() {
    let times = [utcDate(2026, 11, 15, 1, 0), utcDate(2026, 11, 15, 14, 0)]

    let found = nightRebuilds(after: times, now: afterNovember2026, in: londonTime)

    #expect(
        found == [
            novemberRebuild(day: 14, from: 13, to: 15),
            novemberRebuild(day: 15, from: 14, to: 16),
            novemberRebuild(day: 16, from: 15, to: 17),
        ]
    )
}

/// Repeated and unordered record times give the same dates, oldest first, as one ordered time each.
@Test func repeatedAndUnorderedTimesGiveTheSameRebuildsOldestFirst() {
    let times = [
        utcDate(2026, 11, 15, 14, 0),
        utcDate(2026, 11, 15, 1, 0),
        utcDate(2026, 11, 15, 14, 0),
        utcDate(2026, 11, 15, 1, 0),
    ]

    let found = nightRebuilds(after: times, now: afterNovember2026, in: londonTime)

    #expect(
        found == [
            novemberRebuild(day: 14, from: 13, to: 15),
            novemberRebuild(day: 15, from: 14, to: 16),
            novemberRebuild(day: 16, from: 15, to: 17),
        ]
    )
}

/// A sync that stored no History Records rebuilds nothing.
@Test func noTimesRebuildNothing() {
    let found = nightRebuilds(after: [], now: afterNovember2026, in: londonTime)

    #expect(found == [])
}

/// Spec 003: History Records are kept 30 days, so a date whose records start more than 30 days
/// before now is skipped. Now is 30 Nov 2026 12:00 UTC, so the limit is 31 Oct 12:00 UTC
/// (Europe/London is UTC after 25 Oct 2026). A time at 31 Oct 13:00 is in the window noon 31 Oct
/// to noon 1 Nov: 1 Nov's records start 31 Oct 12:00, exactly 30 days before now, and are kept;
/// 31 Oct's records start 30 Oct 12:00 and are skipped.
@Test func dateWhoseRecordsStartMoreThanThirtyDaysAgoIsSkipped() {
    let now = utcDate(2026, 11, 30, 12, 0)

    let found = nightRebuilds(after: [utcDate(2026, 10, 31, 13, 0)], now: now, in: londonTime)

    #expect(
        found == [
            NightRebuild(
                day: Day(year: 2026, month: 11, day: 1),
                records: DateInterval(
                    start: utcDate(2026, 10, 31, 12, 0),
                    end: utcDate(2026, 11, 2, 12, 0)
                )
            )
        ]
    )
}

/// A stray time from 1970 (a Strap clock that was never set) is far outside the 30 days History
/// Records are kept, so it rebuilds nothing.
@Test func strayTimeFrom1970RebuildsNothing() {
    let found = nightRebuilds(
        after: [Date(timeIntervalSince1970: 0)],
        now: afterNovember2026,
        in: londonTime
    )

    #expect(found == [])
}

/// A date whose records start after now is skipped. Now is 15 Nov 2026 11:00 UTC; a time at
/// 16 Nov 01:00 is in the window noon 15 Nov to noon 16 Nov. 15 Nov's records start 14 Nov 12:00,
/// before now, and are kept; 16 Nov's start 15 Nov 12:00, after now, and are skipped.
@Test func dateWhoseRecordsStartAfterNowIsSkipped() {
    let now = utcDate(2026, 11, 15, 11, 0)

    let found = nightRebuilds(after: [utcDate(2026, 11, 16, 1, 0)], now: now, in: londonTime)

    #expect(found == [novemberRebuild(day: 15, from: 14, to: 16)])
}

/// Night windows run local noon to local noon. Europe/London springs forward at 01:00 UTC on
/// 28 Mar 2027, so local noon is 12:00 UTC up to 27 Mar and 11:00 UTC from 28 Mar. A time at
/// 28 Mar 03:00 UTC is in the window noon 27 Mar to noon 28 Mar, which can give 27 or 28 Mar.
/// 28 Mar reads from 27 Mar 12:00 UTC to 29 Mar 11:00 UTC (47 hours); 27 Mar from 26 Mar
/// 12:00 UTC to 28 Mar 11:00 UTC. Now (1 Apr 2027) is late enough that nothing is skipped.
@Test func nightWindowsFollowLocalNoonAcrossTheClockChange() {
    let now = utcDate(2027, 4, 1, 12, 0)

    let found = nightRebuilds(after: [utcDate(2027, 3, 28, 3, 0)], now: now, in: londonTime)

    #expect(
        found == [
            NightRebuild(
                day: Day(year: 2027, month: 3, day: 27),
                records: DateInterval(
                    start: utcDate(2027, 3, 26, 12, 0),
                    end: utcDate(2027, 3, 28, 11, 0)
                )
            ),
            NightRebuild(
                day: Day(year: 2027, month: 3, day: 28),
                records: DateInterval(
                    start: utcDate(2027, 3, 27, 12, 0),
                    end: utcDate(2027, 3, 29, 11, 0)
                )
            ),
        ]
    )
}

/// A rebuild still waiting when Serenix next opens is checked again: once its History Records
/// start more than 30 days before now it's no longer due (they may have been pruned), and it is
/// due right up to that.
@Test func aWaitingRebuildIsNoLongerDueOnceItsRecordsStartMoreThanThirtyDaysAgo() {
    // Day 1 Nov reads from 31 Oct 12:00 UTC.
    let rebuild = NightRebuild(
        day: Day(year: 2026, month: 11, day: 1),
        records: DateInterval(start: utcDate(2026, 10, 31, 12, 0), end: utcDate(2026, 11, 2, 12, 0))
    )

    #expect(rebuild.isDue(at: utcDate(2026, 11, 30, 12, 0)))
    #expect(!rebuild.isDue(at: utcDate(2026, 11, 30, 12, 1)))
}
