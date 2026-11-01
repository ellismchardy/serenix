import Foundation
import SerenixCore
import Testing

// Spec 005, success criteria for Load of a Day with an entered Max HR and no Nights, so Resting
// HR is the 60 bpm fallback. Expected Loads are the spec's literals for a man with Max HR 190 and
// Resting HR 60 unless a test says otherwise. Europe/London is UTC on 4 Nov 2026.

private let london = TimeZone(identifier: "Europe/London")!

/// 4 Nov 2026, the Day every test asks for.
private let fourthOfNovember = Day(year: 2026, month: 11, day: 4)

/// 2026-11-04 00:00:00 UTC: the start of the Day.
private let startOfDay = Date(timeIntervalSince1970: 1_793_750_400)

/// 2026-11-04 04:00:00 UTC.
private let fourAM = Date(timeIntervalSince1970: 1_793_764_800)

/// 2026-11-04 10:00:00 UTC.
private let tenAM = Date(timeIntervalSince1970: 1_793_786_400)

private let oneHour = 3_600
private let man = Profile(name: nil, sex: .male, maxHR: 190)

/// One History Record a second at `bpm`, from `start`, with increasing Record Counters.
private func records(
    at bpm: Int,
    for seconds: Int,
    from start: Date,
    firstCounter: UInt32 = 1
) -> [HistoryRecord] {
    (0..<seconds).map { offset in
        HistoryRecord(
            recordCounter: firstCounter + UInt32(offset),
            timestamp: start.addingTimeInterval(TimeInterval(offset)),
            heartRate: bpm,
            rrIntervals: [],
            motion: [1, 0, 0, 0],
            skinTemperature: 33,
            steps: 0,
            spo2: 0,
            isInSpO2Window: false,
            rawBytes: []
        )
    }
}

/// The Load of 4 Nov 2026 in London from `records`, with no Nights.
private func loadOfFourthOfNovember(
    _ records: [HistoryRecord],
    profile: Profile = man
) -> DayLoad {
    load(of: fourthOfNovember, records: records, nights: [], profile: profile, in: london)
}

@Test func anHourAt164BpmGivesLoad57ForAMan() {
    let result = loadOfFourthOfNovember(records(at: 164, for: oneHour, from: tenAM))

    #expect(result.load == 57)
    #expect(result.missingReason == nil)
}

@Test func anHourAt164BpmGivesLoad58ForAWoman() {
    let woman = Profile(name: nil, sex: .female, maxHR: 190)

    let hard = records(at: 164, for: oneHour, from: tenAM)

    let result = loadOfFourthOfNovember(hard, profile: woman)

    #expect(result.load == 58)
}

@Test func anHourAt164BpmGivesLoad57WhenSexIsPreferNotToSay() {
    let preferNotToSay = Profile(name: nil, sex: .preferNotToSay, maxHR: 190)

    let hard = records(at: 164, for: oneHour, from: tenAM)

    let result = loadOfFourthOfNovember(hard, profile: preferNotToSay)

    #expect(result.load == 57)
}

@Test func anHourAt164BpmGivesLoad57WhenSexIsNotSet() {
    let sexNotSet = Profile(name: nil, maxHR: 190)

    let hard = records(at: 164, for: oneHour, from: tenAM)

    let result = loadOfFourthOfNovember(hard, profile: sexNotSet)

    #expect(result.load == 57)
}

@Test func thirtyMinutesAt112BpmGivesLoad33() {
    let result = loadOfFourthOfNovember(records(at: 112, for: 30 * 60, from: tenAM))

    #expect(result.load == 33)
}

@Test func anHourAt120BpmGivesLoad43() {
    let result = loadOfFourthOfNovember(records(at: 120, for: oneHour, from: tenAM))

    #expect(result.load == 43)
}

@Test func aHeartRateOverTheFloorButUnderRestingHRAddsNothing() {
    // Max HR 100 puts the floor at 50 bpm, so 55 bpm counts but is under the 60 bpm Resting HR.
    let lowMaxHR = Profile(name: nil, sex: .male, maxHR: 100)
    let result = loadOfFourthOfNovember(
        records(at: 55, for: oneHour, from: tenAM),
        profile: lowMaxHR
    )

    #expect(result.load == 0)
}

@Test func sixteenHoursBelowHalfOfMaxHRGivesLoad0() {
    // 94 bpm is under 50% of Max HR 190; 04:00 to 20:00 stays inside the Day.
    let result = loadOfFourthOfNovember(records(at: 94, for: 16 * oneHour, from: fourAM))

    #expect(result.load == 0)
    #expect(result.missingReason == nil)
}

@Test func anHourJustOverHalfOfMaxHRGivesLoad33() {
    let result = loadOfFourthOfNovember(records(at: 95, for: oneHour, from: tenAM))

    #expect(result.load == 33)
}

@Test func anHourAboveMaxHRCountsAsAnHourAtMaxHR() {
    let above = loadOfFourthOfNovember(records(at: 200, for: oneHour, from: tenAM))
    let atMax = loadOfFourthOfNovember(records(at: 190, for: oneHour, from: tenAM))

    #expect(above.load == 64)
    #expect(atMax.load == 64)
}

@Test func aWholeDayAtMaxHRGivesLoad100() {
    let result = loadOfFourthOfNovember(records(at: 190, for: 24 * oneHour, from: startOfDay))

    #expect(result.load == 100)
}

@Test func recordsWithNoHeartRateAddNothing() {
    let hard = records(at: 164, for: oneHour, from: tenAM)
    let elevenAM = tenAM.addingTimeInterval(TimeInterval(oneHour))
    let nextCounter = UInt32(oneHour) + 1
    let notWorn = records(at: 0, for: oneHour, from: elevenAM, firstCounter: nextCounter)

    let result = loadOfFourthOfNovember(hard + notWorn)

    #expect(result.load == 57)
}

@Test func repeatedHistoryRecordsCountOnce() {
    let hard = records(at: 164, for: oneHour, from: tenAM)

    let result = loadOfFourthOfNovember(hard + hard)

    #expect(result.load == 57)
}

@Test func historyRecordsOutOfOrderGiveTheSameLoad() {
    let hard = records(at: 164, for: oneHour, from: tenAM)

    let result = loadOfFourthOfNovember(hard.reversed())

    #expect(result.load == 57)
}

@Test func aDayWithNoHistoryRecordsHasLoadMissingForNoRecords() {
    let result = loadOfFourthOfNovember([])

    #expect(result.load == nil)
    #expect(result.missingReason == .noRecords)
}

@Test func aDayWithRecordsButNoneOverTheFloorHasLoad0NotMissing() {
    let result = loadOfFourthOfNovember(records(at: 80, for: oneHour, from: tenAM))

    #expect(result.load == 0)
    #expect(result.missingReason == nil)
}

@Test func theLoadIsForTheDayAskedFor() {
    let result = loadOfFourthOfNovember(records(at: 164, for: oneHour, from: tenAM))

    #expect(result.day == fourthOfNovember)
}
