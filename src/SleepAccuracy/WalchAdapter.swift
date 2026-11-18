import Foundation
import SerenixCore

/// Reads Walch et al.'s sleep-accel 1.0.0 dataset (PhysioNet; Apple Watch + PSG) into Reference
/// Nights (spec 019). Per recording `<id>`: `motion/<id>_acceleration.txt` (time, x, y, z in g),
/// `heart_rate/<id>_heartrate.txt` (time, bpm) and `labels/<id>_labeled_sleep.txt` (time,
/// stage), every time in seconds from the start of the PSG. The separator isn't documented, so
/// commas and whitespace are both accepted.
public enum WalchAdapter {
    /// PSG time 0 for every recording: a whole UTC minute (the Unix epoch), so each Serenix minute
    /// covers exactly two Epochs. The dataset gives no calendar dates.
    public static let psgStart = Date(timeIntervalSince1970: 0)
    /// Seconds: the longest a heart-rate reading is carried forward. Walch's heart rate comes
    /// every 5–10 s, so this bridges normal gaps without inventing data across dropouts (#81).
    public static let longestHeartRateCarry: TimeInterval = 15

    /// Every recording in `folder` (ids found in any of the three folders), sorted by id. Throws
    /// when there are none, so a wrong folder never passes as an empty dataset.
    public static func referenceNights(in folder: URL) throws -> [ReferenceNight] {
        let ids = Set(DataFile.allCases.flatMap { $0.recordingIDs(in: folder) })
        guard !ids.isEmpty else { throw WalchAdapterError.noRecordings(folder: folder.path) }
        return try ids.sorted().map { try referenceNight(id: $0, in: folder) }
    }

    private static func referenceNight(id: String, in folder: URL) throws -> ReferenceNight {
        let motion = try DataFile.motion.values(of: id, in: folder, columns: 4)
        let heartRate = try DataFile.heartRate.values(of: id, in: folder, columns: 2)
        let labels = try DataFile.labels.values(of: id, in: folder, columns: 2)
        return ReferenceNight(
            id: id,
            seconds: labellingSeconds(
                motion: stride(from: 0, to: motion.count, by: 4).map {
                    (time: motion[$0], axes: (motion[$0 + 1], motion[$0 + 2], motion[$0 + 3]))
                },
                heartRate: stride(from: 0, to: heartRate.count, by: 2)
                    .map { (time: heartRate[$0], bpm: heartRate[$0 + 1]) }
                    .sorted { $0.time < $1.time }
            ),
            epochs: try stride(from: 0, to: labels.count, by: 2).map { offset in
                let (time, code) = (labels[offset], labels[offset + 1])
                guard (time / epochSeconds).rounded() == time / epochSeconds else {
                    throw WalchAdapterError.offGridLabel(recording: id, time: time)
                }
                guard let label = epochLabel(code) else {
                    throw WalchAdapterError.unknownLabel(recording: id, time: time, code: code)
                }
                return Epoch(start: psgStart + time, label: label)
            }
        )
    }

    /// One labelling second for each whole second with acceleration samples: its Tilt from the
    /// second before (nil when that second has no samples, or either has no gravity direction)
    /// and its carried heart rate. Samples are sorted by time (then values, so a repeated time
    /// always keeps the same sample) and repeats dropped.
    private static func labellingSeconds(
        motion: [(time: Double, axes: (Double, Double, Double))],
        heartRate: [(time: Double, bpm: Double)]
    ) -> [LabellingSecond] {
        let sorted = motion.sorted {
            ($0.time, $0.axes.0, $0.axes.1, $0.axes.2) < ($1.time, $1.axes.0, $1.axes.1, $1.axes.2)
        }
        var seconds: [LabellingSecond] = []
        var nextReading = 0
        var lastReading: (time: Double, bpm: Double)?
        var previous: (second: Int, gravity: [Double]?)?
        var index = sorted.startIndex
        while index < sorted.endIndex {
            let second = Int(sorted[index].time.rounded(.down))
            var axes: ([Double], [Double], [Double]) = ([], [], [])
            var lastTime: Double?
            while index < sorted.endIndex, Int(sorted[index].time.rounded(.down)) == second {
                if sorted[index].time != lastTime {
                    axes.0.append(sorted[index].axes.0)
                    axes.1.append(sorted[index].axes.1)
                    axes.2.append(sorted[index].axes.2)
                    lastTime = sorted[index].time
                }
                index += 1
            }
            let gravity = unitVector([median(axes.0), median(axes.1), median(axes.2)])
            let time = Double(second)
            while nextReading < heartRate.count, heartRate[nextReading].time <= time {
                lastReading = heartRate[nextReading]
                nextReading += 1
            }
            var angle: Double?
            if let previous, previous.second == second - 1, let before = previous.gravity,
                let gravity
            {
                angle = degrees(between: before, and: gravity)
            }
            seconds.append(
                LabellingSecond(
                    time: psgStart + time,
                    heartRate: lastReading.flatMap {
                        time - $0.time <= longestHeartRateCarry ? $0.bpm : nil
                    },
                    angle: angle
                )
            )
            previous = (second, gravity)
        }
        return seconds
    }

    /// Walch's stage codes (PhysioNet page): 0 wake, 1 N1, 2 N2, 3 N3, 5 REM, −1 unscored. 4 is
    /// undefined there; read as N3 (old R&K stage 4, merged into N3 by AASM). Nil for any other.
    private static func epochLabel(_ code: Double) -> EpochLabel? {
        switch code {
        case 0: .wake
        case 1: .n1
        case 2: .n2
        case 3, 4: .n3
        case 5: .rem
        case -1: .unscored
        default: nil
        }
    }
}

/// Why the Walch adapter couldn't read a dataset. Each names the folder, or the recording.
public enum WalchAdapterError: Error, Equatable {
    /// The folder has no recordings in any of the three subfolders (or doesn't exist).
    case noRecordings(folder: String)
    /// `file` is the missing path relative to the dataset folder.
    case missingFile(recording: String, file: String)
    /// The file exists but couldn't be read as UTF-8 text.
    case unreadableFile(recording: String, file: String)
    /// A line without enough finite numbers; `line` is 1-based.
    case malformedLine(recording: String, file: String, line: Int)
    /// A label time, in seconds from PSG start, that isn't a whole multiple of 30 s.
    case offGridLabel(recording: String, time: Double)
    /// A stage code Walch's dataset doesn't define.
    case unknownLabel(recording: String, time: Double, code: Double)
}

/// The three files a Walch recording needs.
private enum DataFile: CaseIterable {
    case motion
    case heartRate
    case labels

    var folder: String {
        switch self {
        case .motion: "motion"
        case .heartRate: "heart_rate"
        case .labels: "labels"
        }
    }

    var suffix: String {
        switch self {
        case .motion: "_acceleration.txt"
        case .heartRate: "_heartrate.txt"
        case .labels: "_labeled_sleep.txt"
        }
    }

    func path(of id: String) -> String { "\(folder)/\(id)\(suffix)" }

    /// The ids of this file's recordings in `root`; none when the subfolder can't be listed.
    func recordingIDs(in root: URL) -> [String] {
        let names =
            (try? FileManager.default.contentsOfDirectory(
                atPath: root.appendingPathComponent(folder).path
            )) ?? []
        return names.filter { $0.hasSuffix(suffix) }.map { String($0.dropLast(suffix.count)) }
    }

    /// Each non-empty line's first `columns` numbers, all finite, one line after another in a
    /// single flat array (a day at 50 Hz is millions of lines).
    func values(of id: String, in root: URL, columns: Int) throws -> [Double] {
        let file = path(of: id)
        let url = root.appendingPathComponent(file)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw WalchAdapterError.missingFile(recording: id, file: file)
        }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw WalchAdapterError.unreadableFile(recording: id, file: file)
        }
        var values: [Double] = []
        var lineNumber = 0
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            lineNumber += 1
            let fields = line.split { $0 == "," || $0.isWhitespace }
            if fields.isEmpty { continue }
            let numbers = fields.prefix(columns).compactMap { Double($0) }.filter(\.isFinite)
            guard numbers.count == columns else {
                throw WalchAdapterError.malformedLine(recording: id, file: file, line: lineNumber)
            }
            values.append(contentsOf: numbers)
        }
        return values
    }
}

/// The middle value, or the mean of the two middle values; `values` is never empty here.
private func median(_ values: [Double]) -> Double {
    let sorted = values.sorted()
    let middle = sorted.count / 2
    guard sorted.count.isMultiple(of: 2) else { return sorted[middle] }
    return (sorted[middle - 1] + sorted[middle]) / 2
}

/// `vector` scaled to unit length; nil when it has none (no gravity direction to compare).
private func unitVector(_ vector: [Double]) -> [Double]? {
    let length = vector.map { $0 * $0 }.reduce(0, +).squareRoot()
    return length == 0 ? nil : vector.map { $0 / length }
}

/// Degrees between two unit vectors.
private func degrees(between a: [Double], and b: [Double]) -> Double {
    let dot = zip(a, b).map { $0 * $1 }.reduce(0, +)
    return acos(max(-1, min(1, dot))) * 180 / .pi
}
