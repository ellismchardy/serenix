import Foundation
import SleepAccuracy
import Testing

/// 2027-01-15 08:00:00 UTC, a whole UTC minute.
private let wholeMinute = Date(timeIntervalSince1970: 1_800_000_000)

/// Consecutive Epochs from `wholeMinute`, labelled by `label(index)`.
private func epochs(_ count: Int, label: (Int) -> EpochLabel) -> [Epoch] {
    (0..<count).map {
        Epoch(start: wholeMinute.addingTimeInterval(TimeInterval($0 * 30)), label: label($0))
    }
}

/// Spec 019, Scorer: PSG sleep from Epoch 2 to Epoch 9 (0-based) with wake at Epochs 5 and 7 has
/// Sleep Onset at 60 s (start of Epoch 2), Final Wake at 300 s (end of Epoch 9), 2 Wake Bouts of
/// 0.5 min each, and 3.0 min Time Asleep (Epochs 2, 3, 4, 6, 8, 9 × 30 s). WASO is Epochs 5 and 7,
/// 60 s. Epochs 0, 1, 10 and 11 are wake outside PSG's sleep and count for none of these.
@Test func psgSleepFromEpochTwoToNineWithTwoWakeEpochsGivesTheSpecsReferenceSleep() {
    let sleep = ReferenceSleep(
        epochs: epochs(12) { [2, 3, 4, 6, 8, 9].contains($0) ? .n2 : .wake }
    )

    #expect(sleep.sleepOnset == wholeMinute.addingTimeInterval(60))
    #expect(sleep.finalWake == wholeMinute.addingTimeInterval(300))
    #expect(sleep.wakeBoutMinutes == [0.5, 0.5])
    #expect(sleep.timeAsleep == 180)
    #expect(sleep.wakeAfterSleepOnset == 60)
}

/// An unscored Epoch is neither sleep nor wake and ends a run of wake: sleep, wake, unscored,
/// wake, sleep gives two Wake Bouts of 0.5 min, 60 s of WASO and 60 s Time Asleep.
@Test func anUnscoredEpochEndsARunOfWake() {
    let labels: [EpochLabel] = [.n2, .wake, .unscored, .wake, .n2]
    let sleep = ReferenceSleep(epochs: epochs(labels.count) { labels[$0] })

    #expect(sleep.wakeBoutMinutes == [0.5, 0.5])
    #expect(sleep.wakeAfterSleepOnset == 60)
    #expect(sleep.timeAsleep == 60)
    #expect(sleep.sleepOnset == wholeMinute)
    #expect(sleep.finalWake == wholeMinute.addingTimeInterval(150))
}

/// A Reference Night with no sleep Epoch has no Sleep Onset or Final Wake, and nothing asleep.
@Test func noSleepEpochsGiveNoSleepOnsetOrFinalWake() {
    let sleep = ReferenceSleep(epochs: epochs(4) { _ in .wake })

    #expect(sleep.sleepOnset == nil)
    #expect(sleep.finalWake == nil)
    #expect(sleep.timeAsleep == 0)
    #expect(sleep.wakeAfterSleepOnset == 0)
    #expect(sleep.wakeBoutMinutes.isEmpty)
}
