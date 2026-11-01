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
    /// Which way the difference from Baseline goes as shown; nil when it shows as zero or there's
    /// no difference to show.
    let differenceDirection: BaselineDirection?

    init(_ metric: NightlyMetric, for night: Night, among nights: [Night]) {
        self.metric = metric
        let value = night.value(of: metric)
        let baseline =
            metric.hasBaseline ? Baseline(metric, for: night, among: nights).median : nil
        self.baseline = baseline
        zone = value.flatMap { Zone(metric, value: $0, baseline: baseline) }
        valueText = value.map { formattedValue(of: metric, $0) } ?? missingText
        // The difference as shown, in whole units: its text and its direction both come from it.
        let shown = value.flatMap { value in
            baseline.flatMap { shownDifference(of: metric, value - $0, $0) }
        }
        differenceText =
            switch (value, baseline) {
            case (nil, _): missingText
            case (_, _) where metric == .spo2: spo2LevelText(zone)
            case (_, nil): "Calibrating"
            case (_, _?): shown.map { formattedDifference(of: metric, $0) } ?? missingText
            }
        differenceDirection =
            switch shown?.signum() {
            case 1?: .up
            case (-1)?: .down
            default: nil
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

/// The difference from Baseline in the whole units it's shown in (spec 002, Tiles): HRV as a
/// percentage of Baseline, Resting HR in bpm, respiratory rate and skin temperature in tenths.
/// Nil for SpO2, for HRV against a Baseline of 0 or less, and when it's too large to show.
private func shownDifference(of metric: NightlyMetric, _ difference: Double, _ baseline: Double)
    -> Int?
{
    let shown: Double? =
        switch metric {
        case .hrv: baseline > 0 ? difference / baseline * 100 : nil
        case .restingHR: difference
        case .respiratoryRate, .skinTemperature: difference * 10
        case .spo2: nil
        }
    // `Int(exactly:)` gives nil rather than crashing on a value too large for an Int.
    return shown.flatMap { Int(exactly: $0.rounded()) }
}

/// A shown difference as text: "+14%", "−3 bpm", "+0.4"; one that's zero has no sign.
private func formattedDifference(of metric: NightlyMetric, _ shown: Int) -> String {
    let sign = shown > 0 ? "+" : shown < 0 ? "\u{2212}" : ""
    let size = abs(shown)
    return switch metric {
    case .hrv: "\(sign)\(size)%"
    case .restingHR: "\(sign)\(size) bpm"
    case .respiratoryRate, .skinTemperature: "\(sign)\(size / 10).\(size % 10)"
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
