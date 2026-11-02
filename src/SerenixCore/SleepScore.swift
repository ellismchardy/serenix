import Foundation

/// How well the user slept in a Night's Sleep Period, from its parts (spec 010). Every constant
/// is an assumption from issue #35 and docs/research/sleep-score-without-stages.md: tune with
/// real Nights.
struct SleepScore: Equatable, Sendable {
    /// Sleep Sufficiency's share of Sleep Score, before re-weighting (spec 010). Unitless.
    static let sufficiencyWeight = 0.6
    /// Sleep Efficiency's share of Sleep Score, before re-weighting (spec 010). Unitless.
    static let efficiencyWeight = 0.2
    /// The share of the Sleep Period asleep at or above which Sleep Efficiency is 100 (spec 010:
    /// 95%). Unitless.
    static let fullEfficiency = 0.95
    /// The share of the Sleep Period asleep at or below which Sleep Efficiency is 0 (spec 010:
    /// 75%, bracketing the NSF's "85% or more is good"). Unitless.
    static let zeroEfficiency = 0.75

    /// How much of the Night's Sleep Need its Time Asleep met, 0–100, unrounded.
    let sufficiency: Double
    /// The share of the Sleep Period asleep, scored 0–100 and unrounded; nil when left out.
    let efficiency: Double?
    /// The Sleep Score, 0–100, rounded with halves up.
    let score: Int

    /// The Night's Sleep Score against its Sleep Need, in seconds (spec 009); nil when the Night
    /// has no plausible Time Asleep.
    init?(of night: Night, sleepNeed: TimeInterval) {
        guard let timeAsleep = night.plausibleTimeAsleep else { return nil }
        sufficiency = min(timeAsleep / sleepNeed, 1) * 100
        // Left out without both ends of the Sleep Period, or when Time Asleep is longer than it
        // (spec 010, Missing and left out).
        let period = night.sleepOnset.flatMap { onset in
            night.finalWake.map { $0.timeIntervalSince(onset) }
        }
        efficiency =
            if let period, period > 0, timeAsleep <= period {
                Self.scaled(
                    timeAsleep / period,
                    zeroAt: Self.zeroEfficiency,
                    fullAt: Self.fullEfficiency
                )
            } else {
                nil
            }
        // The parts left are scaled up to add to 1.
        var parts = [(score: sufficiency, weight: Self.sufficiencyWeight)]
        if let efficiency { parts.append((efficiency, Self.efficiencyWeight)) }
        let totalWeight = parts.reduce(0) { $0 + $1.weight }
        let weighted = parts.reduce(0) { $0 + $1.score * $1.weight / totalWeight }
        // Never negative, so rounding away from zero is rounding halves up.
        score = Int(weighted.rounded(.toNearestOrAwayFromZero))
    }

    /// `value` on a straight line from 0 (at `zeroAt`) to 100 (at `fullAt`), held at 0 and 100
    /// beyond them.
    private static func scaled(_ value: Double, zeroAt: Double, fullAt: Double) -> Double {
        min(max((value - zeroAt) / (fullAt - zeroAt), 0), 1) * 100
    }
}
