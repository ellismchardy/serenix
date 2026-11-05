import Foundation

/// Everything the Body tab's weight screen shows (spec 014), worked out from the stored
/// Weigh-ins each time, never stored (ADR 0008). The shell draws it.
public struct BodyView: Equatable, Sendable {
    /// One point per Day with a Weigh-in, oldest first.
    public let trend: [TrendPoint]
    /// The latest Trend Weight in kg; nil with no Weigh-ins.
    public let trendWeight: Double?
    /// The most recent Weigh-in by time.
    public let lastWeighIn: WeighIn?
    /// Every Weigh-in, newest first, for the Weigh-in list.
    public let weighIns: [WeighIn]

    public init(weighIns: [WeighIn], now: Date, timeZone: TimeZone) {
        let newestFirst = weighIns.sorted { $0.time > $1.time }
        self.weighIns = newestFirst
        lastWeighIn = newestFirst.first
        trend = Self.trend(of: weighIns, in: timeZone)
        trendWeight = trend.last?.trendWeight
    }

    /// The share of the gap between Trend Weight and a new Weigh-in that Trend Weight keeps over
    /// one Day, so one Day closes 0.1 of it: the Hacker's Diet step (issue #50,
    /// `docs/research/trend-weight-smoothing.md`). Over `Δd` Days the share closed is
    /// `1 − trendKeep^Δd`, so a gap counts as that many daily steps.
    static let trendKeep = 0.9

    /// The most Days between counted Weigh-ins that Trend Weight carries across; after a longer
    /// gap it restarts at the new Weigh-in (issue #50: after 14 Days only 0.9^14 ≈ 23% of the
    /// old trend would remain, so it says little).
    static let longestGap = 14

    /// Trend Weight over the counted Weigh-ins: the lowest on each Day (spec 014, Weigh-ins).
    static func trend(of weighIns: [WeighIn], in timeZone: TimeZone) -> [TrendPoint] {
        var lowest: [Day: Double] = [:]
        for weighIn in weighIns {
            let day = Day(containing: weighIn.time, in: timeZone)
            lowest[day] = min(lowest[day] ?? .infinity, weighIn.kilograms)
        }
        var points: [TrendPoint] = []
        for (day, weight) in lowest.sorted(by: { $0.key < $1.key }) {
            guard let previous = points.last,
                previous.day.days(until: day) <= longestGap
            else {
                points.append(
                    TrendPoint(day: day, weighIn: weight, trendWeight: weight, startsNewLine: true)
                )
                continue
            }
            let step = 1 - pow(trendKeep, Double(previous.day.days(until: day)))
            let trend = previous.trendWeight + step * (weight - previous.trendWeight)
            points.append(TrendPoint(day: day, weighIn: weight, trendWeight: trend))
        }
        return points
    }
}
