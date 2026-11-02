import Foundation
import SerenixCore
import Testing

// Spec 006, success criteria for the Day's seconds in each HR Zone and the Max HR used, from Load
// of a Day. Defaults: Europe/London (UTC on 4 Nov 2026), a man with Max HR 190 entered, no Nights,
// one record a second. HR Zone lower edges for Max HR 190: 95, 114, 133, 152 and 171 bpm.

private let london = TimeZone(identifier: "Europe/London")!

/// 4 Nov 2026, the Day every test asks for.
private let fourthOfNovember = Day(year: 2026, month: 11, day: 4)

/// 2026-11-04 10:00:00 UTC.
private let tenAM = Date(timeIntervalSince1970: 1_793_786_400)

/// 2026-11-04 11:00:00 UTC.
private let elevenAM = Date(timeIntervalSince1970: 1_793_790_000)

/// 2026-11-04 12:00:00 UTC.
private let noon = Date(timeIntervalSince1970: 1_793_793_600)

private let oneHour = 3_600
private let tenMinutes = 600
private let man = Profile(name: nil, sex: .male, maxHR: 190)

/// The Load of 4 Nov 2026 in London from `records`, with no Nights.
private func loadOfFourthOfNovember(
    _ records: [HistoryRecord],
    profile: Profile = man
) -> DayLoad {
    load(of: fourthOfNovember, records: records, nights: [], profile: profile, in: london)
}

@Test func anHourAt164BpmIsAnHourInHRZone4WithTheEnteredMaxHR() {
    let result = loadOfFourthOfNovember(historyRecords(at: 164, for: oneHour, from: tenAM))

    let heartRate = result.heartRate
    #expect(
        heartRate?.zoneSeconds == [.one: 0, .two: 0, .three: 0, .four: 3_600, .five: 0]
    )
    #expect(heartRate?.maxHRUsed.bpm == 190)
    #expect(heartRate?.maxHRUsed.source == .entered)
}

@Test func eachHRZoneStartsAtItsLowerEdgeAndHeartRatesUnderZone1CountInNone() {
    let bpms = [94, 95, 113, 114, 133, 152, 170, 171, 200]
    var records: [HistoryRecord] = []
    for (index, bpm) in bpms.enumerated() {
        records += historyRecords(
            at: bpm,
            for: tenMinutes,
            from: tenAM.addingTimeInterval(TimeInterval(index * tenMinutes)),
            firstRecordCounter: UInt32(1 + index * tenMinutes)
        )
    }

    let result = loadOfFourthOfNovember(records)

    #expect(
        result.heartRate?.zoneSeconds
            == [.one: 1_200, .two: 600, .three: 600, .four: 1_200, .five: 1_200]
    )
}

@Test func zoneSecondsAreTheSecondsAtOrOverLoadsFloorWhateverTheOrderOrRepeats() {
    let records =
        historyRecords(at: 164, for: oneHour, from: tenAM, firstRecordCounter: 1)
        + historyRecords(at: 0, for: oneHour, from: elevenAM, firstRecordCounter: 3_601)
        + historyRecords(at: 94, for: oneHour, from: noon, firstRecordCounter: 7_201)

    let once = loadOfFourthOfNovember(records)
    let repeated = loadOfFourthOfNovember(records + records)
    let reversed = loadOfFourthOfNovember(records.reversed())

    #expect(once.heartRate?.zoneSeconds == [.one: 0, .two: 0, .three: 0, .four: 3_600, .five: 0])
    #expect(once.heartRate?.zoneSeconds.values.reduce(0, +) == 3_600)
    #expect(repeated.heartRate == once.heartRate)
    #expect(reversed.heartRate == once.heartRate)
}

@Test func withNoMaxHREnteredTheHRZonesComeFromTheMaxHREstimatedFromAge() {
    let bornIn1986 = Profile(name: nil, birthYear: 1986, sex: .male, maxHR: nil)

    let result = loadOfFourthOfNovember(
        historyRecords(at: 162, for: oneHour, from: tenAM),
        profile: bornIn1986
    )

    #expect(
        result.heartRate?.zoneSeconds == [.one: 0, .two: 0, .three: 0, .four: 0, .five: 3_600]
    )
    #expect(result.heartRate?.maxHRUsed.bpm == 180)
    #expect(result.heartRate?.maxHRUsed.source == .estimated)
}

@Test func aDayWithNoRecordsHasNoHeartRate() {
    let result = loadOfFourthOfNovember([])

    #expect(result.heartRate == nil)
}

@Test func withNoMaxHRAndNoBirthYearThereIsNoHeartRate() {
    let noMaxHR = Profile(name: nil, sex: .male, maxHR: nil)

    let result = loadOfFourthOfNovember(
        historyRecords(at: 164, for: oneHour, from: tenAM),
        profile: noMaxHR
    )

    #expect(result.heartRate == nil)
}

@Test func withMaxHRNotAboveRestingHRTheHRZonesAreStillThere() {
    let maxHR100 = Profile(name: nil, sex: .male, maxHR: 100)
    let restingHR100 = Night(day: fourthOfNovember, restingHR: 100)

    let result = load(
        of: fourthOfNovember,
        records: historyRecords(at: 164, for: oneHour, from: tenAM),
        nights: [restingHR100],
        profile: maxHR100,
        in: london
    )

    #expect(result.missingReason == .maxHRNotAboveRestingHR)
    #expect(
        result.heartRate?.zoneSeconds == [.one: 0, .two: 0, .three: 0, .four: 0, .five: 3_600]
    )
    #expect(result.heartRate?.maxHRUsed == MaxHRUsed(bpm: 100, source: .entered))
}

// Hourly HR Zone seconds: entries are the hours elapsed since local midnight, so a Day with a
// clock change has 23 or 25 entries.

private let noZoneSeconds: [HRZone: Int] = [.one: 0, .two: 0, .three: 0, .four: 0, .five: 0]

/// 2026-10-31 23:30:00 UTC, which is 23:30 GMT in London (clocks went back on 25 Oct).
private let halfPastElevenOn31October = Date(timeIntervalSince1970: 1_793_489_400)

/// 2026-03-29 12:00:00 UTC, which is 13:00 BST in London (clocks went forward at 01:00 GMT).
private let noonUTCOn29March = Date(timeIntervalSince1970: 1_774_785_600)

/// 2026-10-25 12:00:00 UTC, which is 12:00 GMT in London (clocks went back at 02:00 BST).
private let noonUTCOn25October = Date(timeIntervalSince1970: 1_792_929_600)

/// The Load of `day` in London from `records`, with no Nights.
private func loadInLondon(of day: Day, _ records: [HistoryRecord]) -> DayLoad {
    load(of: day, records: records, nights: [], profile: man, in: london)
}

@Test func anHourAt164BpmAcrossMidnightIsSplitBetweenEachDaysHours() {
    let records = historyRecords(at: 164, for: oneHour, from: halfPastElevenOn31October)

    let october31 = loadInLondon(of: Day(year: 2026, month: 10, day: 31), records)
    let november1 = loadInLondon(of: Day(year: 2026, month: 11, day: 1), records)

    let october31Hours = october31.heartRate?.hourlyZoneSeconds
    #expect(october31Hours?.count == 24)
    #expect(october31Hours?[23] == [.one: 0, .two: 0, .three: 0, .four: 1_800, .five: 0])
    #expect(october31Hours?.prefix(23).allSatisfy { $0 == noZoneSeconds } == true)

    let november1Hours = november1.heartRate?.hourlyZoneSeconds
    #expect(november1Hours?.count == 24)
    #expect(november1Hours?[0] == [.one: 0, .two: 0, .three: 0, .four: 1_800, .five: 0])
    #expect(november1Hours?.dropFirst().allSatisfy { $0 == noZoneSeconds } == true)
}

@Test func theDayClocksGoForwardHas23HoursAndTheDayTheyGoBackHas25() {
    // 29 Mar: local 01:00 never happens, so 13:00 BST is 12 hours after local midnight (entry 12).
    let march29 = loadInLondon(
        of: Day(year: 2026, month: 3, day: 29),
        historyRecords(at: 164, for: oneHour, from: noonUTCOn29March)
    )
    // 25 Oct: local 01:00 happens twice (BST then GMT), so 12:00 GMT is 13 hours after local
    // midnight (entry 13).
    let october25 = loadInLondon(
        of: Day(year: 2026, month: 10, day: 25),
        historyRecords(at: 164, for: oneHour, from: noonUTCOn25October)
    )

    let march29Hours = march29.heartRate?.hourlyZoneSeconds
    #expect(march29Hours?.count == 23)
    #expect(march29Hours?[12] == [.one: 0, .two: 0, .three: 0, .four: 3_600, .five: 0])

    let october25Hours = october25.heartRate?.hourlyZoneSeconds
    #expect(october25Hours?.count == 25)
    #expect(october25Hours?[13] == [.one: 0, .two: 0, .three: 0, .four: 3_600, .five: 0])
}

@Test func anHourAt164BpmFrom10AMFillsOnlyThe10AMHourWithHRZone4() {
    let result = loadOfFourthOfNovember(historyRecords(at: 164, for: oneHour, from: tenAM))

    let hours = result.heartRate?.hourlyZoneSeconds
    #expect(hours?.count == 24)
    #expect(hours?[10] == [.one: 0, .two: 0, .three: 0, .four: 3_600, .five: 0])
    #expect(
        hours?.enumerated().allSatisfy { hour, seconds in hour == 10 || seconds == noZoneSeconds }
            == true
    )
}

@Test func aDayWithAHalfHourClockChangeKeepsItsLastPartHour() {
    // Lord Howe Island moves its clocks forward 30 minutes (02:00 → 02:30) on 4 Oct 2026, so the
    // Day is 23.5 hours: 24 entries, the last one half an hour long. 12:40 UTC is 23:40 local
    // (UTC+11), 23 h 10 m after local midnight, so entry 23.
    let lordHowe = TimeZone(identifier: "Australia/Lord_Howe")!
    let october4 = Day(year: 2026, month: 10, day: 4)
    let records = historyRecords(at: 164, for: tenMinutes, from: utcDate(2026, 10, 4, 12, 40))

    let result = load(of: october4, records: records, nights: [], profile: man, in: lordHowe)

    let hours = result.heartRate?.hourlyZoneSeconds
    #expect(hours?.count == 24)
    #expect(hours?.last == [.one: 0, .two: 0, .three: 0, .four: 600, .five: 0])
}

// Highest HR: the highest heart rate in the Day's History Records, HR 0 skipped, even under the
// floor; the earliest time if it repeats.

@Test func theHighestHRIsTheEarliestTimeTheDaysTopHeartRateWasReached() {
    let nineAM = utcDate(2026, 11, 4, 9, 0)
    let twentyToSeven = utcDate(2026, 11, 4, 18, 40)
    let records =
        historyRecords(
            at: 120,
            for: oneHour,
            from: utcDate(2026, 11, 4, 8, 0),
            firstRecordCounter: 1
        )
        + historyRecords(at: 150, for: 1, from: nineAM, firstRecordCounter: 3_601)
        + historyRecords(
            at: 120,
            for: oneHour,
            from: nineAM.addingTimeInterval(1),
            firstRecordCounter: 3_602
        )
        + historyRecords(at: 150, for: 1, from: twentyToSeven, firstRecordCounter: 10_000)
        + historyRecords(
            at: 120,
            for: tenMinutes,
            from: twentyToSeven.addingTimeInterval(1),
            firstRecordCounter: 10_001
        )

    let inOrder = loadOfFourthOfNovember(records)
    let reversed = loadOfFourthOfNovember(records.reversed())

    #expect(inOrder.heartRate?.highestHR == HighestHR(bpm: 150, time: nineAM))
    #expect(reversed.heartRate?.highestHR == HighestHR(bpm: 150, time: nineAM))
}

@Test func aDayOfOnlyHR0HasHeartRateButNoHighestHR() {
    let result = loadOfFourthOfNovember(historyRecords(at: 0, for: oneHour, from: tenAM))

    #expect(result.heartRate != nil)
    #expect(result.heartRate?.highestHR == nil)
}

@Test func theHighestHRCountsEvenUnderLoadsFloor() {
    // 80 bpm is under the 95 bpm floor for Max HR 190.
    let result = loadOfFourthOfNovember(historyRecords(at: 80, for: oneHour, from: tenAM))

    #expect(result.heartRate?.highestHR == HighestHR(bpm: 80, time: tenAM))
}

@Test func anHourAt164BpmHasHighestHR164AtTheHoursFirstRecord() {
    let result = loadOfFourthOfNovember(historyRecords(at: 164, for: oneHour, from: tenAM))

    #expect(result.heartRate?.highestHR == HighestHR(bpm: 164, time: tenAM))
}

@Test func theHRZoneEdgeListHasHighestHR200AtTheStartOfItsLast10Minutes() {
    let bpms = [94, 95, 113, 114, 133, 152, 170, 171, 200]
    var records: [HistoryRecord] = []
    for (index, bpm) in bpms.enumerated() {
        records += historyRecords(
            at: bpm,
            for: tenMinutes,
            from: tenAM.addingTimeInterval(TimeInterval(index * tenMinutes)),
            firstRecordCounter: UInt32(1 + index * tenMinutes)
        )
    }

    let result = loadOfFourthOfNovember(records)

    // 200 bpm is the ninth 10 minutes, from 10:00 + 80 minutes = 11:20 UTC.
    #expect(
        result.heartRate?.highestHR == HighestHR(bpm: 200, time: utcDate(2026, 11, 4, 11, 20))
    )
}
