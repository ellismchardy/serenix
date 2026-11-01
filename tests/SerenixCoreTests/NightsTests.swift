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
/// same fixture night (units: bpm, ms, °C).
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
