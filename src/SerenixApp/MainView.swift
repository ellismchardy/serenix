import SerenixCore
import SwiftUI

/// Connect Strap and Sync now, with the sync status and when the last sync completed.
struct MainView: View {
    @ObservedObject var connection: StrapConnection

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text(connection.phase.displayText)
                        .multilineTextAlignment(.center)
                    if connection.phase == .syncing {
                        SyncProgressView(
                            progress: connection.syncProgress,
                            timeLeft: connection.syncTimeLeft
                        )
                    }
                    Text(lastSyncText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button("Connect Strap") { connection.connect() }
                    .buttonStyle(.bordered)
                    .disabled(connection.phase.isBusy)
                Button("Sync now") { connection.syncNow() }
                    .buttonStyle(.borderedProminent)
                    .disabled(connection.phase.isBusy)
                if connection.phase.isBusy {
                    Button("Cancel", role: .cancel) { connection.cancel() }
                }
                NavigationLink("Debug") { DebugView(connection: connection) }
                Spacer()
                Text("Serenix \(BuildInfo.version)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Serenix")
        }
    }

    private var lastSyncText: String {
        guard let completed = connection.lastSyncCompleted else { return "Never synced" }
        let when = completed.formatted(date: .abbreviated, time: .shortened)
        return "Last sync \(when) · \(connection.lastSyncRecordCount) History Records received"
    }
}

/// A running sync's progress bar and time left (spec 001, Sync progress): "Starting…" until the
/// session reports progress.
private struct SyncProgressView: View {
    let progress: Double?
    let timeLeft: TimeInterval?

    var body: some View {
        if let progress {
            VStack(spacing: 4) {
                ProgressView(value: progress)
                if let timeLeft {
                    Text(HistorySync.timeLeftText(timeLeft))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
        } else {
            Text("Starting…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
