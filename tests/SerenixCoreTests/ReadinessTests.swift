import Foundation
import SerenixCore
import Testing

// Readiness on the Today view (spec 008, Behavior: Inputs, Score, Calibrating and missing).
// Expected values are spec 008's success criteria (Score; Missing, dropped and Calibrating).

/// 15 Nov 2026 is in GMT here (BST ended on 25 Oct), so local time equals UTC.
private let london = TimeZone(identifier: "Europe/London")!

/// 2026-11-15T08:12:00Z, 08:12 local in London.
private let now = Date(timeIntervalSince1970: 1_794_730_320)

private let nov15 = Day(year: 2026, month: 11, day: 15)

private let oneHour: TimeInterval = 3_600

private func todayView(nights: [Night]) -> TodayView {
    TodayView(
        nights: nights,
        dayLoads: [],
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
    earlierNights: Int = 4
) -> TodayView {
    todayView(nights: usualNightsBefore15Nov(count: earlierNights) + [night])
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

// MARK: Missing and Calibrating

@Test func aNightWithNoHRVHasNoReadiness() {
    let view = readinessView(for: nightOn15Nov(hrv: nil))

    #expect(view.readinessText == "—")
    #expect(view.readinessBand == nil)
    #expect(view.readinessAdvice == nil)
}

@Test func threeEarlierNightsAreEnoughForAReadinessNumber() {
    let view = readinessView(for: nightOn15Nov(), earlierNights: 3)

    #expect(view.readinessText == "70")
}
