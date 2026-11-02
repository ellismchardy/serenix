import Foundation
import SerenixCore
import Testing

// Spec 007, success criteria for Resting HR of a Day: Europe/London, the Day 10 Nov 2026 (London
// is UTC in November), no Nights, one History Record a second, no turn between records and the
// step count unchanged unless a test says otherwise. Expected values are the spec's literals.

private let london = TimeZone(identifier: "Europe/London")!

/// 10 Nov 2026, the Day every test asks for.
private let tenthOfNovember = Day(year: 2026, month: 11, day: 10)

/// The desk Day's still stretch, 12:00 to 12:20: minutes 1–4 at 55 bpm, 5–9 at `minutes5To9`,
/// 10–15 at 64 and 16–20 at 50, with no steps and no turn.
private func stillStretch(minutes5To9: Int = 62) -> [RecordMinute] {
    Array(repeating: RecordMinute(bpm: 55), count: 4)
        + Array(repeating: RecordMinute(bpm: minutes5To9), count: 5)
        + Array(repeating: RecordMinute(bpm: 64), count: 6)
        + Array(repeating: RecordMinute(bpm: 50), count: 5)
}

/// The desk Day: London local time on `day`, from `start` (08:00 unless a test says otherwise) to
/// 17:00 at 75 bpm with the step count rising by 1 a second, except `still` from 12:00 to 12:20.
/// From 08:00 that's 540 minutes; from 09:00, 480.
private func deskDay(
    still: [RecordMinute] = stillStretch(),
    on day: Day = tenthOfNovember,
    from start: (hour: Int, minute: Int) = (8, 0),
    firstRecordCounter: UInt32 = 1
) -> [HistoryRecord] {
    let walking = RecordMinute(bpm: 75, steps: .rising)
    let minutesBeforeNoon = 12 * 60 - (start.hour * 60 + start.minute)
    let minutes =
        Array(repeating: walking, count: minutesBeforeNoon) + still
        + Array(repeating: walking, count: 280)
    return historyRecords(
        startingAt: londonDate(day, start.hour, start.minute),
        minutes: minutes,
        firstRecordCounter: firstRecordCounter
    )
}

/// `hour`:`minute` London local time on `day`.
private func londonDate(_ day: Day, _ hour: Int, _ minute: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = london
    let components = DateComponents(
        year: day.year,
        month: day.month,
        day: day.dayOfMonth,
        hour: hour,
        minute: minute
    )
    return calendar.date(from: components)!
}

/// The Resting HR of 10 Nov 2026 in London from `records`, with no Nights.
private func restingHROfTenthOfNovember(_ records: [HistoryRecord]) -> Double? {
    restingHR(of: tenthOfNovember, records: records, nights: [], in: london)
}

@Test func theDeskDayGivesRestingHR62LeavingOutSettlingAndAfterMinute15() {
    #expect(restingHROfTenthOfNovember(deskDay()) == 62)
}

@Test func theDeskDayWithMinutes5To9At66GivesRestingHR64FromMinutes10To14() {
    #expect(restingHROfTenthOfNovember(deskDay(still: stillStretch(minutes5To9: 66))) == 64)
}

/// The still stretch with its minute `number` (1 to 20) changed by `change`.
private func stillStretch(minute number: Int, _ change: (inout RecordMinute) -> Void)
    -> [RecordMinute]
{
    var still = stillStretch()
    change(&still[number - 1])
    return still
}

/// The still stretch with every minute turning in its first `activeSeconds` seconds.
private func stillStretch(activeSeconds: Int) -> [RecordMinute] {
    stillStretch().map { minute in
        var minute = minute
        minute.activeSeconds = activeSeconds
        return minute
    }
}

/// Wrist movement without steps, as at a desk, keeps a minute still (spec 007, Still minute).
@Test func theStrapTurningEverySecondWithNoStepsStillGivesRestingHR62() {
    #expect(restingHROfTenthOfNovember(deskDay(still: stillStretch(activeSeconds: 60))) == 62)
}

@Test func oneStepInMinute7BreaksTheRunSoTheRunFromMinute8GivesRestingHR50() {
    let still = stillStretch(minute: 7) { $0.steps = .oneStep }
    #expect(restingHROfTenthOfNovember(deskDay(still: still)) == 50)
}

@Test func aDropInTheStepCountIsAStrapRebootNotAStepSoRestingHRIs62() {
    // The step count has risen to 14,400 over the 240 walking minutes before the still stretch,
    // so the drop to 0 in minute 7 is a real drop; it stays flat at 0 for the rest of the stretch.
    // Minute 7, as for one step, because a run broken there gives 50, not 62.
    let still = stillStretch(minute: 7) { $0.steps = .reset }
    #expect(restingHROfTenthOfNovember(deskDay(still: still)) == 62)
}

@Test func only29WornRecordsInMinute3RestartTheRunAtMinute4SoRestingHRIs55Point6() throws {
    let still = stillStretch(minute: 3) { $0.wornRecords = 29 }
    let restingHR = try #require(restingHROfTenthOfNovember(deskDay(still: still)))
    // Minutes 14–18: 64, 64, 50, 50, 50.
    #expect(abs(restingHR - 55.6) < 1e-9)
}

@Test func thirtyWornRecordsInMinute3KeepTheRunSoRestingHRIs62() {
    let still = stillStretch(minute: 3) { $0.wornRecords = 30 }
    #expect(restingHROfTenthOfNovember(deskDay(still: still)) == 62)
}

// MARK: - The 8-hour rule

@Test func theDeskDayFrom0901Has479WornMinutesSoNoRestingHR() {
    #expect(restingHROfTenthOfNovember(deskDay(from: (9, 1))) == nil)
}

@Test func theDeskDayFrom0900Has480WornMinutesSoRestingHRIs62() {
    #expect(restingHROfTenthOfNovember(deskDay(from: (9, 0))) == 62)
}

// MARK: - Sleep Period exclusion

/// 00:00 to 07:00 on 10 Nov at 45 bpm, still: no turn and the step count flat at 0 throughout.
/// Its Record Counters run 1 to 25 200, so the desk Day's start after them. The desk Day's step
/// count starts at 1 on its first record (08:00), a step from these records' 0, in a walking
/// minute that has steps anyway.
private let stillUntilSeven = historyRecords(
    startingAt: utcDate(2026, 11, 10, 0, 0),
    minutes: Array(repeating: RecordMinute(bpm: 45), count: 7 * 60)
)

/// The first Record Counter of a desk Day built after `stillUntilSeven`.
private let afterStillUntilSeven: UInt32 = 25_201

/// A Night whose Sleep Period runs from 23:00 on 9 Nov to 07:00 on 10 Nov (UTC, which is London
/// time in November).
private let nightToSevenOnTheTenth = Night(
    day: tenthOfNovember,
    sleepOnset: utcDate(2026, 11, 9, 23, 0),
    finalWake: utcDate(2026, 11, 10, 7, 0)
)

@Test func stillRecordsAt45BeforeTheDeskDayWithNoNightGiveRestingHR45() {
    let records = stillUntilSeven + deskDay(firstRecordCounter: afterStillUntilSeven)
    #expect(restingHROfTenthOfNovember(records) == 45)
}

@Test func recordsInsideANightsSleepPeriodAreLeftOutSoRestingHRIs62() {
    let records = stillUntilSeven + deskDay(firstRecordCounter: afterStillUntilSeven)
    let restingHR = restingHR(
        of: tenthOfNovember,
        records: records,
        nights: [nightToSevenOnTheTenth],
        in: london
    )
    #expect(restingHR == 62)
}

@Test func wornMinutesInsideANightsSleepPeriodDontCountTowardThe480SoNoRestingHR() {
    // 479 worn minutes outside the Sleep Period, 899 with it.
    let records =
        stillUntilSeven + deskDay(from: (9, 1), firstRecordCounter: afterStillUntilSeven)
    let restingHR = restingHR(
        of: tenthOfNovember,
        records: records,
        nights: [nightToSevenOnTheTenth],
        in: london
    )
    #expect(restingHR == nil)
}

// MARK: - Day boundaries

/// 20 still minutes at `bpm` from `start`: no turn, the step count flat at 0. Its minutes 5–9
/// form a settled window at `bpm`.
private func stillMinutes(at bpm: Int, from start: Date, firstRecordCounter: UInt32)
    -> [HistoryRecord]
{
    historyRecords(
        startingAt: start,
        minutes: Array(repeating: RecordMinute(bpm: bpm), count: 20),
        firstRecordCounter: firstRecordCounter
    )
}

@Test func aStillStretchAt50OnTheNextDayLeavesTheDeskDayAt62() {
    // The desk Day's records reach Record Counter 32 400. Their step count ends high, so this
    // stretch's flat 0 is a drop (a reboot), not a step.
    let nextDay = stillMinutes(
        at: 50,
        from: utcDate(2026, 11, 11, 12, 0),
        firstRecordCounter: 32_401
    )
    #expect(restingHROfTenthOfNovember(deskDay() + nextDay) == 62)
}

/// Sun 25 Oct 2026: London's clocks go back from 02:00 BST to 01:00 GMT, so the Day runs 25
/// hours, from 23:00 UTC on 24 Oct to 00:00 UTC on 26 Oct.
private let twentyFifthOfOctober = Day(year: 2026, month: 10, day: 25)
private let twentyFourthOfOctober = Day(year: 2026, month: 10, day: 24)

@Test func theDeskDayOnTheDayTheClocksGoBackGivesRestingHR62() {
    let records = deskDay(on: twentyFifthOfOctober)
    #expect(restingHR(of: twentyFifthOfOctober, records: records, nights: [], in: london) == 62)
}

@Test func recordsFrom2300UTCOn24OctCountToward25OctAndThoseBeforeTowardThe24th() {
    // A desk Day on each of 24 and 25 Oct (London local times; 24 Oct is BST, UTC+1), plus two
    // still stretches either side of 25 Oct's local midnight, 23:00 UTC on 24 Oct:
    // - `beforeMidnight` at 50 bpm, 22:30–22:50 UTC (23:30–23:50 BST on 24 Oct);
    // - `afterMidnight` at 45 bpm, 23:00–23:20 UTC (00:00–00:20 BST on 25 Oct).
    // Right: 24 Oct gets only `beforeMidnight` (50 < its desk Day's 62), 25 Oct only
    // `afterMidnight` (45). Days cut at UTC midnight instead, or at any time from 23:20 UTC, give
    // 24 Oct both stretches (45) and 25 Oct neither (62); a cut before 22:30 UTC gives 24 Oct
    // neither (62). Each stretch's flat 0 step count after the desk Day's high one is a drop, not
    // a step.
    let beforeMidnight = stillMinutes(
        at: 50,
        from: utcDate(2026, 10, 24, 22, 30),
        firstRecordCounter: 32_401
    )
    let afterMidnight = stillMinutes(
        at: 45,
        from: utcDate(2026, 10, 24, 23, 0),
        firstRecordCounter: 33_601
    )
    let records =
        deskDay(on: twentyFourthOfOctober) + beforeMidnight + afterMidnight
        + deskDay(on: twentyFifthOfOctober, firstRecordCounter: 34_801)

    #expect(restingHR(of: twentyFourthOfOctober, records: records, nights: [], in: london) == 50)
    #expect(restingHR(of: twentyFifthOfOctober, records: records, nights: [], in: london) == 45)
}

// MARK: - Repeats and order

@Test func theDeskDayWithEveryRecordRepeatedGivesRestingHR62() {
    let records = deskDay()
    #expect(restingHROfTenthOfNovember(records + records) == 62)
}

/// Counted twice, minute 3's 29 worn records would make 58, keep the run and give 62.
@Test func repeatsCountOnceTowardAWornMinuteSoOnly29WornRecordsStillGive55Point6() throws {
    let records = deskDay(still: stillStretch(minute: 3) { $0.wornRecords = 29 })
    let restingHR = try #require(restingHROfTenthOfNovember(records + records))
    #expect(abs(restingHR - 55.6) < 1e-9)
}

@Test func theDeskDayInReverseOrderGivesRestingHR62() {
    #expect(restingHROfTenthOfNovember(deskDay().reversed()) == 62)
}

@Test func theDeskDayShuffledGivesRestingHR62() {
    // A fixed shuffle: every 7th record from the first, then every 7th from the second, and so
    // on, so neighbouring records end up far apart.
    let records = deskDay()
    let shuffled = (0..<7).flatMap { offset in
        stride(from: offset, to: records.count, by: 7).map { records[$0] }
    }
    #expect(restingHROfTenthOfNovember(shuffled) == 62)
}
