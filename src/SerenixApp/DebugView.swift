import SerenixCore
import SwiftUI
import UniformTypeIdentifiers

/// What Serenix knows about the Strap, its stored History Records and the last syncs, with the
/// newest Sync Log entries and Share log (spec 001, debug screen).
struct DebugView: View {
    @ObservedObject var connection: StrapConnection

    var body: some View {
        List {
            Section("Sync") {
                LabeledContent("State", value: connection.phase.displayText)
                LabeledContent(
                    "History Records received",
                    value: "\(connection.historyRecordsReceived)"
                )
                LabeledContent("Sync Log entries", value: "\(connection.syncLog.count)")
                ShareLink(
                    item: SyncLogFile(
                        archive: try? connection.logArchive.get(),
                        running: sharedRunningLog
                    ),
                    preview: SharePreview("Serenix Sync Log")
                ) {
                    Label("Share log (last 5 syncs)", systemImage: "square.and.arrow.up")
                }
            }
            Section("Strap") {
                LabeledContent("Name", value: connection.strapName ?? "–")
                LabeledContent("Model", value: connection.strapModel ?? "–")
                LabeledContent("Firmware", value: connection.strapFirmware ?? "–")
                LabeledContent(
                    "Battery",
                    value: connection.lastBatteryLevel.map { "\($0)%" } ?? "–"
                )
                LabeledContent("Data range (0x22)", value: dataRangeText)
            }
            Section("History Records stored") {
                let stats = connection.storeStats
                LabeledContent("Count", value: "\(stats.count)")
                LabeledContent("First", value: endText(stats.oldest))
                LabeledContent("Last", value: endText(stats.newest))
                LabeledContent("Gaps in Record Counters", value: "\(stats.gapCount)")
            }
            Section("Sync Log, newest \(shownEntryCount)") {
                ForEach(shownIndices, id: \.self) { index in
                    SyncLogRow(entry: connection.syncLog[index])
                }
            }
        }
        .navigationTitle("Debug")
    }

    /// The in-memory Sync Log to add to the kept ones: a sync still under way, or, if the
    /// archive couldn't be opened, the last sync (otherwise it would be shared as nothing).
    private var sharedRunningLog: [SyncLogEntry] {
        let archiveOpen = (try? connection.logArchive.get()) != nil
        return connection.phase == .syncing || !archiveOpen ? connection.syncLog : []
    }

    private var dataRangeText: String {
        guard let range = connection.lastDataRange else { return "–" }
        return "\(timeText(range.oldest)) – \(timeText(range.newest))"
    }

    private func endText(_ end: HistoryRecordStats.End?) -> String {
        guard let end else { return "–" }
        return "#\(end.recordCounter), \(timeText(end.timestamp))"
    }

    private func timeText(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .standard)
    }

    private var shownIndices: Range<Int> {
        connection.syncLog.indices.suffix(shownEntryCount)
    }

    private var shownEntryCount: Int {
        min(connection.syncLog.count, maxShownEntries)
    }
}

/// The debug list shows only the newest entries: a day's sync is ~100,000, too many for a List
/// to redraw twice a second. Share log has them all.
private let maxShownEntries = 200

/// The last syncs' Sync Logs (and a sync still running) as one text file for the share sheet,
/// written only when the user shares it.
private struct SyncLogFile: Transferable {
    let archive: SyncLogArchive?
    let running: [SyncLogEntry]

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .plainText) { file in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("serenix-sync-log.txt")
            if let archive = file.archive {
                try archive.writeCombined(to: url, adding: file.running)
            } else {
                try Data(syncLogText(file.running).utf8).write(to: url, options: .atomic)
            }
            return SentTransferredFile(url)
        }
    }
}

/// One Sync Log entry: direction, time to the millisecond, and the bytes in hex.
private struct SyncLogRow: View {
    let entry: SyncLogEntry

    var body: some View {
        let direction: String = entry.direction == .toStrap ? "→ Strap" : "← Strap"
        let time: String = entry.time.formatted(
            .dateTime.hour().minute().second().secondFraction(.fractional(3))
        )
        let hex: String = entry.hexBytes
        VStack(alignment: .leading, spacing: 2) {
            Text(direction + "  " + time)
                .font(.caption)
            Text(hex)
                .font(.system(.caption2, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}
