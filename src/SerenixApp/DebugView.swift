import SerenixCore
import SwiftUI
import UniformTypeIdentifiers

/// What the last History Sync did: its state, the History Records received and its Sync Log,
/// which Share log exports in full. Plan 001 task 9 adds the store stats and the last 5 syncs.
struct DebugView: View {
    @ObservedObject var connection: StrapConnection

    var body: some View {
        List {
            Section("Last sync") {
                LabeledContent("State", value: connection.phase.displayText)
                LabeledContent("Strap", value: connection.strapName ?? "–")
                LabeledContent(
                    "History Records received",
                    value: "\(connection.historyRecordsReceived)"
                )
                LabeledContent(
                    "History Records stored",
                    value: "\(connection.historyRecordsStored)"
                )
                LabeledContent("Sync Log entries", value: "\(connection.syncLog.count)")
                ShareLink(
                    item: SyncLogFile(entries: connection.syncLog),
                    preview: SharePreview("Serenix Sync Log")
                ) {
                    Label("Share log", systemImage: "square.and.arrow.up")
                }
                .disabled(connection.syncLog.isEmpty)
            }
            Section("Sync Log, newest \(shownEntryCount)") {
                ForEach(shownIndices, id: \.self) { index in
                    SyncLogRow(entry: connection.syncLog[index])
                }
            }
        }
        .navigationTitle("Debug")
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

/// The Sync Log as a text file for the share sheet, written only when the user shares it.
private struct SyncLogFile: Transferable {
    let entries: [SyncLogEntry]

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .plainText) { file in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("serenix-sync-log.txt")
            try Data(syncLogText(file.entries).utf8).write(to: url, options: .atomic)
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
