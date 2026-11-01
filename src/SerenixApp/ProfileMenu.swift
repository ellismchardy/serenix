import SerenixCore
import SwiftUI

/// The profile menu (spec 002), opened from the Today screen's profile icon. It replaces 001's
/// settings screen: the Strap's model, connection, battery and last sync; Sync now and Debug; and
/// a footer with the version, licence and disclaimer.
struct ProfileMenu: View {
    @ObservedObject var connection: StrapConnection
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Strap") {
                    LabeledContent("Model", value: connection.strapModel ?? "—")
                    LabeledContent("Connection", value: connectionText)
                    LabeledContent(
                        "Battery",
                        value: connection.lastBatteryLevel.map { "\($0)%" } ?? "—"
                    )
                    LabeledContent("Last sync", value: lastSyncText)
                }
                Section {
                    // 001's Sync now; after a failed sync it's a retry.
                    Button(isFailed ? "Retry sync" : "Sync now") { connection.syncNow() }
                        .disabled(connection.phase.isBusy)
                    NavigationLink("Debug") { DebugView(connection: connection) }
                }
                Section {
                    // Later specs add Apple Health, Export data, Contact us, Report a bug and
                    // Write a review here.
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Serenix \(BuildInfo.version)")
                        Text("MIT licensed")
                        Text("Not affiliated with WHOOP, Inc.")
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// "Connected" once a Strap is paired with Serenix, else "Not found" (spec 002). Each sync
    /// connects to it, so this doesn't track the Bluetooth link between syncs.
    private var connectionText: String {
        connection.hasPairedStrap ? "Connected" : "Not found"
    }

    /// Whether the sync pill shows a failure, so the button offers a retry.
    private var isFailed: Bool {
        if case .failed = connection.syncStatus { true } else { false }
    }

    /// e.g. "Sun 1 Nov 08:10": 24-hour, whatever the phone's locale (spec 002, Formats).
    private var lastSyncText: String {
        guard let completed = connection.lastSyncCompleted else { return "Never" }
        let hour = Date.FormatStyle.Symbol.VerbatimHour.twoDigits(
            clock: .twentyFourHour,
            hourCycle: .zeroBased
        )
        let style = Date.VerbatimFormatStyle(
            format: """
                \(weekday: .abbreviated) \(day: .defaultDigits) \(month: .abbreviated) \
                \(hour: hour):\(minute: .twoDigits)
                """,
            locale: Locale(identifier: "en_GB"),
            timeZone: .current,
            calendar: Calendar(identifier: .gregorian)
        )
        return completed.formatted(style)
    }
}
