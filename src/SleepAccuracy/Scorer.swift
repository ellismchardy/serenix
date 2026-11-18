import Foundation
import SerenixCore

/// One Reference Night's scores (spec 019).
public struct ReferenceNightResult: Equatable, Codable, Sendable {
    public let id: String
    /// The visible verdict: asleep when inside the Sleep Period and labelled sleep.
    public let visible: EpochAgreement
}

/// Scores Serenix's sleep/wake labelling against Reference Nights (spec 019).
public enum Scorer {
    /// Labels `night.seconds` at `threshold` (degrees) and compares each Epoch with the Serenix
    /// minute it falls in.
    public static func score(
        _ night: ReferenceNight,
        activeAboveDegrees threshold: Double
    ) -> ReferenceNightResult {
        let labelling = SleepWakeLabeller.label(night.seconds, activeAboveDegrees: threshold)
        let period = labelling.sleepPeriod
        var visibleAsleep: [Date: Bool] = [:]
        for minute in labelling.minutes {
            let inPeriod =
                period.map { minute.start >= $0.sleepOnset && minute.start < $0.finalWake }
                ?? false
            visibleAsleep[minute.start] = inPeriod && minute.label == .sleep
        }
        var reference: [Bool] = []
        var serenix: [Bool] = []
        for epoch in night.epochs {
            guard let asleep = epoch.label.isAsleep else { continue }
            reference.append(asleep)
            // Until task 4 of plan 019: an Epoch whose minute has no data counts as wake here;
            // the spec leaves it out of the comparison.
            serenix.append(visibleAsleep[minuteStart(of: epoch.start)] ?? false)
        }
        return ReferenceNightResult(
            id: night.id,
            visible: EpochAgreement(referenceAsleep: reference, serenixAsleep: serenix)
        )
    }
}

/// The whole UTC minute `time` falls in.
private func minuteStart(of time: Date) -> Date {
    Date(timeIntervalSince1970: (time.timeIntervalSince1970 / 60).rounded(.down) * 60)
}
