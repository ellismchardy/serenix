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
