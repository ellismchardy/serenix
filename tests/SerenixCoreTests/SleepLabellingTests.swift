import Foundation
import SerenixCore
import Testing

/// 2027-01-15 08:00:00 UTC, a whole UTC minute.
private let wholeMinute = Date(timeIntervalSince1970: 1_800_000_000)

/// `minutes` whole minutes of one-second labelling input from `wholeMinute`, every second
/// with a heart rate of 60 bpm and the same `angle`.
private func seconds(minutes: Int, angle: Double?) -> [LabellingSecond] {
    (0..<(minutes * 60)).map {
        LabellingSecond(
            time: wholeMinute.addingTimeInterval(TimeInterval($0)),
            heartRate: 60,
            angle: angle
        )
    }
}

/// Spec 019, labeller seam: a second is active only when its angle is above the threshold, so
/// 2.0° is still at a 2° threshold.
@Test func secondsMovingExactlyTheThresholdLabelEveryMinuteSleep() {
    let labelling = SleepWakeLabeller.label(
        seconds(minutes: 20, angle: 2.0),
        activeAboveDegrees: 2.0
    )

    #expect(labelling.minutes.count == 20)
    #expect(labelling.minutes.allSatisfy { $0.label == .sleep })
}

/// Spec 019, labeller seam: 2.0° is above a 1.9° threshold, so every second is active and every
/// minute is wake.
@Test func secondsMovingAboveTheThresholdLabelEveryMinuteWake() {
    let labelling = SleepWakeLabeller.label(
        seconds(minutes: 20, angle: 2.0),
        activeAboveDegrees: 1.9
    )

    #expect(labelling.minutes.count == 20)
    #expect(labelling.minutes.allSatisfy { $0.label == .wake })
}

/// Spec 019, labeller seam: a second with no angle is never active, whatever the threshold.
@Test func secondsWithNoAngleAreNeverActiveEvenBelowAZeroThreshold() {
    let labelling = SleepWakeLabeller.label(
        seconds(minutes: 20, angle: nil),
        activeAboveDegrees: -1
    )

    #expect(labelling.minutes.count == 20)
    #expect(labelling.minutes.allSatisfy { $0.label == .sleep })
}

/// Spec 019, labeller seam: a minute with 29 seconds has no data; one with 30 has.
@Test func aMinuteNeedsThirtySecondsToHaveData() throws {
    let offsets: [Int] = Array(0..<29) + Array(60..<90)
    let input: [LabellingSecond] = offsets.map {
        LabellingSecond(
            time: wholeMinute.addingTimeInterval(TimeInterval($0)),
            heartRate: 60,
            angle: 0
        )
    }

    let labelling = SleepWakeLabeller.label(input, activeAboveDegrees: 2.0)

    try #require(labelling.minutes.count == 2)
    #expect(labelling.minutes[0].start == wholeMinute)
    #expect(labelling.minutes[0].label == nil)
    #expect(labelling.minutes[1].start == wholeMinute.addingTimeInterval(60))
    #expect(labelling.minutes[1].label != nil)
}

/// Spec 019: the 29–30 Oct 2026 fixture night, turned into labelling input with the quaternion
/// turn and labelled at the app's 2°, gives spec 003's Sleep Period for that Night (the literals
/// in NightsTests.fixtureNightMakesOneNightDatedByFinalWakeWithItsSleepPeriod).
@Test func fixtureNightLabelledAtTheAppThresholdGivesTheNightsSleepPeriod() throws {
    var seen = Set<String>()
    let records = NightFixture.night20261030
        .filter { seen.insert($0.identity).inserted }
        .sorted { ($0.timestamp, $0.recordCounter) < ($1.timestamp, $1.recordCounter) }

    let labelling = SleepWakeLabeller.label(
        SleepWakeLabeller.input(from: records),
        activeAboveDegrees: SleepWakeLabeller.appThreshold
    )

    let period = try #require(labelling.sleepPeriod)
    // 2026-10-29 21:05:00 UTC
    #expect(period.sleepOnset == Date(timeIntervalSince1970: 1_793_307_900))
    // 2026-10-30 03:42:00 UTC
    #expect(period.finalWake == Date(timeIntervalSince1970: 1_793_331_720))
    // 2026-10-29 20:57:00 UTC
    #expect(period.timeInBedStart == Date(timeIntervalSince1970: 1_793_307_420))
    // 2026-10-30 04:00:00 UTC
    #expect(period.timeInBedEnd == Date(timeIntervalSince1970: 1_793_332_800))
    // 5h52. Typed up front: comparing a `TimeInterval?` with a bare literal inside `#expect`
    // crashes the Swift 6.4.1 compiler on Windows.
    let fiveHoursFiftyTwo: TimeInterval? = 352 * 60
    #expect(period.timeAsleep == fiveHoursFiftyTwo)
}

/// Spec 019, labeller seam: a minute's mean heart rate is over its seconds that have one. After a
/// wake minute, a still minute whose seconds alternate none and 70 bpm averages 70, 10 above the
/// 60 bpm around it, so the heart-rate extension (≥ 6 bpm raised) keeps it wake. Were the
/// seconds without one counted as 0, it would average 35 and be sleep.
@Test func secondsWithoutAHeartRateAreLeftOutOfTheMinutesMeanHeartRate() throws {
    let wakeMinute = 40
    let raisedMinute = wakeMinute + 1
    let input: [LabellingSecond] = (0..<(80 * 60)).map { offset in
        let minute = offset / 60
        let heartRate: Double? =
            minute == raisedMinute ? (offset.isMultiple(of: 2) ? nil : 70) : 60
        return LabellingSecond(
            time: wholeMinute.addingTimeInterval(TimeInterval(offset)),
            heartRate: heartRate,
            angle: minute == wakeMinute ? 3 : 0
        )
    }

    let labelling = SleepWakeLabeller.label(input, activeAboveDegrees: 2.0)

    try #require(labelling.minutes.count == 80)
    #expect(labelling.minutes[wakeMinute].label == .wake)
    #expect(labelling.minutes[raisedMinute].label == .wake)
    #expect(labelling.minutes[raisedMinute + 1].label == .sleep)
}

/// Spec 019: the app labels at 2°.
@Test func theAppThresholdIsTwoDegrees() {
    #expect(SleepWakeLabeller.appThreshold == 2.0)
}
