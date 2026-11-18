import Foundation
import SerenixCore

/// Reads History Records from the fixture CSV format (spec 019's Strap transfer run): header
/// `counter,utc,hr,rr_ms,q0,q1,q2,q3,temp_c,spo2_window,spo2`, optionally followed by `steps`;
/// `rr_ms` holds space-separated RR intervals and may be empty; `utc` is ISO 8601.
public enum HistoryRecordCSV {
    /// The header every file starts with, exactly, optionally followed by `,steps`.
    static let header = "counter,utc,hr,rr_ms,q0,q1,q2,q3,temp_c,spo2_window,spo2"

    /// History Records from `text`, oldest first (by timestamp, then Record Counter), repeats
    /// dropped by identity. `file` names the source in errors.
    public static func records(from text: String, file: String) throws -> [HistoryRecord] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let firstLine = lines.first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        let columns: Int
        switch firstLine {
        case header: columns = 11
        case header + ",steps": columns = 12
        default: throw HistoryRecordCSVError.missingHeader(file: file)
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        var records: [HistoryRecord] = []
        for (offset, line) in lines.enumerated().dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            guard let record = record(from: trimmed, columns: columns, formatter: formatter) else {
                throw HistoryRecordCSVError.malformedLine(file: file, line: offset + 1)
            }
            records.append(record)
        }
        var seen = Set<String>()
        let unique = records.filter { seen.insert($0.identity).inserted }
        return unique.sorted {
            ($0.timestamp, $0.recordCounter) < ($1.timestamp, $1.recordCounter)
        }
    }

    /// Nil when the line hasn't `columns` fields or any field doesn't parse.
    private static func record(
        from line: String,
        columns: Int,
        formatter: ISO8601DateFormatter
    ) -> HistoryRecord? {
        let fields = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        guard fields.count == columns,
            let counter = UInt32(fields[0]),
            let timestamp = formatter.date(from: fields[1]),
            let heartRate = Int(fields[2]),
            let skinTemperature = Double(fields[8]), skinTemperature.isFinite,
            let spo2Window = Int(fields[9]),
            let spo2 = Int(fields[10])
        else { return nil }
        let motion = fields[4...7].compactMap { Float($0) }
        let rrIntervals = fields[3].split(separator: " ").compactMap { Int($0) }
        let steps = fields.count == 12 ? Int(fields[11]) : 0
        guard motion.count == 4, motion.allSatisfy(\.isFinite),
            rrIntervals.count == fields[3].split(separator: " ").count, let steps
        else { return nil }
        return HistoryRecord(
            recordCounter: counter,
            timestamp: timestamp,
            heartRate: heartRate,
            rrIntervals: rrIntervals,
            motion: motion,
            skinTemperature: skinTemperature,
            steps: steps,
            spo2: spo2,
            isInSpO2Window: spo2Window == 1,
            rawBytes: []
        )
    }
}

/// Why a fixture CSV couldn't be read. Each names the file.
public enum HistoryRecordCSVError: Error, Equatable {
    case missingHeader(file: String)
    /// `line` is 1-based; the header is line 1.
    case malformedLine(file: String, line: Int)
}
