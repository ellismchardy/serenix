import Foundation

/// What happened that might call for an automatic Backup write (spec 020, When it writes).
public enum AutomaticBackupEvent: Sendable {
    /// The user turned the automatic Backup on.
    case turnedOn
    /// A rebuild pass (after a sync, at launch, or after a Profile change), with the stored
    /// Nights and Days read before and after it, each oldest first as the stores return them, so
    /// the same Nights and Days always compare equal.
    case rebuildPass(
        nightsBefore: [Night],
        nightsAfter: [Night],
        daysBefore: [DayLoad],
        daysAfter: [DayLoad]
    )
    /// A Weigh-in, Weight Goal, Food Entry, Complete Day or food target was saved, edited or
    /// deleted.
    case bodyChanged
}

/// What the chosen folder already holds when the automatic Backup is turned on.
public enum FoundBackup: Sendable {
    case noBackup
    case readable(Backup)
    case unreadable(BackupFileError)
}

/// What turning the automatic Backup on does (spec 020, A folder that already holds a Backup).
public enum TurningOn: Equatable, Sendable {
    /// Nothing to lose in the folder: write the Backup now.
    case write
    /// Offer to import the Backup already there; write only after the user imports or chooses
    /// to replace it.
    case offerImport(Backup)
    /// The file there can't be read: offer only to replace it, or cancel.
    case offerReplace(BackupFileError)
}

/// The last automatic Backup write's outcome.
public enum BackupOutcome: Equatable, Sendable {
    case wrote(at: Date)
    case failed(at: Date, reason: String)
}

/// The automatic Backup's decisions (spec 020, Automatic Backup); the shell only writes the file
/// and remembers the outcome.
public enum AutomaticBackup {
    /// Whether `event` calls for a write: turning it on, any Body change, and a rebuild pass that
    /// added, changed or removed a Night or Day. A pass that changed nothing writes nothing.
    public static func isWriteDue(after event: AutomaticBackupEvent) -> Bool {
        switch event {
        case .turnedOn, .bodyChanged: true
        case .rebuildPass(let nightsBefore, let nightsAfter, let daysBefore, let daysAfter):
            nightsBefore != nightsAfter || daysBefore != daysAfter
        }
    }

    /// What turning it on does, given what the folder holds: a Backup already there is never
    /// overwritten unasked.
    public static func onTurningOn(found: FoundBackup) -> TurningOn {
        switch found {
        case .noBackup: .write
        case .readable(let backup): .offerImport(backup)
        case .unreadable(let error): .offerReplace(error)
        }
    }

    /// The line under the toggle, with times in `timeZone`; nil before any write.
    public static func status(after last: BackupOutcome?, in timeZone: TimeZone) -> String? {
        switch last {
        case nil: nil
        case .wrote(let time):
            "Last backup: \(Day(containing: time, in: timeZone).text) at "
                + clockText(time, in: timeZone)
        case .failed(_, let reason): "Backup failed: \(reason)"
        }
    }
}
