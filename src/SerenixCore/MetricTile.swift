import Foundation

/// One Nightly Metric's tile on the Today screen (spec 002, Tiles).
public struct MetricTile: Equatable, Sendable {
    public let metric: NightlyMetric
    /// The value with its unit, e.g. "62 ms", or "—" when the Night doesn't have it.
    public let valueText: String
    /// The Baseline's median; nil while it's Calibrating, and always for SpO2.
    public let baseline: Double?
    /// The difference from Baseline, e.g. "+14%" or "−3 bpm"; SpO2's level in words;
    /// "Calibrating" while the Baseline is; "—" when the value is missing.
    public let differenceText: String
    /// Nil while Calibrating or when the value is missing.
    public let zone: Zone?
    /// The trend line's values, oldest first.
    public let trend: [Double]

    init(_ metric: NightlyMetric, for night: Night, among nights: [Night]) {
        self.metric = metric
        let value = night.value(of: metric)
        let baseline =
            metric.hasBaseline ? Baseline(metric, for: night, among: nights).median : nil
        self.baseline = baseline
        zone = value.flatMap { Zone(metric, value: $0, baseline: baseline) }
        valueText = value.map { formattedValue(of: metric, $0) } ?? missingText
        differenceText =
            switch (value, baseline) {
            case (nil, _): missingText
            case (_, _) where metric == .spo2: spo2LevelText(zone)
            case (_, nil): "Calibrating"
            case (let value?, let baseline?):
                formattedDifference(of: metric, value - baseline, baseline)
            }
        trend = trendValues(of: { $0.value(of: metric) }, upTo: night, among: nights)
    }
}

/// The value with its unit (spec 002, Formats).
private func formattedValue(of metric: NightlyMetric, _ value: Double) -> String {
    switch metric {
    case .restingHR: "\(wholeText(value)) bpm"
    case .hrv: "\(wholeText(value)) ms"
    case .respiratoryRate: "\(tenthsText(value)) br/min"
    case .skinTemperature: "\(tenthsText(value)) °C"
    case .spo2: "\(wholeText(value))%"
    }
}

/// The difference from Baseline (spec 002, Tiles): HRV as a whole percentage of it, Resting HR
/// in whole bpm, respiratory rate and skin temperature to one decimal with no unit.
private func formattedDifference(of metric: NightlyMetric, _ difference: Double, _ baseline: Double)
    -> String
{
    switch metric {
    // A difference from a Baseline of 0 or less means nothing as a percentage.
    case .hrv: baseline > 0 ? "\(signedWholeText(difference / baseline * 100))%" : missingText
    case .restingHR: "\(signedWholeText(difference)) bpm"
    case .respiratoryRate, .skinTemperature: signedTenthsText(difference)
    case .spo2: missingText
    }
}

/// SpO2's line under its value: its Zone's level in words (spec 002, Tiles).
private func spo2LevelText(_ zone: Zone?) -> String {
    switch zone {
    case .inRange: "95% or above"
    case .watch: "Below 95%"
    case .outOfRange: "Below 92%"
    case nil: missingText
    }
}

private func wholeText(_ value: Double) -> String {
    String(Int(value.rounded()))
}

/// To one decimal place, e.g. "14.0".
private func tenthsText(_ value: Double) -> String {
    let tenths = Int((value * 10).rounded())
    let sign = tenths < 0 ? "\u{2212}" : ""
    return "\(sign)\(abs(tenths) / 10).\(abs(tenths) % 10)"
}

/// Signed with "+" or "−" (U+2212); one that rounds to zero has no sign.
private func signedWholeText(_ value: Double) -> String {
    let whole = Int(value.rounded())
    return whole > 0 ? "+\(whole)" : whole < 0 ? "\u{2212}\(-whole)" : "0"
}

private func signedTenthsText(_ value: Double) -> String {
    let tenths = Int((value * 10).rounded())
    return tenths > 0 ? "+\(tenthsText(value))" : tenths < 0 ? tenthsText(value) : "0.0"
}
