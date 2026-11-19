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
    // The visible verdict's errors, in minutes, Serenix minus PSG (`ReferenceSleep`).
    /// Serenix's Time Asleep (0 when it found no Sleep Period) minus PSG's.
    public let timeAsleepBias: Double
    /// Serenix's wake minutes inside its Sleep Period minus PSG's WASO. With no Sleep Period
    /// Serenix's side is 0, as its Time Asleep is, so the Reference Night still counts.
    public let wasoBias: Double
    /// Nil when Serenix found no Sleep Period or PSG scored no sleep.
    public let sleepOnsetError: Double?
    /// Nil when Serenix found no Sleep Period or PSG scored no sleep.
    public let finalWakeError: Double?
    /// How many Wake Bouts Serenix's Sleep Period has (0 with none).
    public let serenixWakeBouts: Int
    /// Minutes; nil with no Wake Bouts.
    public let serenixMeanWakeBoutMinutes: Double?
    /// How many Wake Bouts PSG has (`ReferenceSleep.wakeBoutMinutes`).
    public let referenceWakeBouts: Int
    /// Minutes; nil with no Wake Bouts.
    public let referenceMeanWakeBoutMinutes: Double?
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
    /// Across the kept Reference Nights; nil when none was kept.
    public let pooled: PooledScores?
}

/// Scores across the kept Reference Nights (spec 019). Each error is summed up over the
/// Reference Nights that have it.
public struct PooledScores: Equatable, Codable, Sendable {
    /// Every compared Epoch of every kept Reference Night together.
    public let visible: EpochAgreement
    public let raw: EpochAgreement
    public let timeAsleepBias: ErrorSummary
    public let wasoBias: ErrorSummary
    public let sleepOnsetError: ErrorSummary
    public let finalWakeError: ErrorSummary
    /// Serenix's Wake Bouts minus PSG's, per Reference Night.
    public let wakeBoutCountError: ErrorSummary

    init(_ results: [ReferenceNightResult]) {
        visible = .pooled(results.map(\.visible))
        raw = .pooled(results.map(\.raw))
        timeAsleepBias = ErrorSummary(results.map(\.timeAsleepBias))
        wasoBias = ErrorSummary(results.map(\.wasoBias))
        sleepOnsetError = ErrorSummary(results.compactMap(\.sleepOnsetError))
        finalWakeError = ErrorSummary(results.compactMap(\.finalWakeError))
        wakeBoutCountError = ErrorSummary(
            results.map { Double($0.serenixWakeBouts - $0.referenceWakeBouts) }
        )
    }
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
        activeAboveDegrees threshold: Double,
        settings: LabellerSettings = LabellerSettings()
    ) -> ScoredReferenceNights {
        var kept: [ReferenceNightResult] = []
        var leftOut: [LeftOutReferenceNight] = []
        for night in nights {
            let result = score(night, activeAboveDegrees: threshold, settings: settings)
            if result.coverage < fewestComparedShare {
                leftOut.append(LeftOutReferenceNight(id: result.id, coverage: result.coverage))
            } else {
                kept.append(result)
            }
        }
        return ScoredReferenceNights(
            kept: kept,
            leftOut: leftOut,
            pooled: kept.isEmpty ? nil : PooledScores(kept)
        )
    }

    /// Labels `night.seconds` at `threshold` (degrees) and compares each Epoch with the Serenix
    /// minute it falls in. An Epoch is compared when PSG scored it and its minute has data.
    public static func score(
        _ night: ReferenceNight,
        activeAboveDegrees threshold: Double,
        settings: LabellerSettings = LabellerSettings()
    ) -> ReferenceNightResult {
        let labelling = SleepWakeLabeller.label(
            night.seconds,
            activeAboveDegrees: threshold,
            settings: settings
        )
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
        let psg = ReferenceSleep(epochs: night.epochs)
        let serenixBouts = period?.wakeBouts.map { Double($0.minutes) } ?? []
        let serenixWASO = serenixBouts.reduce(0, +)
        return ReferenceNightResult(
            id: night.id,
            coverage: scored == 0 ? 0 : Double(reference.count) / Double(scored),
            visible: EpochAgreement(referenceAsleep: reference, serenixAsleep: visible),
            raw: EpochAgreement(referenceAsleep: reference, serenixAsleep: raw),
            timeAsleepBias: ((period?.timeAsleep ?? 0) - psg.timeAsleep) / secondsPerMinute,
            wasoBias: serenixWASO - psg.wakeAfterSleepOnset / secondsPerMinute,
            sleepOnsetError: minutesBetween(psg.sleepOnset, period?.sleepOnset),
            finalWakeError: minutesBetween(psg.finalWake, period?.finalWake),
            serenixWakeBouts: serenixBouts.count,
            serenixMeanWakeBoutMinutes: ErrorSummary(serenixBouts).mean,
            referenceWakeBouts: psg.wakeBoutMinutes.count,
            referenceMeanWakeBoutMinutes: ErrorSummary(psg.wakeBoutMinutes).mean
        )
    }
}

/// Minutes from `reference` to `serenix`; nil when either is missing.
private func minutesBetween(_ reference: Date?, _ serenix: Date?) -> Double? {
    guard let reference, let serenix else { return nil }
    return serenix.timeIntervalSince(reference) / secondsPerMinute
}

/// The whole UTC minute `time` falls in.
private func minuteStart(of time: Date) -> Date {
    let minutes = (time.timeIntervalSince1970 / secondsPerMinute).rounded(.down)
    return Date(timeIntervalSince1970: minutes * secondsPerMinute)
}
