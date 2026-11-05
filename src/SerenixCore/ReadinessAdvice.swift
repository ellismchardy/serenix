import Foundation

/// The advice under the Readiness message's band word (spec 002, Readiness message): the band's
/// sentence, led for Steady and Take it easy by why: the inputs that cost Readiness the most.
enum ReadinessAdvice {
    /// The Load to stay under today when Steady: about an hour of moderate exercise. Load points,
    /// 0–100 (ADR 0005; spec 005, Readiness advice). Assumption: tune with real Days.
    static let steadyLoadCap = 50
    /// The Load to stay under today when Take it easy: about a 30-minute brisk walk. Load points,
    /// 0–100 (ADR 0005; spec 005, Readiness advice). Assumption: tune with real Days.
    static let takeItEasyLoadCap = 33

    /// `breakdown` is the Night's Readiness breakdown; `yesterdayLoad` is the Load of the Day
    /// before the Day shown; `hrv` and `sleepingHR` are the Night's tiles.
    static func text(
        for band: ReadinessBand,
        breakdown: Readiness.Breakdown?,
        yesterdayLoad: Int?,
        hrv: MetricTile?,
        sleepingHR: MetricTile?
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
        guard let breakdown else { return sentence }
        let reasons = breakdown.costliestInputs.enumerated().compactMap { position, input in
            reason(
                input,
                first: position == 0,
                breakdown: breakdown,
                yesterdayLoad: yesterdayLoad,
                hrv: hrv,
                sleepingHR: sleepingHR
            )
        }
        return reasons.isEmpty ? sentence : "\(joined(reasons)). \(sentence)"
    }

    /// One input's reason; "You slept" is lower-cased when it isn't the first.
    private static func reason(
        _ input: Readiness.Input,
        first: Bool,
        breakdown: Readiness.Breakdown,
        yesterdayLoad: Int?,
        hrv: MetricTile?,
        sleepingHR: MetricTile?
    ) -> String? {
        switch input {
        case .hrv:
            // A difference that rounds to 0 isn't worth a reason, whatever its points.
            guard let percent = hrv?.differenceAsShown, percent != 0 else { return nil }
            return "HRV is \(abs(percent))% below your Baseline"
        case .sleepingHR:
            guard let bpm = sleepingHR?.differenceAsShown, bpm != 0 else { return nil }
            return "Sleeping HR is up \(abs(bpm)) bpm"
        case .timeAsleep:
            let minutesShort = breakdown.minutesShort
            guard minutesShort > 0 else { return nil }
            return "\(first ? "You" : "you") slept \(hoursMinutesText(minutesShort)) less than "
                + "your Sleep Need"
        case .previousDayLoad:
            return yesterdayLoad.map { "Yesterday's Load was high (\($0))" }
        }
    }

    /// "A", "A and B", "A, B and C", "A, B, C and D".
    private static func joined(_ parts: [String]) -> String {
        guard let last = parts.last, parts.count > 1 else { return parts.first ?? "" }
        return parts.dropLast().joined(separator: ", ") + " and " + last
    }
}
