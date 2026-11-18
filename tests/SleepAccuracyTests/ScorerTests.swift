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
