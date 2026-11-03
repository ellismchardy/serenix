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

/// Spec 003, success criterion 2 (Sleeping HR, HRV and skin temperature). Expected values are
/// hr-tracker's unrounded output on the same fixture night.
@Test func fixtureNightHasSleepingHRHRVAndSkinTemperatureMatchingHRTracker() throws {
    let found = nights(from: NightFixture.night20261030, in: london)

    try #require(found.count == 1)
    let night = found[0]
    let sleepingHR = try #require(night.sleepingHR)
    let hrv = try #require(night.hrv)
    let skinTemperature = try #require(night.skinTemperature)
    #expect(abs(sleepingHR - 48.11506392440245) <= hrTrackerTolerance)
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
    #expect(try #require(night.sleepingHR) == (try #require(unmodified.sleepingHR)))
    #expect(try #require(night.hrv) == (try #require(unmodified.hrv)))
    #expect(try #require(night.respiratoryRate) == (try #require(unmodified.respiratoryRate)))
    #expect(try #require(night.skinTemperature) == (try #require(unmodified.skinTemperature)))
}

/// Spec 003: the fixture night with every RR interval removed has HRV and respiratory rate
/// missing and Sleeping HR, skin temperature and SpO2 unchanged.
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
    #expect(try #require(night.sleepingHR) == (try #require(unmodified.sleepingHR)))
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

/// Spec 003: Sleeping HR is missing when the Sleep Period has under 30 minutes of records; the
/// Night is still made.
@Test func sleepPeriodWithUnderThirtyMinutesOfRecordsHasSleepingHRMissing() throws {
    let records = historyRecords(
        startingAt: utcDate(2026, 11, 15, 0, 30),
        [.moving(minutes: 30), .still(minutes: 20), .moving(minutes: 30)]
    )

    let found = nights(from: records, in: london)

    try #require(found.count == 1)
    #expect(found[0].sleepingHR == nil)
}

/// Spec 003: a Sleep Period with 30 minutes of records or more has a Sleeping HR: here the
/// constant 55 bpm of every record.
@Test func sleepPeriodWithFortyMinutesOfRecordsHasSleepingHR() throws {
    let records = historyRecords(
        startingAt: utcDate(2026, 11, 15, 0, 30),
        [.moving(minutes: 30), .still(minutes: 40), .moving(minutes: 30)]
    )

    let found = nights(from: records, in: london)

    try #require(found.count == 1)
    let sleepingHR = try #require(found[0].sleepingHR)
    #expect(sleepingHR == 55)
}

// Spec 011: the Heart Rate Trace. Hand-built records for the night of 15–16 Nov 2026 (UTC is
// local time in Europe/London): up and about 22:30–23:00, awake in bed (15 active seconds a
// minute: wake, but not up) 23:00–23:10, still 23:10–06:50, awake in bed 06:50–07:00, up and
// about 07:00–07:30. So the Sleep Period is 23:10–06:50 and Time in Bed 23:00–07:00. Motion alone
// drives sleep and wake; the heart rates of the step at 03:00 are set per test.

/// The trace step that starts at 03:00: 4 hours (48 steps of 5 minutes) after 23:00.
private let stepAt0300 = 48

/// The night above, every record at 55 bpm except the 300 records of 03:00–03:05, whose heart
/// rate is `bpmAt0300(second)` for second 0 to 299 of that step.
private func nightInBed2300To0700(bpmAt0300: (Int) -> Int = { _ in 55 }) -> [HistoryRecord] {
    let up = RecordMinute(bpm: 55, activeSeconds: 60)
    let awakeInBed = RecordMinute(bpm: 55, activeSeconds: 15)
    let still = RecordMinute(bpm: 55)
    let minutes =
        Array(repeating: up, count: 30) + Array(repeating: awakeInBed, count: 10)
        + Array(repeating: still, count: 460) + Array(repeating: awakeInBed, count: 10)
        + Array(repeating: up, count: 30)
    let stepStart = utcDate(2026, 11, 16, 3, 0)
    return historyRecords(startingAt: utcDate(2026, 11, 15, 22, 30), minutes: minutes).map {
        record in
        let second = Int(record.timestamp.timeIntervalSince(stepStart))
        guard (0..<300).contains(second) else { return record }
        return HistoryRecord(
            recordCounter: record.recordCounter,
            timestamp: record.timestamp,
            heartRate: bpmAt0300(second),
            rrIntervals: record.rrIntervals,
            motion: record.motion,
            skinTemperature: record.skinTemperature,
            steps: record.steps,
            spo2: record.spo2,
            isInSpO2Window: record.isInSpO2Window,
            rawBytes: record.rawBytes
        )
    }
}

/// Spec 011: a Night whose Time in Bed is 23:00–07:00 has a Heart Rate Trace of 96 steps, the
/// first starting at 23:00 (Time in Bed's start, not Sleep Onset's 23:10).
@Test func nightInBed2300To0700HasHeartRateTraceOfNinetySixStepsFrom2300() throws {
    let found = nights(from: nightInBed2300To0700(), in: london)

    try #require(found.count == 1)
    let night = found[0]
    #expect(night.sleepOnset == utcDate(2026, 11, 15, 23, 10))
    #expect(night.finalWake == utcDate(2026, 11, 16, 6, 50))
    #expect(night.timeInBedStart == utcDate(2026, 11, 15, 23, 0))
    #expect(night.timeInBedEnd == utcDate(2026, 11, 16, 7, 0))
    let trace = try #require(night.heartRateTrace)
    #expect(trace.start == utcDate(2026, 11, 15, 23, 0))
    #expect(trace.steps.count == 96)
}

/// Spec 011: the last step may be shorter. Three more still minutes make Time in Bed 23:00–07:03,
/// so 97 steps, the last 3 minutes long: its 180 records at 55 bpm still reach 150, reading 55.
@Test func aTimeInBedOfPartStepsEndsWithAShorterLastStep() throws {
    let up = RecordMinute(bpm: 55, activeSeconds: 60)
    let awakeInBed = RecordMinute(bpm: 55, activeSeconds: 15)
    let still = RecordMinute(bpm: 55)
    let minutes =
        Array(repeating: up, count: 30) + Array(repeating: awakeInBed, count: 10)
        + Array(repeating: still, count: 463) + Array(repeating: awakeInBed, count: 10)
        + Array(repeating: up, count: 30)
    let records = historyRecords(startingAt: utcDate(2026, 11, 15, 22, 30), minutes: minutes)

    let found = nights(from: records, in: london)

    try #require(found.count == 1)
    #expect(found[0].timeInBedEnd == utcDate(2026, 11, 16, 7, 3))
    let trace = try #require(found[0].heartRateTrace)
    #expect(trace.steps.count == 97)
    let last: Double? = 55
    #expect(trace.steps.last == last)
}

/// The Heart Rate Trace step at 03:00 of the night above, with `bpmAt0300` setting its records'
/// heart rates.
private func heartRateTraceStepAt0300(bpmAt0300: (Int) -> Int) throws -> Double? {
    let found = nights(from: nightInBed2300To0700(bpmAt0300: bpmAt0300), in: london)
    try #require(found.count == 1)
    let trace = try #require(found[0].heartRateTrace)
    try #require(trace.steps.count == 96)
    return trace.steps[stepAt0300]
}

/// Spec 011: a step of 300 records at 60 bpm reads 60.
@Test func heartRateTraceStepOfThreeHundredRecordsAtSixtyReadsSixty() throws {
    let step = try heartRateTraceStepAt0300 { _ in 60 }
    let sixty: Double? = 60
    #expect(step == sixty)
}

/// Spec 011: a step of 150 records at 50 bpm and 150 at 70 reads their mean, 60.
@Test func heartRateTraceStepOfHalfAtFiftyAndHalfAtSeventyReadsSixty() throws {
    let step = try heartRateTraceStepAt0300 { second in second < 150 ? 50 : 70 }
    let sixty: Double? = 60
    #expect(step == sixty)
}

/// Spec 011: records at 0 bpm are left out of a step's mean: 150 at 60 and 150 at 0 read 60.
@Test func heartRateTraceStepLeavesOutRecordsAtZeroBPM() throws {
    let step = try heartRateTraceStepAt0300 { second in second < 150 ? 60 : 0 }
    let sixty: Double? = 60
    #expect(step == sixty)
}

/// Spec 011: a step with fewer than 150 records with a non-zero heart rate is missing: 149 at
/// 60 and 151 at 0.
@Test func heartRateTraceStepWithOneHundredFortyNineNonZeroRecordsIsMissing() throws {
    let step = try heartRateTraceStepAt0300 { second in second < 149 ? 60 : 0 }
    #expect(step == nil)
}

// Spec 011: Wake Bouts.

/// Spec 011: a Night whose Sleep Period has wake minutes 02:00 to 02:07 and no other wake has one
/// Wake Bout, starting 02:00, 8 minutes long. The night of `nightInBed2300To0700`, but awake in bed
/// (15 active seconds a minute) for the 8 minutes 02:00–02:07 inside the still stretch. Heart rate
/// stays flat at 55 bpm, so it never extends the bout; each still minute either side has a
/// 5-minute median of 0 active seconds, so the bout neither grows nor shrinks. 8 minutes of wake
/// is under 60, so the Sleep Period still runs 23:10–06:50.
@Test func nightWithWakeMinutes0200To0207HasOneWakeBoutAt0200OfEightMinutes() throws {
    let up = RecordMinute(bpm: 55, activeSeconds: 60)
    let awakeInBed = RecordMinute(bpm: 55, activeSeconds: 15)
    let still = RecordMinute(bpm: 55)
    // 23:10–02:00 is 170 still minutes, then 8 awake, then 282 still to 06:50.
    let minutes =
        Array(repeating: up, count: 30) + Array(repeating: awakeInBed, count: 10)
        + Array(repeating: still, count: 170) + Array(repeating: awakeInBed, count: 8)
        + Array(repeating: still, count: 282) + Array(repeating: awakeInBed, count: 10)
        + Array(repeating: up, count: 30)
    let records = historyRecords(startingAt: utcDate(2026, 11, 15, 22, 30), minutes: minutes)

    let found = nights(from: records, in: london)

    try #require(found.count == 1)
    let night = found[0]
    #expect(night.sleepOnset == utcDate(2026, 11, 15, 23, 10))
    #expect(night.finalWake == utcDate(2026, 11, 16, 6, 50))
    let wakeBouts = try #require(night.wakeBouts)
    #expect(wakeBouts == [WakeBout(start: utcDate(2026, 11, 16, 2, 0), minutes: 8)])
}

/// Spec 011: two Wake Bouts come oldest first, each with its own start and length (the spec's
/// 02:10 for 8 min and 04:30 for 7 min).
@Test func nightWithTwoWakeStretchesHasTwoWakeBoutsOldestFirst() throws {
    let up = RecordMinute(bpm: 55, activeSeconds: 60)
    let awakeInBed = RecordMinute(bpm: 55, activeSeconds: 15)
    let still = RecordMinute(bpm: 55)
    // 23:10–02:10 still (180), 8 awake, 02:18–04:30 still (132), 7 awake, 04:37–06:50 still
    // (133).
    let minutes =
        Array(repeating: up, count: 30) + Array(repeating: awakeInBed, count: 10)
        + Array(repeating: still, count: 180) + Array(repeating: awakeInBed, count: 8)
        + Array(repeating: still, count: 132) + Array(repeating: awakeInBed, count: 7)
        + Array(repeating: still, count: 133) + Array(repeating: awakeInBed, count: 10)
        + Array(repeating: up, count: 30)
    let records = historyRecords(startingAt: utcDate(2026, 11, 15, 22, 30), minutes: minutes)

    let found = nights(from: records, in: london)

    try #require(found.count == 1)
    let wakeBouts = try #require(found[0].wakeBouts)
    #expect(
        wakeBouts == [
            WakeBout(start: utcDate(2026, 11, 16, 2, 10), minutes: 8),
            WakeBout(start: utcDate(2026, 11, 16, 4, 30), minutes: 7),
        ]
    )
}

/// Spec 011: a Night with no wake between Sleep Onset and Final Wake has Wake Bouts kept, and
/// none ("Didn't wake"), not missing.
@Test func nightWithNoWakeInsideItsSleepPeriodHasNoWakeBouts() throws {
    let found = nights(from: nightInBed2300To0700(), in: london)

    try #require(found.count == 1)
    let wakeBouts = try #require(found[0].wakeBouts)
    #expect(wakeBouts.isEmpty)
}

/// Spec 011: the fixture night's Wake Bouts add up to its Final Wake − Sleep Onset − Time Asleep,
/// in minutes, and its Sleep Period and Time in Bed are unchanged. Spec 003's literals: Sleep
/// Onset 21:05, Final Wake 03:42 (6 h 37 m apart) and Time Asleep 5 h 52 m, so 45 minutes awake.
@Test func fixtureNightWakeBoutsAddUpToItsMinutesAwakeAndItsSleepPeriodIsUnchanged() throws {
    let found = unmodifiedFixtureNights

    try #require(found.count == 1)
    let night = found[0]
    // 2026-10-29 21:05:00 UTC
    #expect(night.sleepOnset == Date(timeIntervalSince1970: 1_793_307_900))
    // 2026-10-30 03:42:00 UTC
    #expect(night.finalWake == Date(timeIntervalSince1970: 1_793_331_720))
    // 2026-10-29 20:57:00 UTC
    #expect(night.timeInBedStart == Date(timeIntervalSince1970: 1_793_307_420))
    // 2026-10-30 04:00:00 UTC
    #expect(night.timeInBedEnd == Date(timeIntervalSince1970: 1_793_332_800))
    let fiveHoursFiftyTwo: TimeInterval? = 352 * 60
    #expect(night.timeAsleep == fiveHoursFiftyTwo)
    let wakeBouts = try #require(night.wakeBouts)
    #expect(wakeBouts.map(\.minutes).reduce(0, +) == 45)
}
