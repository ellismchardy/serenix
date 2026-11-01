import Foundation

/// One Nightly Metric's tile on the Today screen (spec 002, Tiles). Only HRV has a tile so far,
/// so the value is in ms and the difference a percentage; task 4 adds each metric's own.
public struct MetricTile: Equatable, Sendable {
    public let metric: NightlyMetric
    /// The value with its unit, e.g. "62 ms", or "—" when the Night doesn't have it.
    public let valueText: String
    /// The Baseline's median; nil while it's Calibrating.
    public let baseline: Double?
    /// The difference from Baseline, e.g. "+14%"; "Calibrating" while the Baseline is; "—" when
    /// the value is missing.
    public let differenceText: String

    init(_ metric: NightlyMetric, for night: Night, among nights: [Night]) {
        self.metric = metric
        let value = night.value(of: metric)
        let baseline = Baseline(metric, for: night, among: nights)
        self.baseline = baseline.median
        valueText = value.map { "\(Int($0.rounded())) ms" } ?? missingText
        differenceText =
            switch (value, baseline.median) {
            case (nil, _): missingText
            case (_, nil): "Calibrating"
            // A difference from a Baseline of 0 or less means nothing as a percentage.
            case (_, let median?) where median <= 0: missingText
            case (let value?, let median?): percentText((value - median) / median * 100)
            }
    }
}

/// A difference as a whole, signed percentage, e.g. "+14%" or "−3%" (U+2212 minus).
private func percentText(_ percent: Double) -> String {
    let whole = Int(percent.rounded())
    return whole > 0 ? "+\(whole)%" : whole < 0 ? "\u{2212}\(-whole)%" : "0%"
}
