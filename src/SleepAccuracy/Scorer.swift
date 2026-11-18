import Foundation
import SerenixCore

/// One Reference Night's scores (spec 019).
public struct ReferenceNightResult: Equatable, Codable, Sendable {
    public let id: String
    /// Compared Epochs as a share of scored (not unscored) Epochs; 0 when none were scored, so
    /// such a Reference Night is left out and listed rather than silently dropped.
    public let coverage: Double
    /// The visible verdict: asleep when inside the Sleep Period and labelled sleep.
    public let visible: EpochAgreement
    /// Each minute's own sleep/wake label, wherever it falls.
    public let raw: EpochAgreement
}

/// A Reference Night left out of the scores for too little coverage.
public struct LeftOutReferenceNight: Equatable, Codable, Sendable {
    public let id: String
    /// Compared Epochs as a share of scored Epochs.
    public let coverage: Double
}

/// Reference Nights scored together: those kept and those left out, each in input order.
public struct ScoredReferenceNights: Equatable, Codable, Sendable {
    public let kept: [ReferenceNightResult]
    public let leftOut: [LeftOutReferenceNight]
}

/// Scores Serenix's sleep/wake labelling against Reference Nights (spec 019).
public enum Scorer {
    /// The smallest share of a Reference Night's scored Epochs that must be compared for it to be
    /// kept (decided in #81, so gaps in Serenix's data never pass as errors).
    public static let fewestComparedShare = 0.9

    /// Scores each Reference Night at `threshold` (degrees), leaving out those whose coverage is
    /// under `fewestComparedShare`.
    public static func score(
        _ nights: [ReferenceNight],
        activeAboveDegrees threshold: Double
    ) -> ScoredReferenceNights {
        var kept: [ReferenceNightResult] = []
        var leftOut: [LeftOutReferenceNight] = []
        for night in nights {
            let result = score(night, activeAboveDegrees: threshold)
            if result.coverage < fewestComparedShare {
                leftOut.append(LeftOutReferenceNight(id: result.id, coverage: result.coverage))
            } else {
                kept.append(result)
            }
        }
        return ScoredReferenceNights(kept: kept, leftOut: leftOut)
    }

    /// Labels `night.seconds` at `threshold` (degrees) and compares each Epoch with the Serenix
    /// minute it falls in. An Epoch is compared when PSG scored it and its minute has data.
    public static func score(
        _ night: ReferenceNight,
        activeAboveDegrees threshold: Double
    ) -> ReferenceNightResult {
        let labelling = SleepWakeLabeller.label(night.seconds, activeAboveDegrees: threshold)
        let period = labelling.sleepPeriod
        var asleepByMinute: [Date: (visible: Bool, raw: Bool)] = [:]
        for minute in labelling.minutes {
            guard let label = minute.label else { continue }
            let inPeriod =
                period.map { minute.start >= $0.sleepOnset && minute.start < $0.finalWake }
                ?? false
            asleepByMinute[minute.start] = (inPeriod && label == .sleep, label == .sleep)
        }
        var scored = 0
        var reference: [Bool] = []
        var visible: [Bool] = []
        var raw: [Bool] = []
        for epoch in night.epochs {
            guard let asleep = epoch.label.isAsleep else { continue }
            scored += 1
            guard let call = asleepByMinute[minuteStart(of: epoch.start)] else { continue }
            reference.append(asleep)
            visible.append(call.visible)
            raw.append(call.raw)
        }
        return ReferenceNightResult(
            id: night.id,
            coverage: scored == 0 ? 0 : Double(reference.count) / Double(scored),
            visible: EpochAgreement(referenceAsleep: reference, serenixAsleep: visible),
            raw: EpochAgreement(referenceAsleep: reference, serenixAsleep: raw)
        )
    }
}

/// The whole UTC minute `time` falls in.
private func minuteStart(of time: Date) -> Date {
    Date(timeIntervalSince1970: (time.timeIntervalSince1970 / 60).rounded(.down) * 60)
}
