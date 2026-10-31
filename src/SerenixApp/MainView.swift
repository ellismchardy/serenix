import SerenixCore
import SwiftUI

/// Connect Strap and Sync now, with the sync status. The tracer screen of plan 001, task 4.
struct MainView: View {
    @ObservedObject var connection: StrapConnection

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(connection.phase.displayText)
                    .multilineTextAlignment(.center)
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
}
