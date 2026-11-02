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
    /// The previous Day's Load's share of Readiness, before re-weighting (spec 008, Inputs).
    /// Unitless.
    static let loadWeight = 0.10
    /// Load points above typical Load that cost one score unit (spec 008, Inputs), on the 0–100
    /// Load scale.
    static let loadPerScoreUnit = 20.0
    /// Time Asleep at or above this costs nothing, seconds (spec 008: 7 h, until Sleep Need).
    static let timeAsleepMark: TimeInterval = 7 * secondsPerHour
    /// Seconds in an hour, for Time Asleep in hours.
    static let secondsPerHour: TimeInterval = 60 * 60
    /// Each input's score is clamped to this far either side of usual (spec 008), in score units:
    /// Spreads, hours for Time Asleep, or `loadPerScoreUnit` Load points for the previous Day's
    /// Load.
    static let scoreLimit = 3.0
    /// The curve's steepness per unit of the weighted score (spec 008, Score). Unitless.
    static let curveSlope = 2.0
    /// Shifts the curve so a usual Night (weighted score 0) scores 70 (spec 008, Score), in
    /// score units.
    static let curveOffset = 0.42

    /// The Night's Readiness, 0–100, rounded with halves up; nil when the Night has no HRV or
    /// HRV's Baseline has no median or Spread (spec 008). An HRV or Baseline of 0 ms counts as no
    /// HRV, as ln 0 gives no score. Calibrating is the caller's to decide. `previousDayLoad` is
    /// the Load of the Day before the Night's, and `typicalLoad` that Day's typical Load.
    static func score(
        of night: Night,
        hrv: Baseline,
        sleepingHR: Baseline,
        previousDayLoad: Int?,
        typicalLoad: TypicalLoad
    ) -> Int? {
        // Bad stored values count as missing (docs/architecture.md, Errors).
        guard let hrvValue = night.value(of: .hrv), hrvValue > 0,
            let hrvMedian = hrv.median, hrvMedian > 0, let hrvSpread = hrv.spread
        else { return nil }
        // Each input's score is positive when better than usual. Missing inputs are left out.
        var inputs: [(score: Double, weight: Double)] = [
            ((log(hrvValue) - log(hrvMedian)) / hrvSpread, hrvWeight)
        ]
        if let value = night.value(of: .sleepingHR), let median = sleepingHR.median,
            let spread = sleepingHR.spread
        {
            inputs.append((-(value - median) / spread, sleepingHRWeight))
        }
        if let timeAsleep = night.plausibleTimeAsleep {
            let hoursShort = max(timeAsleepMark - timeAsleep, 0) / secondsPerHour
            inputs.append((-hoursShort, timeAsleepWeight))
        }
        // The previous Day's Load costs only above its typical Load; dropped while either is
        // missing.
        if let load = previousDayLoad, case .value(let typical) = typicalLoad {
            // Whole numbers both: typical Load is rounded by its own definition (spec 006).
            let above = max(Double(load - typical), 0)
            inputs.append((-above / loadPerScoreUnit, loadWeight))
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
