import Foundation

/// PSG's own sleep on a Reference Night, from its Epochs (spec 019): what Serenix's Sleep Onset,
/// Final Wake, Time Asleep and Wake Bouts are measured against. Unscored Epochs count as neither
/// sleep nor wake, and end a run of wake.
public struct ReferenceSleep: Equatable, Sendable {
    /// UTC: the start of the first sleep Epoch; nil with no sleep Epoch.
    public let sleepOnset: Date?
    /// UTC: the end of the last sleep Epoch; nil with no sleep Epoch.
    public let finalWake: Date?
    /// Seconds: sleep Epochs × 30 s.
    public let timeAsleep: TimeInterval
    /// Seconds: wake Epochs between Sleep Onset and Final Wake × 30 s.
    public let wakeAfterSleepOnset: TimeInterval
    /// Each run of wake Epochs between Sleep Onset and Final Wake, in minutes, oldest first. AASM
    /// sets no minimum length for wake, so neither does this.
    public let wakeBoutMinutes: [Double]

    /// `epochs` oldest first.
    public init(epochs: [Epoch]) {
        let sleepIndices = epochs.indices.filter { epochs[$0].label.isAsleep == true }
        timeAsleep = Double(sleepIndices.count) * epochSeconds
        guard let first = sleepIndices.first, let last = sleepIndices.last else {
            sleepOnset = nil
            finalWake = nil
            wakeAfterSleepOnset = 0
            wakeBoutMinutes = []
            return
        }
        sleepOnset = epochs[first].start
        finalWake = epochs[last].start + epochSeconds
        var bouts: [Double] = []
        var run = 0
        var wakeEpochs = 0
        for epoch in epochs[first...last] {
            if epoch.label.isAsleep == false {
                run += 1
                wakeEpochs += 1
            } else if run > 0 {
                bouts.append(Double(run) * epochSeconds / secondsPerMinute)
                run = 0
            }
        }
        wakeBoutMinutes = bouts
        wakeAfterSleepOnset = Double(wakeEpochs) * epochSeconds
    }
}
