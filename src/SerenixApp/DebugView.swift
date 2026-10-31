import SerenixCore
import SwiftUI

/// What the last History Sync did: its state, the History Records received and its Sync Log.
/// The bare version of plan 001, task 4; task 9 adds the rest.
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
                LabeledContent("Sync Log entries", value: "\(connection.syncLog.count)")
            }
            Section("Sync Log") {
                ForEach(Array(connection.syncLog.enumerated()), id: \.offset) { _, entry in
                    SyncLogRow(entry: entry)
                }
            }
        }
        .navigationTitle("Debug")
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
        let hex: String = entry.bytes.map { String(format: "%02x", $0) }.joined()
        VStack(alignment: .leading, spacing: 2) {
            Text(direction + "  " + time)
                .font(.caption)
            Text(hex)
                .font(.system(.caption2, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}
