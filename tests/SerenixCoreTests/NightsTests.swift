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
