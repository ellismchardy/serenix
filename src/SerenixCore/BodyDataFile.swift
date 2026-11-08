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

/// All Body data: every Weigh-in and Weight Goal, current and ended (spec 015), and the food
/// log: Food Entries, Complete Days and food targets (spec 016).
public struct BodyData: Equatable, Sendable {
    public let weighIns: [WeighIn]
    public let goals: [GoalRecord]
    public let foodEntries: [FoodEntry]
    public let completeDays: Set<Day>
    public let foodTargets: FoodTargets

    public init(
        weighIns: [WeighIn],
        goals: [GoalRecord],
        foodEntries: [FoodEntry] = [],
        completeDays: Set<Day> = [],
        foodTargets: FoodTargets = FoodTargets()
    ) {
        self.weighIns = weighIns
        self.goals = goals
        self.foodEntries = foodEntries
        self.completeDays = completeDays
        self.foodTargets = foodTargets
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
    /// Holds an entry or target Serenix would refuse if typed in.
    case invalidEntry

    public var message: String {
        switch self {
        case .unreadable: "This file can't be read as Serenix Body data."
        case .wrongFormat: "This isn't a Serenix Body data file."
        case .invalidEntry: "This file holds an entry or target Serenix can't accept."
        case .newerVersion(let version):
            "This file is version \(version), from a newer Serenix. Update the app to import it."
        }
    }
}

/// What importing a file adds, and how many of its entries are already here.
public struct BodyImport: Equatable, Sendable {
    public let weighInsToAdd: [WeighIn]
    public let goalsToAdd: [GoalRecord]
    public let foodEntriesToAdd: [FoodEntry]
    public let completeDaysToAdd: Set<Day>
    /// The file's food targets, when it has some and none are set here; nil otherwise.
    public let foodTargetsToSet: FoodTargets?
    /// Skipped: exact duplicates already here or repeated in the file, Complete Days with no
    /// Food Entry, and the file's food targets when some are set here.
    public let skipped: Int
}

/// The JSON backup of all Body data (spec 015, Backup and import; spec 016, Backup): versioned,
/// and lossless.
public enum BodyDataFile {
    /// Names a Serenix Body data file, so another JSON file is told apart.
    public static let format = "serenix-body"
    /// The version this build writes and the newest it reads: 2 adds food data (spec 016);
    /// version 1 files, with none, still read.
    public static let version = 2

    /// The file's layout. Times and Days use Foundation's default encoding, which keeps every
    /// fraction of a second. The food keys are optional, so a version 1 file reads.
    private struct File: Codable {
        let format: String
        let version: Int
        let weighIns: [WeighIn]
        let goals: [GoalRecord]
        let foodEntries: [FoodEntry]?
        let completeDays: [Day]?
        let foodTargets: FoodTargets?
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
            File(
                format: format,
                version: version,
                weighIns: data.weighIns,
                goals: data.goals,
                foodEntries: data.foodEntries,
                completeDays: data.completeDays.sorted(),
                foodTargets: data.foodTargets
            )
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
        return BodyData(
            weighIns: body.weighIns,
            goals: body.goals,
            foodEntries: body.foodEntries ?? [],
            completeDays: Set(body.completeDays ?? []),
            foodTargets: body.foodTargets ?? FoodTargets()
        )
    }

    /// Why `file` can't be imported as it stands: a file is untrusted, so any Weigh-in or Food
    /// Entry Serenix would refuse at `now`, any Weight Goal that wouldn't save in any units (lb
    /// units offer other rates), or food targets Serenix would refuse, refuses the whole file
    /// before anything is offered. Nil when all is fine.
    public static func refusal(_ file: BodyData, now: Date) -> BodyDataFileError? {
        let badWeighIn = file.weighIns.contains { $0.refusal(now: now) != nil }
        let badGoal = file.goals.contains { record in
            WeightUnits.allCases.allSatisfy { record.goal.refusal(units: $0) != nil }
        }
        let badFoodEntry = file.foodEntries.contains { $0.refusal(now: now) != nil }
        return badWeighIn || badGoal || badFoodEntry || file.foodTargets.isRefused
            ? .invalidEntry : nil
    }

    /// What importing `file` into `current` adds: every entry not already here, each once. A
    /// Weigh-in is a duplicate with the same time and weight; a Food Entry, with every field the
    /// same; a Weight Goal, when the same goal is here in any state. A file's current goal
    /// arrives ended as changed at `now` when `current` already has a current goal, so there's
    /// never two. A Complete Day is added only when that Day, in `timeZone`, has a Food Entry
    /// here or added, as the Food view requires (spec 016); the file's food targets only when
    /// none are set here.
    public static func importing(
        _ file: BodyData,
        into current: BodyData,
        now: Date,
        timeZone: TimeZone
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
        var seenFoodEntries = Set(current.foodEntries)
        let foodEntriesToAdd = file.foodEntries.filter { seenFoodEntries.insert($0).inserted }
        let newCompleteDays = file.completeDays.subtracting(current.completeDays)
        let completeDaysToAdd = FoodView.completeDays(
            newCompleteDays,
            keepingThoseWith: current.foodEntries + foodEntriesToAdd,
            in: timeZone
        )
        let takesTargets = !file.foodTargets.isEmpty && current.foodTargets.isEmpty
        let skippedTargets = !file.foodTargets.isEmpty && !takesTargets ? 1 : 0
        let skipped =
            file.weighIns.count - weighInsToAdd.count + file.goals.count - goalsToAdd.count
            + file.foodEntries.count - foodEntriesToAdd.count
            + file.completeDays.count - completeDaysToAdd.count + skippedTargets
        return BodyImport(
            weighInsToAdd: weighInsToAdd,
            goalsToAdd: goalsToAdd,
            foodEntriesToAdd: foodEntriesToAdd,
            completeDaysToAdd: completeDaysToAdd,
            foodTargetsToSet: takesTargets ? file.foodTargets : nil,
            skipped: skipped
        )
    }
}
