import Foundation

/// One Nightly Metric's tile on the Today screen (spec 002, Tiles).
public struct MetricTile: Equatable, Sendable {
    public let metric: NightlyMetric
    /// The value with its unit, e.g. "62 ms", or "—" when the Night doesn't have it.
    public let valueText: String
    /// The Baseline's median; nil while it's Calibrating, and always for SpO2.
    public var baseline: Double? { comparedBaseline?.median }
    /// The difference from Baseline, e.g. "+14%" or "−3 bpm"; SpO2's level in words;
    /// "Calibrating" while the Baseline is; "—" when the value is missing.
    public let differenceText: String
    /// Nil while Calibrating or when the value is missing.
    public let zone: Zone?
    /// "Normal" when In range, else "Low" or "High" by the side of the Baseline the value is on;
    /// SpO2's level; "Calibrating" while the Baseline is; "—" when the value is missing.
    public let statusText: String
    /// Where the value sits on the tile's gauge, 0 (bottom) to 1 (top); nil while Calibrating or
    /// when the value is missing.
    public let gauge: Double?
    /// Which way the difference from Baseline goes as shown; nil when it shows as zero or there's
    /// no difference to show.
    let differenceDirection: BaselineDirection?
    /// The difference from Baseline in the whole units it's shown in: a percentage for HRV, bpm
    /// for Resting HR, tenths for respiratory rate and skin temperature; nil when there's none.
    let differenceAsShown: Int?
    /// The Baseline the value is compared against, Calibrating or not; nil for SpO2.
    let comparedBaseline: Baseline?

    init(_ metric: NightlyMetric, for night: Night, among nights: [Night]) {
        self.metric = metric
        let value = night.value(of: metric)
        let comparedBaseline =
            metric.hasBaseline ? Baseline(metric, for: night, among: nights) : nil
        self.comparedBaseline = comparedBaseline
        let baseline = comparedBaseline?.median
        let zone = value.flatMap { Zone(metric, value: $0, baseline: comparedBaseline) }
        self.zone = zone
        valueText = value.map { formattedValue(of: metric, $0) } ?? missingText
        // The difference as shown, in whole units: its text and its direction both come from it.
        let shown = value.flatMap { value in
            baseline.flatMap { shownDifference(of: metric, value - $0, $0) }
        }
        // Missing, SpO2 and Calibrating read the same on both lines; only a comparison differs.
        let sharedText: String? =
            switch (value, baseline) {
            case (nil, _): missingText
            case (_, _) where metric == .spo2: spo2LevelText(zone)
            case (_, nil): "Calibrating"
            case (_, _?): nil
            }
        differenceText =
            sharedText ?? shown.map { formattedDifference(of: metric, $0) } ?? missingText
        differenceAsShown = shown
        differenceDirection =
            switch shown?.signum() {
            case 1?: .up
            case (-1)?: .down
            default: nil
            }
        statusText =
            sharedText
            ?? value.flatMap { value in
                baseline.map { statusWord(zone, below: value < $0) }
            } ?? missingText
        gauge = value.flatMap { Zone.gaugePosition(metric, value: $0, baseline: comparedBaseline) }
    }
}

/// The value with its unit (spec 002, Formats).
func formattedValue(of metric: NightlyMetric, _ value: Double) -> String {
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

/// A tile's status word (spec 002, Tiles): "Normal" In range, otherwise "Low" below the
/// Baseline and "High" above it; "—" when there's no Zone (HRV against a Baseline of 0 or less).
private func statusWord(_ zone: Zone?, below: Bool) -> String {
    switch zone {
    case .inRange: "Normal"
    case .watch, .outOfRange: below ? "Low" : "High"
    case nil: missingText
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
