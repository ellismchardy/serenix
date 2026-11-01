import Foundation
import SerenixCore
import Testing

private let london = TimeZone(identifier: "Europe/London")!

/// Spec 003, success criterion 1. Expected values are hr-tracker's output on the same fixture
/// night; Europe/London is UTC on these dates.
@Test func fixtureNightMakesOneNightDatedByFinalWakeWithItsSleepPeriod() throws {
    let found = nights(from: NightFixture.night20261030, in: london)

    try #require(found.count == 1)
    let night = found[0]
    #expect(night.day == Day(year: 2026, month: 10, day: 30))
    // 2026-10-29 21:05:00 UTC
    #expect(night.sleepOnset == Date(timeIntervalSince1970: 1_793_307_900))
    // 2026-10-30 03:42:00 UTC
    #expect(night.finalWake == Date(timeIntervalSince1970: 1_793_331_720))
    // 2026-10-29 20:57:00 UTC
    #expect(night.timeInBedStart == Date(timeIntervalSince1970: 1_793_307_420))
    // 2026-10-30 04:00:00 UTC
    #expect(night.timeInBedEnd == Date(timeIntervalSince1970: 1_793_332_800))
    // 5h52. Typed up front: comparing a `TimeInterval?` with a bare literal inside `#expect`
    // crashes the Swift 6.4.1 compiler on Windows.
    let fiveHoursFiftyTwo: TimeInterval? = 352 * 60
    #expect(night.timeAsleep == fiveHoursFiftyTwo)
}

/// Spec 003: each Nightly Metric must be within ±0.05 of hr-tracker's unrounded value on the
/// same fixture night (units: bpm, ms, br/min, °C).
private let hrTrackerTolerance = 0.05

/// Spec 003, success criterion 2 (Resting HR, HRV and skin temperature). Expected values are
/// hr-tracker's unrounded output on the same fixture night.
@Test func fixtureNightHasRestingHRHRVAndSkinTemperatureMatchingHRTracker() throws {
    let found = nights(from: NightFixture.night20261030, in: london)

    try #require(found.count == 1)
    let night = found[0]
    let restingHR = try #require(night.restingHR)
    let hrv = try #require(night.hrv)
    let skinTemperature = try #require(night.skinTemperature)
    #expect(abs(restingHR - 48.11506392440245) <= hrTrackerTolerance)
    #expect(abs(hrv - 85.40044373112873) <= hrTrackerTolerance)
    #expect(abs(skinTemperature - 32.58730047441119) <= hrTrackerTolerance)
}

/// Spec 003, success criterion 2 (respiratory rate, breaths a minute). The expected value is
/// hr-tracker's unrounded output on the same fixture night.
@Test func fixtureNightHasRespiratoryRateMatchingHRTracker() throws {
    let found = nights(from: NightFixture.night20261030, in: london)

    try #require(found.count == 1)
    let night = found[0]
    let respiratoryRate = try #require(night.respiratoryRate)
    #expect(abs(respiratoryRate - 12.151574819458562) <= hrTrackerTolerance)
}

/// Spec 003, success criterion 2 (SpO2, %). The expected value is hr-tracker's unrounded output
/// on the same fixture night.
@Test func fixtureNightHasSpO2MatchingHRTracker() throws {
    let found = nights(from: NightFixture.night20261030, in: london)

    try #require(found.count == 1)
    let night = found[0]
    let spo2 = try #require(night.spo2)
    #expect(abs(spo2 - 98.58333333333333) <= hrTrackerTolerance)
}

/// The unmodified fixture Night, worked out once: the "unchanged" criteria compare against it,
/// and `nights(from:in:)` on the whole fixture takes a few seconds.
private let unmodifiedFixtureNights = nights(from: NightFixture.night20261030, in: london)

/// The fixture night with every SpO2 Window removed: no record is in one or has a reading.
private func fixtureRecordsWithoutSpO2Windows() -> [HistoryRecord] {
    NightFixture.night20261030.map { record in
        HistoryRecord(
            recordCounter: record.recordCounter,
            timestamp: record.timestamp,
            heartRate: record.heartRate,
            rrIntervals: record.rrIntervals,
            motion: record.motion,
            skinTemperature: record.skinTemperature,
            steps: record.steps,
            spo2: 0,
            isInSpO2Window: false,
            rawBytes: record.rawBytes
        )
    }
}

/// The fixture night with every RR interval removed.
private func fixtureRecordsWithoutRRIntervals() -> [HistoryRecord] {
    NightFixture.night20261030.map { record in
        HistoryRecord(
            recordCounter: record.recordCounter,
            timestamp: record.timestamp,
            heartRate: record.heartRate,
            rrIntervals: [],
            motion: record.motion,
            skinTemperature: record.skinTemperature,
            steps: record.steps,
            spo2: record.spo2,
            isInSpO2Window: record.isInSpO2Window,
            rawBytes: record.rawBytes
        )
    }
}

/// Spec 003: the fixture night with every SpO2 Window removed has SpO2 missing and the other
/// four Nightly Metrics unchanged.
@Test func fixtureNightWithoutSpO2WindowsHasSpO2MissingAndOtherMetricsUnchanged() throws {
    try #require(unmodifiedFixtureNights.count == 1)
    let unmodified = unmodifiedFixtureNights[0]
    let found = nights(from: fixtureRecordsWithoutSpO2Windows(), in: london)

    try #require(found.count == 1)
    let night = found[0]
    #expect(night.spo2 == nil)
    #expect(try #require(night.restingHR) == (try #require(unmodified.restingHR)))
    #expect(try #require(night.hrv) == (try #require(unmodified.hrv)))
    #expect(try #require(night.respiratoryRate) == (try #require(unmodified.respiratoryRate)))
    #expect(try #require(night.skinTemperature) == (try #require(unmodified.skinTemperature)))
}

/// Spec 003: the fixture night with every RR interval removed has HRV and respiratory rate
/// missing and Resting HR, skin temperature and SpO2 unchanged.
@Test func fixtureNightWithoutRRIntervalsHasHRVAndRespiratoryRateMissingAndOtherMetricsUnchanged()
    throws
{
    try #require(unmodifiedFixtureNights.count == 1)
    let unmodified = unmodifiedFixtureNights[0]
    let found = nights(from: fixtureRecordsWithoutRRIntervals(), in: london)

    try #require(found.count == 1)
    let night = found[0]
    #expect(night.hrv == nil)
    #expect(night.respiratoryRate == nil)
    #expect(try #require(night.restingHR) == (try #require(unmodified.restingHR)))
    #expect(try #require(night.skinTemperature) == (try #require(unmodified.skinTemperature)))
    #expect(try #require(night.spo2) == (try #require(unmodified.spo2)))
}

// Hand-built History Records (HistoryRecordBuilder.swift). Mid-November 2026, when
// Europe/London is UTC, so every local time below is also the UTC time. Still minutes are sleep
// minutes and moving minutes are wake minutes that mean out of bed, so a still stretch framed by
// moving ones is a Sleep Period from the start of its first still minute to the end of its last.

/// Spec 003: the same records in a different order, or with duplicate History Records, give the
/// same Night.
@Test func recordsInADifferentOrderWithDuplicatesGiveTheSameNight() throws {
    let records = historyRecords(
        startingAt: utcDate(2026, 11, 15, 0, 30),
        [.moving(minutes: 30), .still(minutes: 60), .moving(minutes: 30)]
    )
    let inOrder = nights(from: records, in: london)
    try #require(inOrder.count == 1)

    let shuffled = Array(records.reversed()) + Array(records.prefix(500))
    #expect(nights(from: shuffled, in: london) == inOrder)
}

/// Spec 003: records split across two night windows give one Night per window that has a Sleep
/// Period, each dated by its Final Wake's local date.
@Test func recordsInTwoNightWindowsGiveOneNightEachDatedByFinalWake() throws {
    // Window noon 14 Nov → noon 15 Nov: asleep 01:00–02:00 on 15 Nov.
    let first = historyRecords(
        startingAt: utcDate(2026, 11, 15, 0, 30),
        [.moving(minutes: 30), .still(minutes: 60), .moving(minutes: 30)]
    )
    // Window noon 15 Nov → noon 16 Nov: asleep 02:00–04:00 on 16 Nov.
    let second = historyRecords(
        startingAt: utcDate(2026, 11, 16, 1, 30),
        [.moving(minutes: 30), .still(minutes: 120), .moving(minutes: 30)],
        firstRecordCounter: 100_000
    )

    let found = nights(from: first + second, in: london)

    try #require(found.count == 2)
    #expect(found[0].day == Day(year: 2026, month: 11, day: 15))
    #expect(found[0].sleepOnset == utcDate(2026, 11, 15, 1, 0))
    #expect(found[0].finalWake == utcDate(2026, 11, 15, 2, 0))
    #expect(found[1].day == Day(year: 2026, month: 11, day: 16))
    #expect(found[1].sleepOnset == utcDate(2026, 11, 16, 2, 0))
    #expect(found[1].finalWake == utcDate(2026, 11, 16, 4, 0))
}

/// Spec 003: two windows whose Nights share a date give one Night, the one with more Time
/// Asleep.
@Test func twoNightWindowsWhoseNightsShareADateKeepTheNightWithMoreTimeAsleep() throws {
    // Window noon 14 Nov → noon 15 Nov: asleep 01:00–03:00 on 15 Nov (2 h), dated 15 Nov.
    let earlier = historyRecords(
        startingAt: utcDate(2026, 11, 15, 0, 30),
        [.moving(minutes: 30), .still(minutes: 120), .moving(minutes: 30)]
    )
    // Window noon 15 Nov → noon 16 Nov: asleep 14:00–20:00 on 15 Nov (6 h), also dated 15 Nov.
    let later = historyRecords(
        startingAt: utcDate(2026, 11, 15, 13, 30),
        [.moving(minutes: 30), .still(minutes: 360), .moving(minutes: 30)],
        firstRecordCounter: 100_000
    )

    let found = nights(from: earlier + later, in: london)

    try #require(found.count == 1)
    let night = found[0]
    #expect(night.day == Day(year: 2026, month: 11, day: 15))
    #expect(night.sleepOnset == utcDate(2026, 11, 15, 14, 0))
    #expect(night.finalWake == utcDate(2026, 11, 15, 20, 0))
    let sixHours: TimeInterval? = 6 * 60 * 60
    #expect(night.timeAsleep == sixHours)
}

/// Spec 003: the rule is "more Time Asleep", not "the later window": here the earlier window
/// has more.
@Test func twoNightWindowsWhoseNightsShareADateKeepTheEarlierNightWhenItHasMoreTimeAsleep()
    throws
{
    // Window noon 14 Nov → noon 15 Nov: asleep 01:00–05:00 on 15 Nov (4 h), dated 15 Nov.
    let earlier = historyRecords(
        startingAt: utcDate(2026, 11, 15, 0, 30),
        [.moving(minutes: 30), .still(minutes: 240), .moving(minutes: 30)]
    )
    // Window noon 15 Nov → noon 16 Nov: asleep 14:00–16:00 on 15 Nov (2 h), also dated 15 Nov.
    let later = historyRecords(
        startingAt: utcDate(2026, 11, 15, 13, 30),
        [.moving(minutes: 30), .still(minutes: 120), .moving(minutes: 30)],
        firstRecordCounter: 100_000
    )

    let found = nights(from: earlier + later, in: london)

    try #require(found.count == 1)
    #expect(found[0].sleepOnset == utcDate(2026, 11, 15, 1, 0))
    #expect(found[0].finalWake == utcDate(2026, 11, 15, 5, 0))
}

/// Two windows whose Nights share a date and have equal Time Asleep keep the one that ends
/// first, so the result never depends on the order windows are worked out in.
@Test func twoNightWindowsWhoseNightsShareADateAndTimeAsleepKeepTheOneThatEndsFirst() throws {
    // Both asleep 2 h and dated 15 Nov: 01:00–03:00, then 14:00–16:00.
    let earlier = historyRecords(
        startingAt: utcDate(2026, 11, 15, 0, 30),
        [.moving(minutes: 30), .still(minutes: 120), .moving(minutes: 30)]
    )
    let later = historyRecords(
        startingAt: utcDate(2026, 11, 15, 13, 30),
        [.moving(minutes: 30), .still(minutes: 120), .moving(minutes: 30)],
        firstRecordCounter: 100_000
    )

    let found = nights(from: later + earlier, in: london)

    try #require(found.count == 1)
    #expect(found[0].finalWake == utcDate(2026, 11, 15, 3, 0))
}

/// Spec 003: a window whose longest run of sleep minutes is 6 makes no Night.
@Test func sixSleepMinutesInARowMakeNoNight() {
    let records = historyRecords(
        startingAt: utcDate(2026, 11, 15, 0, 30),
        [.moving(minutes: 30), .still(minutes: 6), .moving(minutes: 30)]
    )

    #expect(nights(from: records, in: london).isEmpty)
}

/// Spec 003: a window whose longest run of sleep minutes is 7 makes one Night.
@Test func sevenSleepMinutesInARowMakeANight() throws {
    let records = historyRecords(
        startingAt: utcDate(2026, 11, 15, 0, 30),
        [.moving(minutes: 30), .still(minutes: 7), .moving(minutes: 30)]
    )

    let found = nights(from: records, in: london)

    try #require(found.count == 1)
    #expect(found[0].sleepOnset == utcDate(2026, 11, 15, 1, 0))
    #expect(found[0].finalWake == utcDate(2026, 11, 15, 1, 7))
    let sevenMinutes: TimeInterval? = 7 * 60
    #expect(found[0].timeAsleep == sevenMinutes)
}

/// Spec 003: a window with no records makes no Night.
@Test func noRecordsMakeNoNight() {
    #expect(nights(from: [], in: london).isEmpty)
}

/// Spec 003: a window with only minutes of fewer than 30 records makes no Night, even when those
/// records are still.
@Test func onlyMinutesWithFewerThanThirtyRecordsMakeNoNight() {
    let records = historyRecords(
        startingAt: utcDate(2026, 11, 15, 1, 0),
        [.sparse(minutes: 120)]
    )

    #expect(nights(from: records, in: london).isEmpty)
}

/// Spec 003: two sleep runs 59 minutes of wake apart make one Sleep Period.
@Test func twoSleepRunsFiftyNineMinutesOfWakeApartMakeOneSleepPeriod() throws {
    let records = historyRecords(
        startingAt: utcDate(2026, 11, 15, 0, 30),
        [
            .moving(minutes: 30), .still(minutes: 60), .moving(minutes: 59), .still(minutes: 30),
            .moving(minutes: 30),
        ]
    )

    let found = nights(from: records, in: london)

    try #require(found.count == 1)
    // Asleep 01:00–02:00 and 02:59–03:29.
    #expect(found[0].sleepOnset == utcDate(2026, 11, 15, 1, 0))
    #expect(found[0].finalWake == utcDate(2026, 11, 15, 3, 29))
    let ninetyMinutes: TimeInterval? = 90 * 60
    #expect(found[0].timeAsleep == ninetyMinutes)
}

/// Spec 003: two sleep runs 60 minutes of wake apart make two Sleep Periods, and the one with
/// more sleep minutes is the Night's.
@Test func twoSleepRunsSixtyMinutesOfWakeApartMakeTwoSleepPeriodsAndTheLongerWins() throws {
    let records = historyRecords(
        startingAt: utcDate(2026, 11, 15, 0, 30),
        [
            .moving(minutes: 30), .still(minutes: 30), .moving(minutes: 60), .still(minutes: 60),
            .moving(minutes: 30),
        ]
    )

    let found = nights(from: records, in: london)

    try #require(found.count == 1)
    // Asleep 01:00–01:30, then 02:30–03:30: the second has more sleep minutes.
    #expect(found[0].sleepOnset == utcDate(2026, 11, 15, 2, 30))
    #expect(found[0].finalWake == utcDate(2026, 11, 15, 3, 30))
    let sixtyMinutes: TimeInterval? = 60 * 60
    #expect(found[0].timeAsleep == sixtyMinutes)
}

/// Spec 003: Resting HR is missing when the Sleep Period has under 30 minutes of records; the
/// Night is still made.
@Test func sleepPeriodWithUnderThirtyMinutesOfRecordsHasRestingHRMissing() throws {
    let records = historyRecords(
        startingAt: utcDate(2026, 11, 15, 0, 30),
        [.moving(minutes: 30), .still(minutes: 20), .moving(minutes: 30)]
    )

    let found = nights(from: records, in: london)

    try #require(found.count == 1)
    #expect(found[0].restingHR == nil)
}

/// Spec 003: a Sleep Period with 30 minutes of records or more has a Resting HR: here the
/// constant 55 bpm of every record.
@Test func sleepPeriodWithFortyMinutesOfRecordsHasRestingHR() throws {
    let records = historyRecords(
        startingAt: utcDate(2026, 11, 15, 0, 30),
        [.moving(minutes: 30), .still(minutes: 40), .moving(minutes: 30)]
    )

    let found = nights(from: records, in: london)

    try #require(found.count == 1)
    let restingHR = try #require(found[0].restingHR)
    #expect(restingHR == 55)
}
