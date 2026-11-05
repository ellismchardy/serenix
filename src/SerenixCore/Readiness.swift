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
        var sleepShortfall: TimeInterval = 0
        if let timeAsleep = night.plausibleTimeAsleep {
            sleepShortfall = max(sleepNeed - timeAsleep, 0)
            inputs.append((.timeAsleep, -sleepShortfall / secondsPerHour, timeAsleepWeight))
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
            },
            sleepShortfall: sleepShortfall
        )
    }

    /// One of Readiness's four inputs (spec 008, Inputs), in that order.
    enum Input: Hashable, Sendable, CaseIterable {
        case hrv, sleepingHR, timeAsleep, previousDayLoad

        /// As in the Readiness popup (specs 008, 012).
        var name: String {
            switch self {
            case .hrv: "HRV"
            case .sleepingHR: "Sleeping HR"
            case .timeAsleep: "Time Asleep"
            case .previousDayLoad: "Yesterday's Load"
            }
        }
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
        /// In `Input.allCases` order.
        let parts: [Part]
        /// How far Time Asleep fell short of Sleep Need, unclamped, in seconds; 0 when it met it
        /// or was dropped.
        let sleepShortfall: TimeInterval

        /// The weighted sum of the scores (spec 008's Z), in score units.
        var weightedScore: Double {
            parts.reduce(0) { $0 + $1.score * $1.weight }
        }

        /// Readiness, 0–100, rounded with halves up.
        var score: Int {
            // Readiness is never negative, so rounding away from zero is rounding halves up.
            Int(curve(weightedScore).rounded(.toNearestOrAwayFromZero))
        }

        /// Each counted input's whole points, in `parts` order: its share of how far Readiness
        /// is from a usual Night, adding up to `score` − the usual Night's Readiness (spec 012,
        /// Points).
        var points: [Int] {
            let weighted = weightedScore
            // Readiness moved per score unit; at Z = 0, the curve's slope there. Inputs that cancel
            // leave Z a rounding error away from 0, where the difference quotient loses precision.
            let perUnit =
                abs(weighted) < Readiness.flatWeightedScore
                ? curveSlope * curve(0) * (1 - curve(0) / 100)
                : (curve(weighted) - curve(0)) / weighted
            let raw = parts.map { $0.score * $0.weight * perUnit }
            var points = raw.map { Int($0.rounded(.down)) }
            // Largest remainder: hand out (or take back) the points rounding down left over, so
            // they add up exactly.
            let shortfall = (score - Readiness.usualScore) - points.reduce(0, +)
            let byRemainder = raw.indices.sorted {
                raw[$0] - Double(points[$0]) > raw[$1] - Double(points[$1])
            }
            if shortfall > 0 {
                for index in byRemainder.prefix(shortfall) { points[index] += 1 }
            } else if shortfall < 0 {
                for index in byRemainder.suffix(-shortfall) { points[index] -= 1 }
            }
            return points
        }

        /// The counted inputs from the lowest points to the highest; equal points keep the
        /// `Input.allCases` order (spec 012, Why; spec 002, Readiness message).
        var inputsByPoints: [(input: Input, points: Int)] {
            let costs = zip(parts, points).enumerated().map { entry -> (Int, Input, Int) in
                (entry.offset, entry.element.0.input, entry.element.1)
            }
            return costs.sorted { $0.2 != $1.2 ? $0.2 < $1.2 : $0.0 < $1.0 }.map { ($0.1, $0.2) }
        }

        /// The inputs that cost `namedCostPoints` or more, costliest first: the ones the popup's
        /// verdict and the Readiness message name.
        var costliestInputs: [Input] {
            inputsByPoints.filter { $0.points <= -Readiness.namedCostPoints }.map(\.input)
        }

        /// `sleepShortfall` in whole minutes, as the popup and the Readiness message show it.
        var minutesShort: Int {
            Int((sleepShortfall / 60).rounded())
        }
    }

    /// An input that costs this many points or more is named, in the Readiness popup's verdict
    /// (spec 012, Verdict) and the Readiness message (spec 002). Readiness points.
    static let namedCostPoints = 3

    /// The usual Night's Readiness (spec 008, Score): what the points start from.
    static let usualScore = 70

    /// A weighted score closer to 0 than this counts as 0 when splitting points (spec 012,
    /// Points), in score units: far below any real input's effect, far above rounding error.
    static let flatWeightedScore = 1e-9

    /// Readiness before rounding, 0–100, for a weighted score Z (spec 008, Score).
    static func curve(_ weighted: Double) -> Double {
        100 / (1 + exp(-curveSlope * (weighted + curveOffset)))
    }
}
