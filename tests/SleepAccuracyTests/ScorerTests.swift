import Foundation
import SerenixCore
import SleepAccuracy
import Testing

/// 2027-01-15 08:00:00 UTC, a whole UTC minute.
private let wholeMinute = Date(timeIntervalSince1970: 1_800_000_000)

/// Spec 019, Scorer: four compared Epochs, PSG sleep/sleep/sleep/wake against Serenix
/// sleep/sleep/wake/wake, give sensitivity 0.667, specificity 1.000, accuracy 0.750 and κ 0.500.
@Test func fourComparedEpochsGiveTheSpecsAgreement() throws {
    let agreement = EpochAgreement(
        referenceAsleep: [true, true, true, false],
        serenixAsleep: [true, true, false, false]
    )

    #expect(agreement.comparedEpochs == 4)
    #expect(abs(try #require(agreement.sensitivity) - 0.667) < 1e-3)
    #expect(abs(try #require(agreement.specificity) - 1.000) < 1e-3)
    #expect(abs(try #require(agreement.accuracy) - 0.750) < 1e-3)
    #expect(abs(try #require(agreement.kappa) - 0.500) < 1e-3)
}

/// Spec 019, Scorer: a Serenix minute's label counts for both of its Epochs. 20 minutes make one
/// Sleep Period over all of them, all still but minute 10, which moves every second and so is a
/// wake minute inside it. PSG's wake Epochs are 1 (second half of sleep minute 0, so scored
/// asleep) and 20 (first half of wake minute 10, so scored wake); Epoch 21, the second half of
/// minute 10, is PSG sleep but scored wake. 37 of 38 PSG sleep Epochs and 1 of 2 wake Epochs
/// agree: sensitivity 37/38, specificity 1/2, accuracy 38/40.
@Test func aMinutesLabelCountsForBothOfItsEpochs() throws {
    let wakeMinute = 10
    let seconds = (0..<(20 * 60)).map {
        LabellingSecond(
            time: wholeMinute.addingTimeInterval(TimeInterval($0)),
            heartRate: 60,
            angle: $0 / 60 == wakeMinute ? 3 : 0
        )
    }
    let epochs = (0..<40).map {
        Epoch(
            start: wholeMinute.addingTimeInterval(TimeInterval($0 * 30)),
            label: $0 == 1 || $0 == 20 ? .wake : .n2
        )
    }
    let night = ReferenceNight(id: "still-night", seconds: seconds, epochs: epochs)

    let result = Scorer.score(night, activeAboveDegrees: SleepWakeLabeller.appThreshold)

    #expect(result.id == "still-night")
    #expect(result.visible.comparedEpochs == 40)
    #expect(abs(try #require(result.visible.sensitivity) - 0.974) < 1e-3)
    #expect(abs(try #require(result.visible.specificity) - 0.500) < 1e-3)
    #expect(abs(try #require(result.visible.accuracy) - 0.950) < 1e-3)
}

/// Seconds from `wholeMinute` at 60 bpm, still (angle 0) unless `moving` says otherwise
/// (angle 3, above the app's 2° threshold).
private func labellingSeconds(
    _ offsets: some Sequence<Int>,
    moving: (Int) -> Bool = { _ in false }
) -> [LabellingSecond] {
    offsets.map {
        LabellingSecond(
            time: wholeMinute.addingTimeInterval(TimeInterval($0)),
            heartRate: 60,
            angle: moving($0) ? 3 : 0
        )
    }
}

/// Consecutive Epochs from `wholeMinute`, labelled by `label(index)`.
private func epochs(_ count: Int, label: (Int) -> EpochLabel = { _ in .n2 }) -> [Epoch] {
    (0..<count).map {
        Epoch(start: wholeMinute.addingTimeInterval(TimeInterval($0 * 30)), label: label($0))
    }
}

/// Spec 019, Scorer: unscored Epochs, and Epochs whose minute has no data, are not compared.
/// 20 minutes where minute 5 has only 29 seconds (no data), so its Epochs 10 and 11 aren't
/// compared; Epoch 30 is unscored. 37 of the 39 scored Epochs are compared, in both layers.
@Test func unscoredAndNoDataEpochsAreNotCompared() {
    let seconds = labellingSeconds((0..<(20 * 60)).filter { $0 / 60 != 5 || $0 % 60 < 29 })
    let night = ReferenceNight(
        id: "gap-night",
        seconds: seconds,
        epochs: epochs(40) { $0 == 30 ? .unscored : .n2 }
    )

    let result = Scorer.score(night, activeAboveDegrees: SleepWakeLabeller.appThreshold)

    #expect(result.visible.comparedEpochs == 37)
    #expect(result.raw.comparedEpochs == 37)
    #expect(abs(result.coverage - 37.0 / 39.0) < 1e-9)
}

/// Spec 019, Scorer: a Reference Night with 89% of its scored Epochs compared is left out and
/// listed with its coverage; one with 90% is kept. Both have 200 scored Epochs (100 minutes);
/// night "a" has seconds for the first 89 minutes (178 compared), night "b" for the first 90
/// (180 compared).
@Test func aReferenceNightUnderNinetyPercentCoverageIsLeftOutAndOneAtNinetyIsKept() throws {
    let a = ReferenceNight(id: "a", seconds: labellingSeconds(0..<(89 * 60)), epochs: epochs(200))
    let b = ReferenceNight(id: "b", seconds: labellingSeconds(0..<(90 * 60)), epochs: epochs(200))

    let scored = Scorer.score([a, b], activeAboveDegrees: SleepWakeLabeller.appThreshold)

    #expect(Scorer.fewestComparedShare == 0.9)
    #expect(scored.kept.map(\.id) == ["b"])
    #expect(abs(try #require(scored.kept.first).coverage - 0.90) < 1e-9)
    #expect(scored.leftOut.map(\.id) == ["a"])
    #expect(abs(try #require(scored.leftOut.first).coverage - 0.89) < 1e-9)
}

/// Spec 019, Scorer: a sleep-labelled minute outside the Sleep Period is wake in the visible
/// verdict and sleep in the raw labels. 24 minutes, still but minute 3 (moving, so wake).
/// Minutes 0–2 are a 3-minute sleep run, too short to start a Sleep Period, which is minutes
/// 4–23. PSG is all N2 (48 Epochs): visible scores 40 asleep (8/48 sleep Epochs missed),
/// raw scores 46 asleep (only minute 3's two Epochs missed).
@Test func aSleepMinuteOutsideTheSleepPeriodIsWakeInTheVisibleVerdictAndSleepInTheRawLabels()
    throws
{
    let night = ReferenceNight(
        id: "short-run-night",
        seconds: labellingSeconds(0..<(24 * 60)) { $0 / 60 == 3 },
        epochs: epochs(48)
    )

    let result = Scorer.score(night, activeAboveDegrees: SleepWakeLabeller.appThreshold)

    #expect(result.visible.comparedEpochs == 48)
    #expect(result.raw.comparedEpochs == 48)
    #expect(abs(try #require(result.visible.sensitivity) - 40.0 / 48.0) < 1e-9)
    #expect(abs(try #require(result.raw.sensitivity) - 46.0 / 48.0) < 1e-9)
}

/// Spec 019, Scorer: a Reference Night where Serenix finds no Sleep Period scores every
/// compared Epoch wake in the visible verdict. 21 minutes in which every 7th minute moves, so
/// the sleep runs are 6 minutes, one short of starting a Sleep Period; the raw labels still call
/// 18 of the 21 minutes sleep. PSG all N2.
@Test func aReferenceNightWithNoSleepPeriodScoresEveryComparedEpochWake() throws {
    let night = ReferenceNight(
        id: "restless-night",
        seconds: labellingSeconds(0..<(21 * 60)) { $0 / 60 % 7 == 6 },
        epochs: epochs(42)
    )

    let result = Scorer.score(night, activeAboveDegrees: SleepWakeLabeller.appThreshold)

    #expect(result.visible.comparedEpochs == 42)
    #expect(result.raw.comparedEpochs == 42)
    #expect(try #require(result.visible.sensitivity) == 0.0)
    #expect(abs(try #require(result.raw.sensitivity) - 36.0 / 42.0) < 1e-9)
}

/// 20 still minutes: Serenix's Sleep Period is minutes 0–20, Time Asleep 20 min, no Wake Bouts.
/// PSG (40 Epochs) is wake at Epochs 0–3, 20 and 38–39, else N2: Sleep Onset 120 s (Epoch 4),
/// Final Wake 1140 s (end of Epoch 37), 33 sleep Epochs = 16.5 min, WASO 0.5 min (Epoch 20),
/// one Wake Bout of 0.5 min.
private func stillNightWithPSGWake() -> ReferenceNight {
    ReferenceNight(
        id: "still-night",
        seconds: labellingSeconds(0..<(20 * 60)),
        epochs: epochs(40) { (0...3).contains($0) || $0 == 20 || $0 >= 38 ? .wake : .n2 }
    )
}

/// 21 minutes in which every 7th minute moves, so Serenix finds no Sleep Period (raw labels: 18
/// of 21 minutes sleep). PSG all N2: 42 Epochs = 21 min asleep, no WASO, no Wake Bouts.
private func restlessNight() -> ReferenceNight {
    ReferenceNight(
        id: "restless-night",
        seconds: labellingSeconds(0..<(21 * 60)) { $0 / 60 % 7 == 6 },
        epochs: epochs(42)
    )
}

/// Spec 019, Per Reference Night: the visible verdict's errors are Serenix minus PSG, in minutes.
/// Time Asleep 20 − 16.5 = +3.5; WASO 0 − 0.5 = −0.5; Sleep Onset 0 − 2 = −2.0; Final Wake
/// 20 − 19 = +1.0; Wake Bouts 0 (no mean) against PSG's 1 of 0.5 min.
@Test func aReferenceNightReportsSerenixMinusPSGErrorsInMinutes() throws {
    let result = Scorer.score(
        stillNightWithPSGWake(),
        activeAboveDegrees: SleepWakeLabeller.appThreshold
    )

    #expect(abs(result.timeAsleepBias - 3.5) < 1e-9)
    #expect(abs(result.wasoBias - -0.5) < 1e-9)
    #expect(abs(try #require(result.sleepOnsetError) - -2.0) < 1e-9)
    #expect(abs(try #require(result.finalWakeError) - 1.0) < 1e-9)
    #expect(result.serenixWakeBouts == 0)
    #expect(result.serenixMeanWakeBoutMinutes == nil)
    #expect(result.referenceWakeBouts == 1)
    #expect(abs(try #require(result.referenceMeanWakeBoutMinutes) - 0.5) < 1e-9)
}

/// Spec 019, Scorer: a Reference Night where Serenix finds no Sleep Period has Time Asleep 0
/// (bias 0 − 21 = −21.0) and empty Sleep Onset and Final Wake errors.
@Test func aReferenceNightWithNoSleepPeriodHasTimeAsleepZeroAndNoOnsetOrFinalWakeError() {
    let result = Scorer.score(restlessNight(), activeAboveDegrees: SleepWakeLabeller.appThreshold)

    #expect(abs(result.timeAsleepBias - -21.0) < 1e-9)
    #expect(result.sleepOnsetError == nil)
    #expect(result.finalWakeError == nil)
    #expect(result.serenixWakeBouts == 0)
    #expect(result.referenceWakeBouts == 0)
}

/// The 4-Epoch example (PSG sleep/sleep/sleep/wake, Serenix sleep/sleep/wake/wake) has 2 sleep
/// as sleep, 1 sleep as wake, 0 wake as sleep, 1 wake as wake; pooling it with itself doubles
/// each count and keeps its rates.
@Test func pooledAgreementSumsTheCounts() throws {
    let agreement = EpochAgreement(
        referenceAsleep: [true, true, true, false],
        serenixAsleep: [true, true, false, false]
    )

    #expect(agreement.sleepAsSleep == 2)
    #expect(agreement.sleepAsWake == 1)
    #expect(agreement.wakeAsSleep == 0)
    #expect(agreement.wakeAsWake == 1)

    let pooled = EpochAgreement.pooled([agreement, agreement])

    #expect(pooled.comparedEpochs == 8)
    #expect(pooled.sleepAsSleep == 4)
    #expect(pooled.sleepAsWake == 2)
    #expect(pooled.wakeAsSleep == 0)
    #expect(pooled.wakeAsWake == 2)
    #expect(abs(try #require(pooled.kappa) - 0.500) < 1e-3)
}

/// Spec 019, Pooled: Epoch stats over all compared Epochs of all kept Reference Nights; error
/// means skip Reference Nights that lack the error.
///
/// Worked by hand. Visible verdict:
/// - still night: all 40 Epochs scored asleep → sleepAsSleep 33, wakeAsSleep 7.
/// - restless night: all 42 scored wake → sleepAsWake 42.
/// Pooled: 82 compared; 33 / 42 / 7 / 0. Sensitivity 33/75 = 0.44, specificity 0/7 = 0,
/// accuracy 33/82, κ = (2706 − 3294) / (6724 − 3294) = −6/35 ≈ −0.1714
/// (observed 33·82 = 2706, chance 75·40 + 7·42 = 3294, over 82² = 6724).
/// Raw labels: still night as visible; restless night 36 of 42 asleep → raw sensitivity
/// (33 + 36)/75 = 0.92.
/// Errors: Time Asleep +3.5 and −21.0 → mean −8.75; WASO −0.5 and 0 → mean −0.25; Sleep Onset
/// −2.0 and Final Wake +1.0 from the still night only (count 1); Wake Bout count error
/// 0 − 1 = −1 and 0 − 0 = 0 → mean −0.5.
@Test func pooledScoresCoverAllKeptEpochsAndSkipMissingErrors() throws {
    let scored = Scorer.score(
        [stillNightWithPSGWake(), restlessNight()],
        activeAboveDegrees: SleepWakeLabeller.appThreshold
    )
    let pooled = try #require(scored.pooled)

    #expect(pooled.visible.comparedEpochs == 82)
    #expect(pooled.visible.sleepAsSleep == 33)
    #expect(pooled.visible.sleepAsWake == 42)
    #expect(pooled.visible.wakeAsSleep == 7)
    #expect(pooled.visible.wakeAsWake == 0)
    #expect(abs(try #require(pooled.visible.sensitivity) - 0.44) < 1e-9)
    #expect(try #require(pooled.visible.specificity) == 0.0)
    #expect(abs(try #require(pooled.visible.accuracy) - 33.0 / 82.0) < 1e-9)
    #expect(abs(try #require(pooled.visible.kappa) - -6.0 / 35.0) < 1e-9)
    #expect(pooled.raw.comparedEpochs == 82)
    #expect(abs(try #require(pooled.raw.sensitivity) - 0.92) < 1e-9)

    #expect(pooled.timeAsleepBias.count == 2)
    #expect(abs(try #require(pooled.timeAsleepBias.mean) - -8.75) < 1e-9)
    #expect(pooled.wasoBias.count == 2)
    #expect(abs(try #require(pooled.wasoBias.mean) - -0.25) < 1e-9)
    #expect(pooled.sleepOnsetError.count == 1)
    #expect(abs(try #require(pooled.sleepOnsetError.mean) - -2.0) < 1e-9)
    #expect(pooled.finalWakeError.count == 1)
    #expect(abs(try #require(pooled.finalWakeError.mean) - 1.0) < 1e-9)
    #expect(pooled.wakeBoutCountError.count == 2)
    #expect(abs(try #require(pooled.wakeBoutCountError.mean) - -0.5) < 1e-9)
}

/// With no Reference Night kept there is nothing to pool.
@Test func nothingKeptHasNoPooledScores() {
    let gappy = ReferenceNight(
        id: "a",
        seconds: labellingSeconds(0..<(89 * 60)),
        epochs: epochs(200)
    )

    let scored = Scorer.score([gappy], activeAboveDegrees: SleepWakeLabeller.appThreshold)

    #expect(scored.kept.isEmpty)
    #expect(scored.pooled == nil)
}
