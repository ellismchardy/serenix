import Foundation

/// One Night's Baseline for one Nightly Metric (GLOSSARY, specs 002 and 004): the median of that
/// metric over the most recent earlier Nights that have it, and its Spread. The Night itself is
/// never part of it.
struct Baseline: Equatable, Sendable {
    /// How many earlier Nights have a value for the metric, all of them, not only those used.
    let earlierNights: Int
    /// Nil while the Baseline is Calibrating.
    let median: Double?
    /// How much the metric usually varies from Night to Night (GLOSSARY, Spread), on ln(RMSSD)
    /// for HRV. Nil while Calibrating, and for metrics whose Spread isn't worked out yet.
    let spread: Double?

    /// At most this many of the most recent earlier Nights count (spec 002, Baseline).
    static let maxNights = 14
    /// Calibrating until this many earlier Nights have a value, so the 4th Night with one is the
    /// first with a Baseline (spec 002; docs/architecture.md, "calibrating until 4 Nights").
    static let minEarlierNights = 3
    /// HRV's typical Spread, on ln(RMSSD) (spec 004, Spread). Assumption from issue #14 and
    /// docs/research/nightly-metric-deviation.md: tune with real Nights.
    static let hrvTypicalSpread = 0.15

    init(_ metric: NightlyMetric, for night: Night, among nights: [Night]) {
        // Newest first; missing values are skipped, never counted as 0.
        let earlier =
            nights
            .filter { $0.day < night.day }
            .sorted { $0.day > $1.day }
            .compactMap { $0.value(of: metric) }
        earlierNights = earlier.count
        median =
            earlier.count < Self.minEarlierNights
            ? nil : Self.median(of: Array(earlier.prefix(Self.maxNights)))
        spread = median == nil ? nil : Self.typicalSpread(of: metric)
    }

    /// The Spread used until there are enough Nights to measure the user's own (spec 004).
    private static func typicalSpread(of metric: NightlyMetric) -> Double? {
        switch metric {
        case .hrv: hrvTypicalSpread
        case .restingHR, .respiratoryRate, .skinTemperature, .spo2: nil
        }
    }

    var isCalibrating: Bool { median == nil }

    /// The middle value, or the mean of the two middle values for an even count.
    private static func median(of values: [Double]) -> Double {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
}
