import Foundation
import SerenixCore
import Testing

/// 1 Nov 2026 is in GMT here (BST ended on 25 Oct), so local time equals UTC.
private let london = TimeZone(identifier: "Europe/London")!
/// 2026-11-01T08:12:00Z, 08:12 local in London.
private let now = Date(timeIntervalSince1970: 1_793_520_720)
private let nov1 = Day(year: 2026, month: 11, day: 1)
/// 2026-10-31T23:18:00Z, 23:18 local in London.
private let onsetOct31At2318 = Date(timeIntervalSince1970: 1_793_488_680)
/// 2026-11-01T06:51:00Z, 06:51 local in London.
private let finalWakeNov1At0651 = Date(timeIntervalSince1970: 1_793_515_860)
/// Time Asleep of 7 h 12 m.
private let sevenHoursTwelve: TimeInterval = 25_920

private func storyForNov1() -> TodayStory {
    TodayView(
        nights: [
            Night(
                day: nov1,
                sleepOnset: onsetOct31At2318,
                finalWake: finalWakeNov1At0651,
                timeAsleep: sevenHoursTwelve
            )
        ],
        dayLoads: [],
        showing: nov1,
        now: now,
        timeZone: london,
        sync: .idle,
        profileName: nil
    ).story
}

@Test func aDayWithANightTellsItsStoryInFourStepsInOrder() {
    #expect(storyForNov1().steps.map(\.kind) == [.sleep, .overnight, .thisMorning, .todaySoFar])
}

@Test func theSleepStepRunsFromSleepOnsetToFinalWakeAndSaysHowLongYouSlept() {
    let sleep = storyForNov1().steps.first { $0.kind == .sleep }
    #expect(sleep?.timeLabel == "23:18 \u{2192} 06:51")
    #expect(sleep?.title == "You slept 7h 12m")
}

// MARK: Overnight step

private let oct29 = Day(year: 2026, month: 10, day: 29)

private let oct30 = Day(year: 2026, month: 10, day: 30)

private let oct31 = Day(year: 2026, month: 10, day: 31)

/// The Overnight step for 1 Nov's Night, after `earlier` Nights.
private func overnightStep(_ night: Night, earlier: [Night] = []) -> StoryStep? {
    TodayView(
        nights: earlier + [night],
        dayLoads: [],
        showing: nov1,
        now: now,
        timeZone: london,
        sync: .idle,
        profileName: nil
    ).story.steps.first { $0.kind == .overnight }
}

@Test func theOvernightStepIsLabelledOvernightAndTitledNightlyMetrics() {
    let overnight = overnightStep(Night(day: nov1, sleepingHR: 52))
    #expect(overnight?.timeLabel == "Overnight")
    #expect(overnight?.title == "Nightly Metrics")
}

@Test func theOvernightStepListsOnlyTheNightlyMetricsTheNightHas() {
    let overnight = overnightStep(Night(day: nov1, sleepingHR: 52, spo2: 97))
    #expect(overnight?.metrics.map(\.metric) == [.sleepingHR, .spo2])
}

@Test func otherStepsListNoNightlyMetrics() {
    let steps = storyForNov1().steps.filter { $0.kind != .overnight }
    #expect(steps.allSatisfy { $0.metrics.isEmpty })
}

@Test func eachOvernightMetricCarriesItsZone() {
    // Three earlier Nights at Sleeping HR 52 give a Baseline of 52 bpm; 52 is In range.
    // SpO2 97% is at or above 95%, its fixed In range level. 91% is below 92%, Out of range.
    let earlier = [oct29, oct30, oct31].map { Night(day: $0, sleepingHR: 52) }
    let overnight = overnightStep(Night(day: nov1, sleepingHR: 52, spo2: 97), earlier: earlier)
    #expect(overnight?.metrics.map(\.zone) == [.inRange, .inRange])

    let lowSpO2 = overnightStep(Night(day: nov1, spo2: 91))
    #expect(lowSpO2?.metrics.map(\.zone) == [.outOfRange])
}
