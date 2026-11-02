import Foundation
import SerenixCore
import Testing

// Sleep Score on the Today view's Sleep Score ring (spec 010, Behavior: Sleep Sufficiency,
// Sleep Efficiency, Sleep Score, Missing and left out). Expected values are spec 010's success
// criteria, worked by hand from its rules.

/// 14–15 Nov 2026 is in GMT here (BST ended on 25 Oct), so local time equals UTC.
private let london = TimeZone(identifier: "Europe/London")!

/// 2026-11-15T08:12:00Z, 08:12 local in London.
private let now = Date(timeIntervalSince1970: 1_794_730_320)

private let nov15 = Day(year: 2026, month: 11, day: 15)

private let oneHour: TimeInterval = 3_600

private let oneMinute: TimeInterval = 60

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

/// `hour`:`minute` UTC (and so London local time) on `day` Nov 2026.
private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar.date(
        from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute)
    )!
}

/// The Night shown, dated 15 Nov: by default Sleep Onset 23:00 on 14 Nov, Final Wake 07:00 and
/// Time Asleep 8 h (spec 010's default fixture).
private func nightOn15Nov(
    sleepOnset: Date? = at(14, 23),
    finalWake: Date? = at(15, 7),
    timeAsleep: TimeInterval? = 8 * oneHour
) -> Night {
    Night(
        day: nov15,
        sleepOnset: sleepOnset,
        finalWake: finalWake,
        timeAsleep: timeAsleep
    )
}

/// Earlier Nights dated 14 Nov, 13 Nov and so on back, with the given Time Asleep in that order
/// and no Sleep Onset or Final Wake.
private func earlierNights(_ timesAsleep: [TimeInterval]) -> [Night] {
    timesAsleep.enumerated().map { offset, timeAsleep in
        Night(day: Day(year: 2026, month: 11, day: 14 - offset), timeAsleep: timeAsleep)
    }
}

// MARK: Score and Sleep Sufficiency

@Test func theDefaultNightReads100WithTheRingFull() {
    let view = todayView(nights: [nightOn15Nov()])

    #expect(view.sleepScoreText == "100")
    #expect(view.sleepScoreFill == 1.0)
}

@Test func sixHoursAsleepAgainstASleepNeedOf8HoursReads81() {
    let view = todayView(nights: [nightOn15Nov(finalWake: at(15, 5, 18), timeAsleep: 6 * oneHour)])

    #expect(view.sleepScoreText == "81")
}

@Test func timeAsleep7Hours36Reads96AndTheRingFillsTo096() {
    let view = todayView(nights: [nightOn15Nov(timeAsleep: 7 * oneHour + 36 * oneMinute)])

    #expect(view.sleepScoreText == "96")
    #expect(view.sleepScoreFill == 0.96)
}

@Test func aSleepNeedRaisedTo9HoursLowersSleepSufficiency() {
    let view = todayView(
        nights: [nightOn15Nov()] + earlierNights(Array(repeating: 6 * oneHour, count: 4))
    )

    #expect(view.sleepScoreText == "92")
}

// MARK: Sleep Efficiency

@Test func eightHoursAsleepInANineHourSleepPeriodReads92() {
    let view = todayView(nights: [nightOn15Nov(sleepOnset: at(14, 22))])

    #expect(view.sleepScoreText == "92")
}

@Test func sleepEfficiencyBelow75PercentScoresZeroAndReads75() {
    let view = todayView(nights: [nightOn15Nov(sleepOnset: at(14, 20))])

    #expect(view.sleepScoreText == "75")
}

@Test func withNoSleepOnsetSleepEfficiencyIsLeftOutAndSleepSufficiencyAloneReads75() {
    let view = todayView(nights: [nightOn15Nov(sleepOnset: nil, timeAsleep: 6 * oneHour)])

    #expect(view.sleepScoreText == "75")
}

@Test func timeAsleepLongerThanTheSleepPeriodLeavesOutSleepEfficiencyAndReads100() {
    let view = todayView(nights: [nightOn15Nov(sleepOnset: at(14, 23, 30))])

    #expect(view.sleepScoreText == "100")
}

// MARK: Missing and where it shows

@Test func aNightWithNoTimeAsleepHasNoSleepScoreAndAnEmptyRing() {
    let view = todayView(nights: [nightOn15Nov(timeAsleep: nil)])

    #expect(view.sleepScoreText == "\u{2014}")
    #expect(view.sleepScoreFill == 0)
}

@Test func theReadinessPopupsSleepScoreRowShowsTheNightsSleepScore() {
    // Spec 008's usual HRV 60 ms and Sleeping HR 52 bpm on four earlier Nights (14 to 11 Nov),
    // with no Time Asleep, Sleep Onset or Final Wake, so Readiness is past Calibrating and Sleep
    // Need stays 8 h. Time Asleep 7 h 36 m in 23:00 to 07:00 reads 96.
    let earlier = (11...14).map { day in
        Night(day: Day(year: 2026, month: 11, day: day), sleepingHR: 52, hrv: 60)
    }
    var shown = nightOn15Nov(timeAsleep: 7 * oneHour + 36 * oneMinute)
    shown.sleepingHR = 52
    shown.hrv = 60

    let popup = todayView(nights: earlier + [shown]).readinessPopup

    #expect(popup?.sleepScoreText == "96")
}
