import Foundation

/// The Nightly Metrics, each worked out exactly as hr-tracker's `tools/metrics.py` does (methods:
/// hr-tracker `docs/protocol.md#sleep-metrics`), quirks kept so the two give the same numbers
/// (spec 003). Each takes the Sleep Period's History Records with heart rate above 0, oldest
/// first, and is nil when its method has nothing to work on. Means are summed in order, where
/// Python's `fmean` sums exactly; the two differ only in the last digits.
enum NightlyMetrics {
    /// The span Resting HR averages over: 30 minutes, which is also 1,800 records at one a
    /// second. metrics.py `RHR_SPAN`.
    private static let restingHRSpan = 1800
    /// Records between Resting HR start points: one minute at one a second. metrics.py
    /// `resting_hr()`.
    private static let restingHRStep = 60
    /// ms: the shortest and longest RR interval kept for HRV and respiratory rate. metrics.py
    /// `RR_MIN`, `RR_MAX`.
    static let keptRRIntervals = 600...1600
    /// ms: successive RR differences at least this big are dropped from HRV. metrics.py
    /// `RR_DIFF`.
    private static let largestRRDifference = 200

    /// bpm: the lowest mean heart rate over `restingHRSpan` seconds, trying a start every
    /// `restingHRStep` records (records, not seconds, as metrics.py `resting_hr()` does).
    static func restingHR(of records: [HistoryRecord]) -> Double? {
        guard let last = records.last?.timestamp.timeIntervalSince1970 else { return nil }
        var lowest: Double?
        for start in stride(from: 0, to: records.count, by: restingHRStep) {
            let startTime = records[start].timestamp.timeIntervalSince1970
            let endTime = startTime + Double(restingHRSpan)
            if endTime > last { break }
            // metrics.py looks at most one span plus one step of records ahead.
            let ahead = records[start..<min(records.count, start + restingHRSpan + restingHRStep)]
            let rates = ahead.filter { $0.timestamp.timeIntervalSince1970 < endTime }
                .map(\.heartRate)
            let mean = Double(rates.reduce(0, +)) / Double(rates.count)
            lowest = min(lowest ?? mean, mean)
        }
        return lowest
    }

    /// ms: RMSSD over every RR interval in order, keeping `keptRRIntervals` and successive
    /// differences under `largestRRDifference`. metrics.py `rmssd()`.
    static func hrv(of records: [HistoryRecord]) -> Double? {
        let kept = records.flatMap(\.rrIntervals).filter { keptRRIntervals.contains($0) }
        let differences = zip(kept, kept.dropFirst())
            .map { $1 - $0 }
            .filter { abs($0) < largestRRDifference }
        guard !differences.isEmpty else { return nil }
        let meanSquare =
            Double(differences.map { $0 * $0 }.reduce(0, +)) / Double(differences.count)
        return meanSquare.squareRoot()
    }

    /// °C: the mean of every record's skin temperature, including the minutes while the Strap
    /// warms up. metrics.py `main()`.
    static func skinTemperature(of records: [HistoryRecord]) -> Double? {
        guard !records.isEmpty else { return nil }
        return records.map(\.skinTemperature).reduce(0, +) / Double(records.count)
    }
}
