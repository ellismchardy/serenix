import Foundation

/// Everything a Backup holds (GLOSSARY, spec 020): every stored Night and Day, and all Body
/// data. History Records, the Sync Log and the Profile are never in it.
public struct Backup: Equatable, Sendable {
    public let nights: [Night]
    /// Each Day's Resting HR, Load and HR Zones.
    public let days: [DayLoad]
    public let body: BodyData

    public init(nights: [Night], days: [DayLoad], body: BodyData) {
        self.nights = nights
        self.days = days
        self.body = body
    }
}

/// Why a file can't be imported as a Backup; nothing from it is imported (spec 020).
public enum BackupFileError: Error, Equatable {
    /// Not JSON, cut short, or missing what a Backup holds.
    case unreadable
    /// JSON, but neither a Serenix Backup nor a Serenix Body data file.
    case wrongFormat
    /// Written by a newer Serenix, in a version this one can't read.
    case newerVersion(Int)

    public var message: String {
        switch self {
        case .unreadable: "This file can't be read as a Serenix Backup."
        case .wrongFormat: "This isn't a Serenix Backup."
        case .newerVersion(let version):
            "This file is version \(version), made by a newer Serenix. Update the app to import it."
        }
    }
}

/// The JSON Backup of Nights, Days and Body data (spec 020): versioned and lossless. It
/// replaces the Body data file, whose version 1 and 2 files it still reads; every Body rule stays
/// with `BodyDataFile`.
public enum BackupFile {
    /// Names a Serenix Backup, so another JSON file is told apart.
    public static let format = "serenix-backup"
    /// The version this build writes and the newest it reads. 3 follows the Body data file's 2,
    /// so one version number runs through both formats.
    public static let version = 3

    /// The file's layout. Times use Foundation's default encoding, which keeps every fraction of
    /// a second; the Body data keys are those of a version 2 Body data file.
    private struct File: Codable {
        let format: String
        let version: Int
        let nights: [Night]
        let days: [DayLoad]
        let weighIns: [WeighIn]
        let goals: [GoalRecord]
        let foodEntries: [FoodEntry]
        let completeDays: [Day]
        let foodTargets: FoodTargets
    }

    /// Just the header, read first so a wrong format or newer version is told apart from a
    /// broken file.
    private struct Header: Decodable {
        let format: String?
        let version: Int?
    }

    public static func encode(_ backup: Backup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(
            File(
                format: format,
                version: version,
                nights: backup.nights,
                days: backup.days,
                weighIns: backup.body.weighIns,
                goals: backup.body.goals,
                foodEntries: backup.body.foodEntries,
                completeDays: backup.body.completeDays.sorted(),
                foodTargets: backup.body.foodTargets
            )
        )
    }

    /// The Backup in `file`. A Body data file (version 1 or 2) gives its Body data with no Nights
    /// or Days.
    public static func decode(_ file: Data) throws(BackupFileError) -> Backup {
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: file),
            let fileFormat = header.format
        else { throw .unreadable }
        if fileFormat == BodyDataFile.format { return try decodeBodyDataFile(file) }
        guard fileFormat == format else { throw .wrongFormat }
        guard let fileVersion = header.version else { throw .unreadable }
        guard fileVersion <= version else { throw .newerVersion(fileVersion) }
        guard let backup = try? decoder.decode(File.self, from: file) else { throw .unreadable }
        return Backup(
            nights: backup.nights,
            days: backup.days,
            body: BodyData(
                weighIns: backup.weighIns,
                goals: backup.goals,
                foodEntries: backup.foodEntries,
                completeDays: Set(backup.completeDays),
                foodTargets: backup.foodTargets
            )
        )
    }

    private static func decodeBodyDataFile(_ file: Data) throws(BackupFileError) -> Backup {
        do {
            return Backup(nights: [], days: [], body: try BodyDataFile.decode(file))
        } catch {
            switch error {
            case .wrongFormat: throw .wrongFormat
            case .newerVersion(let version): throw .newerVersion(version)
            // `BodyDataFile.decode` never throws `.invalidEntry`: entries are judged by
            // `refusal`, after decoding.
            case .unreadable, .invalidEntry: throw .unreadable
            }
        }
    }
}
