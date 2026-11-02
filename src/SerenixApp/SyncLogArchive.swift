import Foundation
import SerenixCore

/// The Sync Logs of the last `keptSyncs` syncs, as text files on the phone (spec 001). They
/// only ever leave the phone when the user shares them (ADR 0001).
struct SyncLogArchive: Sendable {
    private let directory: URL

    init() throws {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        directory = support.appendingPathComponent("SyncLogs", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Keeps one sync's Sync Log, then drops the oldest beyond `keptSyncs`.
    func save(_ entries: [SyncLogEntry], syncStartedAt start: Date) throws {
        let name = "sync-\(Int64(start.timeIntervalSince1970)).txt"
        try Data(syncLogText(entries).utf8).write(
            to: directory.appendingPathComponent(name),
            options: .atomic
        )
        for old in try logFiles().dropLast(keptSyncs) {
            try FileManager.default.removeItem(at: old)
        }
    }

    /// Keeps the Sync Log of Live HR outside a sync (spec 006), replacing the last one. It isn't
    /// one of the `keptSyncs`, so it never pushes out a sync's Sync Log.
    func saveLiveHR(_ entries: [SyncLogEntry]) throws {
        try Data(syncLogText(entries).utf8).write(
            to: directory.appendingPathComponent(liveHRFileName),
            options: .atomic
        )
    }

    /// Writes every kept sync into `url`, oldest first, each headed by a `# sync` line, then
    /// `running` (a sync still under way, not yet kept). File by file, so a few large logs are
    /// never in memory together.
    func writeCombined(to url: URL, adding running: [SyncLogEntry]) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let output = try FileHandle(forWritingTo: url)
        defer { try? output.close() }
        for file in try logFiles() {
            let name = file.deletingPathExtension().lastPathComponent
            try output.write(contentsOf: Data("# sync \(name)\n".utf8))
            try output.write(contentsOf: Data(contentsOf: file))
        }
        let liveHR = directory.appendingPathComponent(liveHRFileName)
        if FileManager.default.fileExists(atPath: liveHR.path) {
            try output.write(contentsOf: Data("# Live HR\n".utf8))
            try output.write(contentsOf: Data(contentsOf: liveHR))
        }
        if !running.isEmpty {
            try output.write(contentsOf: Data(("# sync running\n" + syncLogText(running)).utf8))
        }
    }

    /// Oldest first: names are `sync-<Unix seconds>`, all the same length for centuries.
    private func logFiles() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "txt" && $0.lastPathComponent.hasPrefix("sync-") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}

/// The one Live HR Sync Log (spec 006).
private let liveHRFileName = "livehr.txt"

/// How many syncs' Sync Logs the phone keeps (spec 001).
private let keptSyncs = 5
