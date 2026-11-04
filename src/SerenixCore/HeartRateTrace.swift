import Foundation

/// The user's heart rate through one Night's Time in Bed, in 5-minute steps, kept with the Night
/// (GLOSSARY, spec 012).
public struct HeartRateTrace: Equatable, Codable, Sendable {
    /// How long each step covers, seconds (spec 012: 5 minutes).
    static let step: TimeInterval = 5 * 60
    /// The fewest History Records with a non-zero heart rate a step needs, else it's missing
    /// (spec 012: 150, half a 5-minute step).
    static let fewestRecordsPerStep = 150

    /// UTC: when the first step starts.
    public let start: Date
    /// Mean bpm of each step, unrounded; step i starts `step` × i after `start`, and the last may
    /// be shorter. Nil where a step has too few records.
    public let steps: [Double?]

    public init(start: Date, steps: [Double?]) {
        self.start = start
        self.steps = steps
    }

    /// The trace from `start` to `end` of `records` (any order): each step's mean heart rate over
    /// its records with a non-zero heart rate.
    init(from start: Date, to end: Date, of records: [HistoryRecord]) {
        let count = max(Int((end.timeIntervalSince(start) / Self.step).rounded(.up)), 0)
        var sums = [Int](repeating: 0, count: count)
        var counts = [Int](repeating: 0, count: count)
        for record in records where record.heartRate > 0 {
            let offset = record.timestamp.timeIntervalSince(start)
            guard offset >= 0, record.timestamp < end else { continue }
            // Below `count` since the record is before `end`; `min` only guards rounding.
            let index = min(Int(offset / Self.step), count - 1)
            sums[index] += record.heartRate
            counts[index] += 1
        }
        self.start = start
        steps = zip(sums, counts).map { sum, records in
            records >= Self.fewestRecordsPerStep ? Double(sum) / Double(records) : nil
        }
    }
}
