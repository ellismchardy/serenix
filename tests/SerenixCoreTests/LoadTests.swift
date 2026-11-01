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

// Which records (spec 005): a Day's Load uses only the History Records in that Day, local
// midnight to local midnight. An hour at 164 bpm split 30 minutes per Day gives 49 to each Day.

/// The Load of `day` in London from `records`, with no Nights, for a man with Max HR 190.
private func loadOf(_ day: Day, _ records: [HistoryRecord]) -> DayLoad {
    load(of: day, records: records, nights: [], profile: man, in: london)
}

@Test func anHourAcrossMidnightCountsHalfTowardEachDay() {
    // 2026-10-31 23:30:00 UTC; London is on GMT, so local midnight is 1 Nov 00:00 UTC.
    let halfPastElevenOn31Oct = Date(timeIntervalSince1970: 1_793_489_400)
    let acrossMidnight = records(at: 164, for: oneHour, from: halfPastElevenOn31Oct)

    let thirtyFirst = loadOf(Day(year: 2026, month: 10, day: 31), acrossMidnight)
    let first = loadOf(Day(year: 2026, month: 11, day: 1), acrossMidnight)

    #expect(thirtyFirst.load == 49)
    #expect(first.load == 49)
}

@Test func theDayClocksGoForwardRunsFromMidnightGMTTo2300UTC() {
    // On 29 Mar 2026 London goes from GMT to BST at 01:00 GMT, so the Day runs 29 Mar 00:00 UTC
    // to 29 Mar 23:00 UTC.
    let twentyNinthOfMarch = Day(year: 2026, month: 3, day: 29)
    // 2026-03-28 23:30:00 UTC.
    let halfPastElevenOn28Mar = Date(timeIntervalSince1970: 1_774_740_600)
    // 2026-03-29 22:30:00 UTC.
    let halfPastTenOn29Mar = Date(timeIntervalSince1970: 1_774_823_400)
    let intoTheDay = records(at: 164, for: oneHour, from: halfPastElevenOn28Mar)
    let outOfTheDay = records(at: 164, for: oneHour, from: halfPastTenOn29Mar)

    let start = loadOf(twentyNinthOfMarch, intoTheDay)
    let end = loadOf(twentyNinthOfMarch, outOfTheDay)
    let thirtiethOfMarch = loadOf(Day(year: 2026, month: 3, day: 30), outOfTheDay)

    #expect(start.load == 49)
    #expect(end.load == 49)
    #expect(thirtiethOfMarch.load == 49)
}

@Test func aDayGivenOnlyOtherDaysRecordsHasLoadMissingForNoRecords() {
    let secondOfNovember = Day(year: 2026, month: 11, day: 2)

    let result = loadOf(secondOfNovember, records(at: 164, for: oneHour, from: tenAM))

    #expect(result.load == nil)
    #expect(result.missingReason == .noRecords)
}

@Test func aRecordAtMidnightCountsTowardTheDayItStartsNotTheDayBefore() {
    // 1 Nov 2026 00:00 UTC, which is local midnight in London (GMT).
    let midnightStarting1Nov = Date(timeIntervalSince1970: 1_793_491_200)
    let atMidnight = records(at: 190, for: 1, from: midnightStarting1Nov)

    #expect(loadOf(Day(year: 2026, month: 10, day: 31), atMidnight).missingReason == .noRecords)
    #expect(loadOf(Day(year: 2026, month: 11, day: 1), atMidnight).missingReason == nil)
}

@Test func theDayClocksGoBackRunsFrom2300UTCTo2400UTC() {
    // 25 Oct 2026: 02:00 BST becomes 01:00 GMT, so the Day is 24 Oct 23:00 UTC to 26 Oct 00:00
    // UTC, 25 hours.
    let halfPastTenOn24Oct = Date(timeIntervalSince1970: 1_792_881_000)
    let halfPastElevenOn25Oct = Date(timeIntervalSince1970: 1_792_971_000)
    let start = records(at: 164, for: oneHour, from: halfPastTenOn24Oct)
    let end = records(at: 164, for: oneHour, from: halfPastElevenOn25Oct)
    let twentyFifthOfOctober = Day(year: 2026, month: 10, day: 25)

    #expect(loadOf(twentyFifthOfOctober, start).load == 49)
    #expect(loadOf(twentyFifthOfOctober, end).load == 49)
}

// Max HR (spec 005): the entered Max HR, else Tanaka's 208 − 0.7 × age, with age the Day's year
// minus the birth year. Birth year 1986 on a Day in 2026 is age 40, so Max HR 180.

@Test func withNoMaxHRTheMaxHREstimatedFromAgeGivesLoad56() {
    let bornIn1986 = Profile(name: nil, birthYear: 1986, sex: .male)

    let result = loadOfFourthOfNovember(
        records(at: 154, for: oneHour, from: tenAM),
        profile: bornIn1986
    )

    #expect(result.load == 56)
    #expect(result.missingReason == nil)
}

@Test func withNoMaxHRAndNoBirthYearLoadIsMissingForNoMaxHR() {
    let noAge = Profile(name: nil, sex: .male)

    let result = loadOfFourthOfNovember(
        records(at: 164, for: oneHour, from: tenAM),
        profile: noAge
    )

    #expect(result.load == nil)
    #expect(result.missingReason == .noMaxHR)
}

@Test func anEnteredMaxHRWinsOverTheEstimateFromBirthYear() {
    let bornIn1986WithMaxHR190 = Profile(name: nil, birthYear: 1986, sex: .male, maxHR: 190)

    let result = loadOfFourthOfNovember(
        records(at: 164, for: oneHour, from: tenAM),
        profile: bornIn1986WithMaxHR190
    )

    #expect(result.load == 57)
    #expect(result.missingReason == nil)
}
