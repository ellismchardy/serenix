import Foundation
import SerenixCore
import Testing

// Readiness on the Today view (spec 008, Behavior: Inputs, Score, Sleeping HR's Spread,
// Calibrating and missing, dropped inputs, Always current).
// Expected values are spec 008's success criteria (Score; Sleeping HR's Spread;
// Missing, dropped and Calibrating; Always current).

/// 15 Nov 2026 is in GMT here (BST ended on 25 Oct), so local time equals UTC.
private let london = TimeZone(identifier: "Europe/London")!

/// 2026-11-15T08:12:00Z, 08:12 local in London.
private let now = Date(timeIntervalSince1970: 1_794_730_320)

private let nov14 = Day(year: 2026, month: 11, day: 14)
private let nov15 = Day(year: 2026, month: 11, day: 15)

private let oneHour: TimeInterval = 3_600

private func todayView(nights: [Night], dayLoads: [DayLoad] = []) -> TodayView {
    TodayView(
        nights: nights,
        dayLoads: dayLoads,
        showing: nov15,
        now: now,
        timeZone: london,
        sync: .idle,
        profileName: nil
    )
}

/// `count` earlier Nights on the Days before 15 Nov (14 Nov, 13 Nov, …), each with HRV 60 ms and
/// Sleeping HR 52 bpm. With 3 to 6 of them the Spreads are the typical ones: HRV 0.15 (on ln
/// RMSSD) and Sleeping HR 2.5 bpm.
private func usualNightsBefore15Nov(count: Int = 4) -> [Night] {
    (1...count).map { daysBefore in
        Night(day: Day(year: 2026, month: 11, day: 15 - daysBefore), sleepingHR: 52, hrv: 60)
    }
}

/// The Night dated 15 Nov: by default the usual one (HRV 60 ms, Sleeping HR 52 bpm, Time Asleep
/// 7 h). It carries no stored Readiness.
private func nightOn15Nov(
    hrv: Double? = 60,
    sleepingHR: Double? = 52,
    timeAsleep: TimeInterval = 7 * oneHour
) -> Night {
    Night(day: nov15, sleepingHR: sleepingHR, hrv: hrv, timeAsleep: timeAsleep)
}

private func readinessView(
    for night: Night,
    earlierNights: Int = 4,
    dayLoads: [DayLoad] = []
) -> TodayView {
    todayView(nights: usualNightsBefore15Nov(count: earlierNights) + [night], dayLoads: dayLoads)
}

/// `count` Days before 14 Nov (13 Nov, 12 Nov, …), each at Load 45, so with 4 of them typical
/// Load for 14 Nov is 45; with fewer it is calibrating.
private func daysBefore14NovAtLoad45(count: Int = 4) -> [DayLoad] {
    (1...count).map { daysBefore in
        DayLoad(day: Day(year: 2026, month: 11, day: 14 - daysBefore), load: 45)
    }
}

/// Four Days before 14 Nov at Load 45 (typical Load 45), and 14 Nov at `load`.
private func dayLoadsWith14NovAt(_ load: Int) -> [DayLoad] {
    daysBefore14NovAtLoad45() + [DayLoad(day: nov14, load: load)]
}

// MARK: Score

@Test func aUsualNightReads70AndReady() {
    let view = readinessView(for: nightOn15Nov())

    #expect(view.readinessText == "70")
    #expect(view.readinessBand == .ready)
}

@Test func anHRVBelowBaselineLowersReadinessToSteady() {
    let view = readinessView(for: nightOn15Nov(hrv: 50))

    #expect(view.readinessText == "38")
    #expect(view.readinessBand == .steady)
}

@Test func anHRVAboveBaselineRaisesReadiness() {
    let view = readinessView(for: nightOn15Nov(hrv: 72))

    #expect(view.readinessText == "90")
    #expect(view.readinessBand == .ready)
}

@Test func aFarLowHRVIsClampedAndReadsTakeItEasy() {
    let view = readinessView(for: nightOn15Nov(hrv: 20))

    #expect(view.readinessText == "8")
    #expect(view.readinessBand == .takeItEasy)
}

@Test func aSleepingHRAboveBaselineLowersReadiness() {
    let view = readinessView(for: nightOn15Nov(sleepingHR: 57))

    #expect(view.readinessText == "43")
}

@Test func aSleepingHRBelowBaselineRaisesReadiness() {
    let view = readinessView(for: nightOn15Nov(sleepingHR: 48))

    #expect(view.readinessText == "85")
}

@Test func timeAsleepShortOfSevenHoursLowersReadiness() {
    let view = readinessView(for: nightOn15Nov(timeAsleep: 5 * oneHour))

    #expect(view.readinessText == "54")
}

@Test func timeAsleepAMinuteShortOfSevenHoursStillReads70() {
    let view = readinessView(for: nightOn15Nov(timeAsleep: 6 * oneHour + 59 * 60))

    #expect(view.readinessText == "70")
}

@Test func timeAsleepPastSevenHoursAddsNothing() {
    let view = readinessView(for: nightOn15Nov(timeAsleep: 9 * oneHour))

    #expect(view.readinessText == "70")
}

@Test func aPreviousDaysLoadAtOrBelowTypicalLoadStillReads70() {
    let view = readinessView(for: nightOn15Nov(), dayLoads: dayLoadsWith14NovAt(40))

    #expect(view.readinessText == "70")
}

@Test func aPreviousDaysLoadAboveTypicalLoadLowersReadinessToSteady() {
    let view = readinessView(for: nightOn15Nov(), dayLoads: dayLoadsWith14NovAt(65))

    #expect(view.readinessText == "65")
    #expect(view.readinessBand == .steady)
}

@Test func aPreviousDaysLoadFarAboveTypicalLoadLowersReadinessFurther() {
    let view = readinessView(for: nightOn15Nov(), dayLoads: dayLoadsWith14NovAt(85))

    #expect(view.readinessText == "61")
}

@Test func aPreviousDaysLoadFarAboveTypicalLoadIsClamped() {
    let view = readinessView(for: nightOn15Nov(), dayLoads: dayLoadsWith14NovAt(200))

    #expect(view.readinessText == "56")
}

@Test func allFourInputsOffAtOnceReadTakeItEasy() {
    let view = readinessView(
        for: nightOn15Nov(hrv: 50, sleepingHR: 57, timeAsleep: 5 * oneHour + 30 * 60),
        dayLoads: dayLoadsWith14NovAt(85)
    )

    #expect(view.readinessText == "10")
    #expect(view.readinessBand == .takeItEasy)
}

@Test func theLoadOfTheNightsOwnDayIsNotUsed() {
    let view = readinessView(
        for: nightOn15Nov(),
        dayLoads: dayLoadsWith14NovAt(45) + [DayLoad(day: nov15, load: 200)]
    )

    #expect(view.readinessText == "70")
}

// MARK: Missing, dropped and Calibrating

@Test func aNightWithNoHRVHasNoReadiness() {
    let view = readinessView(for: nightOn15Nov(hrv: nil))

    #expect(view.readinessText == "—")
    #expect(view.readinessBand == nil)
    #expect(view.readinessAdvice == nil)
}

@Test func aNightWithNoSleepingHRStillHasAReadinessFromHRVAndTimeAsleep() {
    let view = readinessView(for: nightOn15Nov(hrv: 50, sleepingHR: nil))

    #expect(view.readinessText == "26")
    #expect(view.readinessBand == .takeItEasy)
}

@Test func threeEarlierNightsAreEnoughForAReadinessNumber() {
    let view = readinessView(for: nightOn15Nov(), earlierNights: 3)

    #expect(view.readinessText == "70")
}

@Test func aPreviousDaysLoadWithTypicalLoadCalibratingChangesNothing() {
    let view = readinessView(
        for: nightOn15Nov(),
        dayLoads: daysBefore14NovAtLoad45(count: 3) + [DayLoad(day: nov14, load: 85)]
    )

    #expect(view.readinessText == "70")
}

@Test func noDayForThePreviousDayChangesNothing() {
    let view = readinessView(for: nightOn15Nov(), dayLoads: daysBefore14NovAtLoad45())

    #expect(view.readinessText == "70")
}

@Test func aPreviousDayWithMissingLoadChangesNothing() {
    let view = readinessView(
        for: nightOn15Nov(),
        dayLoads: daysBefore14NovAtLoad45() + [
            DayLoad(day: nov14, load: nil, missingReason: .noMaxHR)
        ]
    )

    #expect(view.readinessText == "70")
}

// MARK: Always current

@Test func readinessFollowsThePreviousDaysLoadOnceItArrives() {
    let nights = usualNightsBefore15Nov() + [nightOn15Nov()]

    let before = todayView(nights: nights, dayLoads: daysBefore14NovAtLoad45())
    let after = todayView(nights: nights, dayLoads: dayLoadsWith14NovAt(85))

    #expect(before.readinessText == "70")
    #expect(after.readinessText == "61")
}

// MARK: Sleeping HR's Spread

/// Earlier Nights on the Days before 15 Nov (14 Nov, 13 Nov, …), one per Sleeping HR given, in
/// that order, each with HRV 60 ms.
private func earlierNightsBefore15Nov(sleepingHRs: [Double]) -> [Night] {
    sleepingHRs.enumerated().map { index, sleepingHR in
        Night(day: Day(year: 2026, month: 11, day: 14 - index), sleepingHR: sleepingHR, hrv: 60)
    }
}

private func readinessView(for night: Night, earlierSleepingHRs: [Double]) -> TodayView {
    todayView(nights: earlierNightsBefore15Nov(sleepingHRs: earlierSleepingHRs) + [night])
}

@Test func aSleepingHRTwoAboveBaselineWithFourEarlierNightsUsesTheTypicalSpread() {
    let view = readinessView(for: nightOn15Nov(sleepingHR: 54), earlierNights: 4)

    #expect(view.readinessText == "60")
}

@Test func aSleepingHRTwoAboveBaselineWithSevenIdenticalEarlierNightsUsesTheFlooredSpread() {
    let view = readinessView(
        for: nightOn15Nov(sleepingHR: 54),
        earlierSleepingHRs: Array(repeating: 52, count: 7)
    )

    #expect(view.readinessText == "43")
}

@Test func aSleepingHRAgainstSevenVaryingEarlierNightsUsesTheScaledMAD() {
    let view = readinessView(
        for: nightOn15Nov(sleepingHR: 56),
        earlierSleepingHRs: [50, 51, 52, 52, 52, 53, 54]
    )

    #expect(view.readinessText == "34")
}

// Spec 004's fixed +3 / +5 bpm gaps still set the Sleeping HR Zone; Sleeping HR's Spread doesn't.
@Test(arguments: [(54, .inRange), (56, .watch)] as [(Double, Zone)])
func theSleepingHRZoneIgnoresItsSpread(sleepingHR: Double, zone: Zone) {
    let view = readinessView(
        for: nightOn15Nov(sleepingHR: sleepingHR),
        earlierSleepingHRs: Array(repeating: 52, count: 7)
    )

    #expect(view.tile(.sleepingHR)?.zone == zone)
}
