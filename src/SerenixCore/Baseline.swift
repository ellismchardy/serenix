import Foundation

/// One Night's Baseline for one Nightly Metric (GLOSSARY, spec 002): the median of that metric
/// over the most recent earlier Nights that have it. The Night itself is never part of it.
struct Baseline: Equatable, Sendable {
    /// How many earlier Nights have a value for the metric, all of them, not only those used.
    let earlierNights: Int
    /// Nil while the Baseline is Calibrating.
    let median: Double?

    /// At most this many of the most recent earlier Nights count (spec 002, Baseline).
    static let maxNights = 14
    /// Calibrating until this many earlier Nights have a value, so the 4th Night with one is the
    /// first with a Baseline (spec 002; docs/architecture.md, "calibrating until 4 Nights").
    static let minEarlierNights = 3

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
