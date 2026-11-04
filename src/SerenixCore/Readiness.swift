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
    /// HRV, as ln 0 gives no score. Calibrating is the caller's to decide. `sleepNeed` is the
    /// Night's Sleep Need in seconds (spec 009): Time Asleep at or above it costs nothing.
    /// `previousDayLoad` is the Load of the Day before the Night's, and `typicalLoad` that Day's
    /// typical Load.
    static func score(
        of night: Night,
        hrv: Baseline,
        sleepingHR: Baseline,
        sleepNeed: TimeInterval,
        previousDayLoad: Int?,
        typicalLoad: TypicalLoad
    ) -> Int? {
        breakdown(
            of: night,
            hrv: hrv,
            sleepingHR: sleepingHR,
            sleepNeed: sleepNeed,
            previousDayLoad: previousDayLoad,
            typicalLoad: typicalLoad
        )?.score
    }

    /// How the Night's Readiness is made up (spec 008): each input's clamped score and re-weighted
    /// weight, or nil for the whole when `score` would be nil. Same arguments as `score`.
    static func breakdown(
        of night: Night,
        hrv: Baseline,
        sleepingHR: Baseline,
        sleepNeed: TimeInterval,
        previousDayLoad: Int?,
        typicalLoad: TypicalLoad
    ) -> Breakdown? {
        // Bad stored values count as missing (docs/architecture.md, Errors).
        guard let hrvValue = night.value(of: .hrv), hrvValue > 0,
            let hrvMedian = hrv.median, hrvMedian > 0, let hrvSpread = hrv.spread
        else { return nil }
        // Each input's score is positive when better than usual. Missing inputs are left out.
        var inputs: [(input: Input, score: Double, weight: Double)] = [
            (.hrv, (log(hrvValue) - log(hrvMedian)) / hrvSpread, hrvWeight)
        ]
        if let value = night.value(of: .sleepingHR), let median = sleepingHR.median,
            let spread = sleepingHR.spread
        {
            inputs.append((.sleepingHR, -(value - median) / spread, sleepingHRWeight))
        }
        if let timeAsleep = night.plausibleTimeAsleep {
            let hoursShort = max(sleepNeed - timeAsleep, 0) / secondsPerHour
            inputs.append((.timeAsleep, -hoursShort, timeAsleepWeight))
        }
        // The previous Day's Load costs only above its typical Load; dropped while either is
        // missing.
        if let load = previousDayLoad, case .value(let typical) = typicalLoad {
            // Whole numbers both: typical Load is rounded by its own definition (spec 006).
            let above = max(Double(load - typical), 0)
            inputs.append((.previousDayLoad, -above / loadPerScoreUnit, loadWeight))
        }
        // The weights left are scaled up to add to 1.
        let totalWeight = inputs.reduce(0) { $0 + $1.weight }
        return Breakdown(
            parts: inputs.map { input in
                Part(
                    input: input.input,
                    score: min(max(input.score, -scoreLimit), scoreLimit),
                    weight: input.weight / totalWeight
                )
            }
        )
    }

    /// One of Readiness's four inputs (spec 008, Inputs).
    enum Input: Equatable, Sendable {
        case hrv, sleepingHR, timeAsleep, previousDayLoad
    }

    /// One input that counted towards Readiness.
    struct Part: Equatable, Sendable {
        let input: Input
        /// Clamped to ±`scoreLimit`; positive when better than usual, in score units.
        let score: Double
        /// Re-weighted so the inputs that counted add to 1. Unitless.
        let weight: Double
    }

    /// The inputs that counted towards one Night's Readiness; a dropped input has no Part.
    struct Breakdown: Equatable, Sendable {
        /// In the order HRV, Sleeping HR, Time Asleep, previous Day's Load.
        let parts: [Part]

        /// The weighted sum of the scores (spec 008's Z), in score units.
        var weightedScore: Double {
            parts.reduce(0) { $0 + $1.score * $1.weight }
        }

        /// Readiness, 0–100, rounded with halves up.
        var score: Int {
            let readiness = 100 / (1 + exp(-curveSlope * (weightedScore + curveOffset)))
            // Readiness is never negative, so rounding away from zero is rounding halves up.
            return Int(readiness.rounded(.toNearestOrAwayFromZero))
        }
    }
}
