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

/// The desk Day: 08:00 to 17:00 (540 minutes) at 75 bpm with the step count rising by 1 a second,
/// except `still` from 12:00 to 12:20.
private func deskDay(still: [RecordMinute] = stillStretch()) -> [HistoryRecord] {
    let walking = RecordMinute(bpm: 75, steps: .rising)
    let minutes =
        Array(repeating: walking, count: 240) + still + Array(repeating: walking, count: 280)
    return historyRecords(startingAt: utcDate(2026, 11, 10, 8, 0), minutes: minutes)
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

@Test func tenActiveSecondsInEachStillMinuteLeaveTheDeskDayWithNoRestingHR() {
    #expect(restingHROfTenthOfNovember(deskDay(still: stillStretch(activeSeconds: 10))) == nil)
}

@Test func nineActiveSecondsInEachStillMinuteStillGiveRestingHR62() {
    #expect(restingHROfTenthOfNovember(deskDay(still: stillStretch(activeSeconds: 9))) == 62)
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
