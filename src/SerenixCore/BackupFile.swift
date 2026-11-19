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

/// What importing a Backup adds, and how much of it is already here (spec 020).
public struct BackupImport: Equatable, Sendable {
    /// The file's Nights whose date has no Night here, in file order.
    public let nightsToAdd: [Night]
    /// The file's Days whose date has no Day here, in file order.
    public let daysToAdd: [DayLoad]
    /// What the file's Body data adds, by the Body data file's rules (specs 015–017).
    public let body: BodyImport
    /// Nights and Days whose date is already here (the phone's copy wins), plus the Body data
    /// skipped.
    public let skipped: Int
}

/// The first entry that makes a Backup invalid (spec 020, All or nothing), with the date of its
/// Night or Day.
public enum InvalidBackupEntry: Equatable, Sendable {
    case finalWakeBeforeSleepOnset(Day)
    case repeatedNightDate(Day)
    case repeatedDayDate(Day)
    /// Its start isn't Time in Bed's start, its step count isn't Time in Bed in 5-minute steps
    /// rounded up, as a Night's trace is built (spec 012), or the Night has no Time in Bed.
    case traceDoesNotFitTimeInBed(Day)
    /// It starts before Sleep Onset or ends after Final Wake, or the Night has neither.
    case wakeBoutOutsideSleepPeriod(Day)
    /// A Weigh-in, Weight Goal, Food Entry or food targets the Body data file refuses.
    case bodyEntry

    public var message: String {
        switch self {
        case .finalWakeBeforeSleepOnset(let day):
            "The Night of \(dateText(day)) wakes before it falls asleep."
        case .repeatedNightDate(let day): "It holds two Nights dated \(dateText(day))."
        case .repeatedDayDate(let day): "It holds two Days dated \(dateText(day))."
        case .traceDoesNotFitTimeInBed(let day):
            "The Night of \(dateText(day)) has a Heart Rate Trace that doesn't fit its Time in "
                + "Bed."
        case .wakeBoutOutsideSleepPeriod(let day):
            "The Night of \(dateText(day)) has a Wake Bout outside its Sleep Period."
        case .bodyEntry: "It holds an entry or target Serenix can't accept."
        }
    }

    /// `day` as an ISO date, e.g. 2026-11-03.
    private func dateText(_ day: Day) -> String {
        String(format: "%04d-%02d-%02d", day.year, day.month, day.dayOfMonth)
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
    /// Holds a Night, Day or Body entry Serenix can't accept.
    case invalidEntry(InvalidBackupEntry)

    public var message: String {
        switch self {
        case .unreadable: "This file can't be read as a Serenix Backup."
        case .wrongFormat: "This isn't a Serenix Backup."
        case .newerVersion(let version):
            "This file is version \(version), made by a newer Serenix. Update the app to import it."
        case .invalidEntry(let entry): "This Backup can't be imported. \(entry.message)"
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

    /// What importing `file` into `current` adds. A Night or Day whose date already has one here
    /// is skipped, so the phone's copy, built from History Records it holds, wins; Body data
    /// follows `BodyDataFile.importing`. `file` must have passed `refusal` (spec 020, all or
    /// nothing), which turns away one holding two Nights or two Days with one date.
    public static func importing(
        _ file: Backup,
        into current: Backup,
        now: Date,
        timeZone: TimeZone
    ) -> BackupImport {
        let datesWithNight = Set(current.nights.map(\.day))
        let datesWithDay = Set(current.days.map(\.day))
        let nightsToAdd = file.nights.filter { !datesWithNight.contains($0.day) }
        let daysToAdd = file.days.filter { !datesWithDay.contains($0.day) }
        let body = BodyDataFile.importing(
            file.body,
            into: current.body,
            now: now,
            timeZone: timeZone
        )
        let datesSkipped =
            file.nights.count - nightsToAdd.count + file.days.count - daysToAdd.count
        return BackupImport(
            nightsToAdd: nightsToAdd,
            daysToAdd: daysToAdd,
            body: body,
            skipped: datesSkipped + body.skipped
        )
    }

    /// Why `file` can't be imported as it stands, or nil when every entry is fine. A file is
    /// untrusted, so one bad Night, Day or Body entry refuses it all (spec 020, All or nothing);
    /// Body entries are judged by `BodyDataFile.refusal` at `now`.
    public static func refusal(_ file: Backup, now: Date) -> BackupFileError? {
        var nightDates = Set<Day>()
        for night in file.nights {
            guard nightDates.insert(night.day).inserted else {
                return .invalidEntry(.repeatedNightDate(night.day))
            }
            if let entry = invalidEntry(in: night) { return .invalidEntry(entry) }
        }
        var dayDates = Set<Day>()
        for day in file.days where !dayDates.insert(day.day).inserted {
            return .invalidEntry(.repeatedDayDate(day.day))
        }
        return BodyDataFile.refusal(file.body, now: now) == nil ? nil : .invalidEntry(.bodyEntry)
    }

    /// What's wrong with `night` on its own, if anything.
    private static func invalidEntry(in night: Night) -> InvalidBackupEntry? {
        if let onset = night.sleepOnset, let wake = night.finalWake, wake < onset {
            return .finalWakeBeforeSleepOnset(night.day)
        }
        if let trace = night.heartRateTrace, !trace.fits(night) {
            return .traceDoesNotFitTimeInBed(night.day)
        }
        if let bouts = night.wakeBouts, !bouts.isEmpty {
            guard let onset = night.sleepOnset, let wake = night.finalWake,
                bouts.allSatisfy({ $0.start >= onset && $0.end <= wake })
            else { return .wakeBoutOutsideSleepPeriod(night.day) }
        }
        return nil
    }

    private static func decodeBodyDataFile(_ file: Data) throws(BackupFileError) -> Backup {
        do {
            return Backup(nights: [], days: [], body: try BodyDataFile.decode(file))
        } catch {
            switch error {
            case .wrongFormat: throw .wrongFormat
            case .newerVersion(let version): throw .newerVersion(version)
            case .unreadable: throw .unreadable
            // Never thrown today: `BodyDataFile.decode` leaves entries to `refusal`.
            case .invalidEntry: throw .invalidEntry(.bodyEntry)
            }
        }
    }
}

extension HeartRateTrace {
    /// Whether it covers `night`'s Time in Bed in 5-minute steps, as a Night's trace is built
    /// (spec 012): starting at Time in Bed's start, with Time in Bed ÷ 5 minutes steps rounded up.
    fileprivate func fits(_ night: Night) -> Bool {
        guard let start = night.timeInBedStart, let end = night.timeInBedEnd else { return false }
        let count = max(Int((end.timeIntervalSince(start) / Self.step).rounded(.up)), 0)
        return self.start == start && steps.count == count
    }
}
