import Combine
import Foundation
import SerenixCore

/// The automatic Backup (spec 020): keeps `Serenix Backup.json` up to date in a folder the user
/// picked, which survives deleting the app. `AutomaticBackup` decides when to write and what
/// turning it on does; this keeps the folder's bookmark, reads and writes the file, and remembers
/// the last outcome. A failed write is shown, never thrown at a sync or a Body save.
@MainActor
final class AutomaticBackupWriter: ObservableObject {
    /// Whether a folder is chosen and the Backup is written to it.
    @Published private(set) var isOn: Bool
    /// The last write's outcome, kept across launches; nil before any.
    @Published private(set) var lastOutcome: BackupOutcome?
    /// The line under the toggle: "Last backup: …" or "Backup failed: …".
    var status: String? { AutomaticBackup.status(after: lastOutcome, in: .current) }

    private var connection: StrapConnection?
    private var bodyStore: BodyStore?
    private var foodStore: FoodStore?
    /// The bookmark of a folder picked while its existing Backup is offered for import or
    /// replacing; it becomes the Backup's folder only once the user goes ahead.
    private var pendingFolder: Data?
    /// The write under way, so writes run one at a time, in order.
    private var writing: Task<Void, Never>?

    init() {
        let defaults = UserDefaults.standard
        isOn = defaults.data(forKey: folderBookmarkKey) != nil
        lastOutcome = Self.storedOutcome(in: defaults)
    }

    /// Gives it the stores a Backup is read from.
    func attach(connection: StrapConnection, bodyStore: BodyStore, foodStore: FoodStore) {
        self.connection = connection
        self.bodyStore = bodyStore
        self.foodStore = foodStore
    }

    /// Everything a Backup holds, as stored now; the Nights and Days are read off the main
    /// thread.
    func currentBackup() async throws -> Backup {
        guard let connection, let bodyStore, let foodStore else {
            throw OnDeviceStoreError("Serenix's data isn't open yet.")
        }
        let stored = try await connection.storedNightsAndDays()
        let body = try bodyStore.allData()
        let food = try foodStore.storedFoodData()
        return Backup(
            nights: stored.nights,
            days: stored.days,
            body: BodyData(
                weighIns: body.weighIns,
                goals: body.goals,
                foodEntries: food.entries,
                completeDays: food.completeDays,
                foodTargets: food.targets
            )
        )
    }

    /// Writes the Backup when it's on and `event` calls for it.
    func handle(_ event: AutomaticBackupEvent) {
        guard isOn, AutomaticBackup.isWriteDue(after: event) else { return }
        write()
    }

    /// Starts turning it on with the `folder` the user picked, and says what to do: write now
    /// (done here), or offer the Backup already there for import, or only for replacing. The
    /// existing file is read through a file coordinator, so one in iCloud that isn't on the
    /// phone yet is downloaded rather than taken for none.
    func choose(_ folder: URL) async throws -> TurningOn {
        let bookmark = try Self.bookmark(for: folder)
        let found = try await Task.detached(priority: .userInitiated) {
            try Self.backup(in: folder)
        }.value
        pendingFolder = bookmark
        let decision = AutomaticBackup.onTurningOn(found: found)
        if decision == .write { confirmTurningOn() }
        return decision
    }

    /// Makes the picked folder the Backup's and writes to it: after the user imported the Backup
    /// found there, or chose to replace it.
    func confirmTurningOn() {
        guard let pendingFolder else { return }
        UserDefaults.standard.set(pendingFolder, forKey: folderBookmarkKey)
        self.pendingFolder = nil
        isOn = true
        handle(.turnedOn)
    }

    /// Leaves it off and the folder's file untouched.
    func cancelTurningOn() {
        pendingFolder = nil
    }

    /// Stops writing; the file stays where it is.
    func turnOff() {
        UserDefaults.standard.removeObject(forKey: folderBookmarkKey)
        pendingFolder = nil
        isOn = false
    }

    /// Queues a write after any under way.
    private func write() {
        let previous = writing
        writing = Task {
            await previous?.value
            await self.writeNow()
        }
    }

    private func writeNow() async {
        // A write queued before it was turned off has no folder to go to, and isn't a failure.
        guard isOn else { return }
        do {
            let folder = try resolvedFolder()
            let file = try BackupFile.encode(try await currentBackup())
            try await Task.detached(priority: .utility) {
                try Self.write(file, in: folder)
            }.value
            record(.wrote(at: Date()))
        } catch {
            record(.failed(at: Date(), reason: error.localizedDescription))
        }
    }

    /// The chosen folder, its bookmark renewed if iOS says it's stale.
    private func resolvedFolder() throws -> URL {
        guard let bookmark = UserDefaults.standard.data(forKey: folderBookmarkKey) else {
            throw OnDeviceStoreError("No folder is chosen for the Backup.")
        }
        var isStale = false
        let folder = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale)
        if isStale, let renewed = try? Self.bookmark(for: folder) {
            UserDefaults.standard.set(renewed, forKey: folderBookmarkKey)
        }
        return folder
    }

    private func record(_ outcome: BackupOutcome) {
        lastOutcome = outcome
        let defaults = UserDefaults.standard
        switch outcome {
        case .wrote(let time):
            defaults.set(time, forKey: lastOutcomeTimeKey)
            defaults.removeObject(forKey: lastFailureKey)
        case .failed(let time, let reason):
            defaults.set(time, forKey: lastOutcomeTimeKey)
            defaults.set(reason, forKey: lastFailureKey)
        }
    }

    private static func storedOutcome(in defaults: UserDefaults) -> BackupOutcome? {
        guard let time = defaults.object(forKey: lastOutcomeTimeKey) as? Date else { return nil }
        if let reason = defaults.string(forKey: lastFailureKey) {
            return .failed(at: time, reason: reason)
        }
        return .wrote(at: time)
    }

    /// A bookmark to `folder` that keeps Serenix's access to it across launches.
    nonisolated private static func bookmark(for folder: URL) throws -> Data {
        let opened = folder.startAccessingSecurityScopedResource()
        defer { if opened { folder.stopAccessingSecurityScopedResource() } }
        return try folder.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    /// What `folder` holds under the Backup's name. A file that can't be read, or that holds an
    /// entry Serenix would refuse, can only be replaced (spec 020). A Backup in iCloud that isn't
    /// on the phone yet is never taken for none: its download starts and this throws, so the user
    /// tries again rather than writing over it.
    nonisolated private static func backup(in folder: URL) throws -> FoundBackup {
        let opened = folder.startAccessingSecurityScopedResource()
        defer { if opened { folder.stopAccessingSecurityScopedResource() } }
        let file = folder.appendingPathComponent(backupFileName)
        let files = FileManager.default
        // Older iCloud Drive layouts keep a hidden placeholder in place of a file not downloaded.
        let placeholder = folder.appendingPathComponent(".\(backupFileName).icloud")
        if files.fileExists(atPath: placeholder.path) {
            try? files.startDownloadingUbiquitousItem(at: file)
            throw OnDeviceStoreError(
                "The Backup in this folder is still downloading from iCloud. Try again in a moment."
            )
        }
        // A file that isn't there is none; one that is (even not yet downloaded, which the
        // coordinated read below downloads) is read.
        guard files.fileExists(atPath: file.path) else { return .noBackup }
        var coordinationError: NSError?
        var found = FoundBackup.noBackup
        NSFileCoordinator().coordinate(
            readingItemAt: file,
            options: [],
            error: &coordinationError
        ) { url in
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            do {
                let backup = try BackupFile.decode(try Data(contentsOf: url))
                if let refusal = BackupFile.refusal(backup, now: Date()) {
                    found = .unreadable(refusal)
                } else {
                    found = .readable(backup)
                }
            } catch let error as BackupFileError {
                found = .unreadable(error)
            } catch {
                found = .unreadable(.unreadable)
            }
        }
        // The file is there, so one that couldn't even be read is never taken for none.
        if coordinationError != nil, case .noBackup = found { return .unreadable(.unreadable) }
        return found
    }

    /// Writes `file` as the folder's Backup: to a temporary file first, then swapped in, so an
    /// interrupted write leaves the previous Backup whole.
    nonisolated private static func write(_ file: Data, in folder: URL) throws {
        let opened = folder.startAccessingSecurityScopedResource()
        defer { if opened { folder.stopAccessingSecurityScopedResource() } }
        let target = folder.appendingPathComponent(backupFileName)
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(
            writingItemAt: target,
            options: .forReplacing,
            error: &coordinationError
        ) { url in
            do {
                try file.write(to: url, options: .atomic)
            } catch {
                writeError = error
            }
        }
        if let error = coordinationError ?? writeError { throw error }
    }
}

/// The Backup's file name in the chosen folder (spec 020).
private let backupFileName = "Serenix Backup.json"
private let folderBookmarkKey = "automaticBackupFolder"
private let lastOutcomeTimeKey = "automaticBackupLastOutcomeTime"
private let lastFailureKey = "automaticBackupLastFailure"
