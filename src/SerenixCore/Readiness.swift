import Foundation

/// How Readiness is worked out from its inputs (spec 008). Every constant is an assumption from
/// issue #18 and docs/research/readiness-composite-scores.md: tune with real Nights.
enum Readiness {
    /// HRV's share of Readiness, before re-weighting (spec 008, Inputs). Unitless.
    static let hrvWeight = 0.50
    /// Sleeping HR's share of Readiness, before re-weighting (spec 008, Inputs). Unitless.
    static let sleepingHRWeight = 0.25
    /// Time Asleep's share of Readiness, before re-weighting (spec 008, Inputs). Unitless.
    static let timeAsleepWeight = 0.15
    /// Time Asleep at or above this costs nothing, seconds (spec 008: 7 h, until Sleep Need).
    static let timeAsleepMark: TimeInterval = 7 * 60 * 60
    /// Each input's score is clamped to this far either side of usual (spec 008), in score units:
    /// Spreads, or hours for Time Asleep.
    static let scoreLimit = 3.0
    /// The curve's steepness per unit of the weighted score (spec 008, Score). Unitless.
    static let curveSlope = 2.0
    /// Shifts the curve so a usual Night (weighted score 0) scores 70 (spec 008, Score), in
    /// score units.
    static let curveOffset = 0.42

    /// The Night's Readiness, 0–100, rounded with halves up; nil when the Night has no HRV or
    /// HRV's Baseline has no median or Spread (spec 008). An HRV or Baseline of 0 ms counts as no
    /// HRV, as ln 0 gives no score. Calibrating is the caller's to decide.
    static func score(of night: Night, hrv: Baseline, sleepingHR: Baseline) -> Int? {
        guard let hrvValue = night.hrv, hrvValue > 0,
            let hrvMedian = hrv.median, hrvMedian > 0, let hrvSpread = hrv.spread
        else { return nil }
        // Each input's score is positive when better than usual. Missing inputs are left out.
        var inputs: [(score: Double, weight: Double)] = [
            ((log(hrvValue) - log(hrvMedian)) / hrvSpread, hrvWeight)
        ]
        if let value = night.sleepingHR, let median = sleepingHR.median,
            let spread = sleepingHR.spread
        {
            inputs.append((-(value - median) / spread, sleepingHRWeight))
        }
        if let timeAsleep = night.timeAsleep {
            let hoursShort = max(timeAsleepMark - timeAsleep, 0) / (60 * 60)
            inputs.append((-hoursShort, timeAsleepWeight))
        }
        // The weights left are scaled up to add to 1.
        let totalWeight = inputs.reduce(0) { $0 + $1.weight }
        let weighted = inputs.reduce(0) { sum, input in
            sum + min(max(input.score, -scoreLimit), scoreLimit) * input.weight / totalWeight
        }
        let readiness = 100 / (1 + exp(-curveSlope * (weighted + curveOffset)))
        // Readiness is never negative, so rounding away from zero is rounding halves up.
        return Int(readiness.rounded(.toNearestOrAwayFromZero))
    }
}
