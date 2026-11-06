import Foundation

/// One stored Weight Goal and how it ended; no end for the current one (ADR 0008).
public struct GoalRecord: Equatable, Codable, Sendable {
    public let goal: WeightGoal
    public let endedAt: Date?
    public let endReason: GoalEnd?

    public init(goal: WeightGoal, endedAt: Date? = nil, endReason: GoalEnd? = nil) {
        self.goal = goal
        self.endedAt = endedAt
        self.endReason = endReason
    }
}

/// All Body data: every Weigh-in and every Weight Goal, current and ended (spec 015).
public struct BodyData: Equatable, Sendable {
    public let weighIns: [WeighIn]
    public let goals: [GoalRecord]

    public init(weighIns: [WeighIn], goals: [GoalRecord]) {
        self.weighIns = weighIns
        self.goals = goals
    }
}

/// Why a Body data file can't be imported; nothing from it is imported (spec 015).
public enum BodyDataFileError: Error, Equatable {
    /// Not JSON, cut short, or missing what a Body data file holds.
    case unreadable
    /// JSON, but not a Serenix Body data file.
    case wrongFormat
    /// Written by a newer Serenix, in a version this one can't read.
    case newerVersion(Int)
    /// Holds a Weigh-in or Weight Goal Serenix would refuse if typed in.
    case invalidEntry

    public var message: String {
        switch self {
        case .unreadable: "This file can't be read as Serenix Body data."
        case .wrongFormat: "This isn't a Serenix Body data file."
        case .invalidEntry: "This file holds a Weigh-in or Weight Goal Serenix can't accept."
        case .newerVersion(let version):
            "This file is version \(version), from a newer Serenix. Update the app to import it."
        }
    }
}

/// What importing a file adds, and how many of its entries are already here.
public struct BodyImport: Equatable, Sendable {
    public let weighInsToAdd: [WeighIn]
    public let goalsToAdd: [GoalRecord]
    /// Exact duplicates skipped: already here, or repeated in the file.
    public let skipped: Int
}

/// The JSON backup of all Body data (spec 015, Backup and import): versioned, and lossless.
public enum BodyDataFile {
    /// Names a Serenix Body data file, so another JSON file is told apart.
    public static let format = "serenix-body"
    /// The version this build writes and the newest it reads.
    public static let version = 1

    /// The file's layout. Times and Days use Foundation's default encoding, which keeps every
    /// fraction of a second.
    private struct File: Codable {
        let format: String
        let version: Int
        let weighIns: [WeighIn]
        let goals: [GoalRecord]
    }

    /// Just the header, read first so a wrong format or newer version is told apart from a
    /// broken file.
    private struct Header: Decodable {
        let format: String?
        let version: Int?
    }

    public static func encode(_ data: BodyData) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(
            File(format: format, version: version, weighIns: data.weighIns, goals: data.goals)
        )
    }

    public static func decode(_ file: Data) throws(BodyDataFileError) -> BodyData {
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: file) else {
            throw .unreadable
        }
        guard let fileFormat = header.format else { throw .unreadable }
        guard fileFormat == format else { throw .wrongFormat }
        guard let fileVersion = header.version else { throw .unreadable }
        guard fileVersion <= version else { throw .newerVersion(fileVersion) }
        guard let body = try? decoder.decode(File.self, from: file) else { throw .unreadable }
        return BodyData(weighIns: body.weighIns, goals: body.goals)
    }

    /// Why `file` can't be imported as it stands: a file is untrusted, so any Weigh-in Serenix
    /// would refuse at `now`, or any Weight Goal that wouldn't save in any units (lb units offer
    /// other rates), refuses the whole file before anything is offered. Nil when all is fine.
    public static func refusal(_ file: BodyData, now: Date) -> BodyDataFileError? {
        let badWeighIn = file.weighIns.contains { $0.refusal(now: now) != nil }
        let badGoal = file.goals.contains { record in
            WeightUnits.allCases.allSatisfy { record.goal.refusal(units: $0) != nil }
        }
        return badWeighIn || badGoal ? .invalidEntry : nil
    }

    /// What importing `file` into `current` adds: every entry not already here, each once. A
    /// Weigh-in is a duplicate with the same time and weight; a Weight Goal, when the same goal
    /// is here in any state. A file's current goal arrives ended as changed at `now` when
    /// `current` already has a current goal, so there's never two.
    public static func importing(
        _ file: BodyData,
        into current: BodyData,
        now: Date
    ) -> BodyImport {
        var seenWeighIns = Set(current.weighIns)
        let weighInsToAdd = file.weighIns.filter { seenWeighIns.insert($0).inserted }
        var seenGoals = current.goals.map(\.goal)
        var hasCurrentGoal = current.goals.contains { $0.endedAt == nil }
        var goalsToAdd: [GoalRecord] = []
        for record in file.goals where !seenGoals.contains(record.goal) {
            seenGoals.append(record.goal)
            if record.endedAt == nil, hasCurrentGoal {
                goalsToAdd.append(GoalRecord(goal: record.goal, endedAt: now, endReason: .changed))
            } else {
                if record.endedAt == nil { hasCurrentGoal = true }
                goalsToAdd.append(record)
            }
        }
        let skipped =
            file.weighIns.count - weighInsToAdd.count + file.goals.count - goalsToAdd.count
        return BodyImport(weighInsToAdd: weighInsToAdd, goalsToAdd: goalsToAdd, skipped: skipped)
    }
}
