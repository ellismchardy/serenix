import Foundation

/// The advice under the Readiness message's band word (spec 002, Readiness message): the band's
/// sentence, led for Steady and Take it easy by why, from the Night's own numbers.
enum ReadinessAdvice {
    /// A Load at or above this, the Day before, counts as high. Assumption: tune once the Load
    /// spec ships.
    static let highLoad = 70
    /// The Load to stay under today when Steady, and when Take it easy. Assumptions: tune once
    /// the Load spec ships.
    static let steadyLoadCap = 60
    static let takeItEasyLoadCap = 30

    /// `yesterdayLoad` is the Load of the Day before the Day shown; `hrv` and `restingHR` are the
    /// Night's tiles.
    static func text(
        for band: ReadinessBand,
        yesterdayLoad: Int?,
        hrv: MetricTile?,
        restingHR: MetricTile?
    ) -> String {
        let sentence =
            switch band {
            case .ready:
                "You've recovered well. A good day to push: go for a harder session if you feel "
                    + "like it."
            case .steady:
                "You're part-way recovered. Train at a moderate pace and keep your Load under "
                    + "\(steadyLoadCap) today."
            case .takeItEasy:
                "Your body hasn't recovered yet. Rest, hydrate and get to bed early, and keep your "
                    + "Load under \(takeItEasyLoadCap) today."
            }
        guard band != .ready else { return sentence }
        let reasons = reasons(yesterdayLoad: yesterdayLoad, hrv: hrv, restingHR: restingHR)
        return reasons.isEmpty ? sentence : "\(joined(reasons)). \(sentence)"
    }

    /// What applies, in order: a high Load yesterday, HRV below Baseline, Resting HR above it.
    private static func reasons(yesterdayLoad: Int?, hrv: MetricTile?, restingHR: MetricTile?)
        -> [String]
    {
        var reasons: [String] = []
        if let load = yesterdayLoad, load >= highLoad {
            reasons.append("Yesterday's Load was high (\(load))")
        }
        if let hrv, hrv.differenceDirection == .down, let percent = hrv.differenceAsShown {
            reasons.append("HRV is \(abs(percent))% below your Baseline")
        }
        if let restingHR, restingHR.differenceDirection == .up,
            let bpm = restingHR.differenceAsShown
        {
            reasons.append("Resting HR is up \(bpm) bpm")
        }
        return reasons
    }

    /// "A", "A and B", "A, B and C".
    private static func joined(_ parts: [String]) -> String {
        guard let last = parts.last, parts.count > 1 else { return parts.first ?? "" }
        return parts.dropLast().joined(separator: ", ") + " and " + last
    }
}
