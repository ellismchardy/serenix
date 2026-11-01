import Foundation
import SerenixCore

/// A fixture night in `Fixtures/`: untrimmed real History Records from the project owner's own
/// nights, one CSV row per second (docs/conventions.md, Testing).
enum NightFixture {
    /// The night of 29–30 Oct 2026, Europe/London.
    static let night20261030: [HistoryRecord] = records(fixture: "Night-2026-10-30")

    /// Reads `Fixtures/<name>.csv`, whose header is
    /// `counter,utc,hr,rr_ms,q0,q1,q2,q3,temp_c,spo2_window,spo2`.
    static func records(fixture name: String) -> [HistoryRecord] {
        guard
            let url = Bundle.module.url(
                forResource: name,
                withExtension: "csv",
                subdirectory: "Fixtures"
            ),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            fatalError("missing test fixture Fixtures/\(name).csv")
        }
        let lines = text.split(whereSeparator: \.isNewline).dropFirst()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return lines.map { record(from: $0, formatter: formatter) }
    }

    private static func record(from line: Substring, formatter: ISO8601DateFormatter)
        -> HistoryRecord
    {
        let fields = line.split(separator: ",", omittingEmptySubsequences: false)
        guard fields.count == 11,
            let counter = UInt32(fields[0]),
            let timestamp = formatter.date(from: String(fields[1])),
            let heartRate = Int(fields[2]),
            let motion = Optional(fields[4...7].compactMap { Float($0) }), motion.count == 4,
            let skinTemperature = Double(fields[8]),
            let spo2Window = Int(fields[9]),
            let spo2 = Int(fields[10])
        else {
            fatalError("malformed fixture line: \(line)")
        }
        let rrIntervals = fields[3].split(separator: " ").map { value in
            guard let interval = Int(value) else { fatalError("bad RR interval: \(line)") }
            return interval
        }
        return HistoryRecord(
            recordCounter: counter,
            timestamp: timestamp,
            heartRate: heartRate,
            rrIntervals: rrIntervals,
            motion: motion,
            skinTemperature: skinTemperature,
            steps: 0,
            spo2: spo2,
            isInSpO2Window: spo2Window == 1,
            rawBytes: []
        )
    }
}
