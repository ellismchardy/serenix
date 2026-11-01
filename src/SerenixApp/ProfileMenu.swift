import SerenixCore
import SwiftUI

/// The profile menu (spec 002), opened from the Today screen's avatar: the Profile's avatar and
/// name, which can be edited; the Strap's connection and model, battery and last sync, with Sync
/// now; the Appearance; Debug; and a footer with the version, licence and disclaimer. Rounded,
/// grouped rows on the Look's background, closed with an ✕.
struct ProfileMenu: View {
    @ObservedObject var connection: StrapConnection
    @ObservedObject var profile: ProfileStore
    /// The Today view's avatar letter and menu header name.
    let avatarLetter: String?
    let menuName: String
    /// The Today view's say on whether Sync now reads Retry sync.
    let syncOffersRetry: Bool
    /// The Today view's say on whether a sync is running, so 001's progress shows here.
    let showsSyncProgress: Bool
    @Binding var showsSampleNights: Bool
    @EnvironmentObject private var appearanceStore: AppearanceStore
    @Environment(\.dismiss) private var dismiss
    @State private var editsName = false
    @State private var draftName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        draftName = profile.name ?? ""
                        editsName = true
                    } label: {
                        VStack(spacing: 12) {
                            Avatar(letter: avatarLetter, diameter: 96)
                            Text(menuName).font(.title2.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Edit your name")
                }
                .listRowBackground(Color.clear)
                Section("Strap") {
                    LabeledContent {
                        Text(connection.strapModel ?? "—")
                    } label: {
                        Label(connectionText, systemImage: "applewatch")
                    }
                    LabeledContent {
                        Text(connection.lastBatteryLevel.map { "\($0)%" } ?? "—")
                    } label: {
                        Label("Battery", systemImage: "battery.75percent")
                    }
                    LabeledContent {
                        Text(lastSyncText)
                    } label: {
                        Label("Last sync", systemImage: "clock")
                    }
                    // 001's progress bar and time left, once the running sync reports progress.
                    if showsSyncProgress, let progress = connection.syncProgress {
                        SyncProgressView(progress: progress, timeLeft: connection.syncTimeLeft)
                    }
                    // 001's Sync now; after a failed or paused sync it's a retry.
                    Button {
                        connection.syncNow()
                    } label: {
                        Label(
                            syncOffersRetry ? "Retry sync" : "Sync now",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                    }
                    .disabled(connection.phase.isBusy)
                }
                .listRowBackground(Theme.card)
                Section("Appearance") {
                    Picker("Appearance", selection: $appearanceStore.selected) {
                        ForEach(Appearance.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Theme.card)
                Section {
                    NavigationLink {
                        DebugView(connection: connection, showsSampleNights: $showsSampleNights)
                    } label: {
                        Label("Debug", systemImage: "ladybug")
                    }
                } footer: {
                    // Later specs add Integrations, Export data, Contact us, Report a bug and
                    // Write a review above.
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Serenix \(BuildInfo.version)")
                        Text("MIT licensed")
                        Text("Not affiliated with WHOOP, Inc.")
                    }
                    .padding(.top, 8)
                }
                .listRowBackground(Theme.card)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
            .alert("Your name", isPresented: $editsName) {
                TextField("Your name", text: $draftName)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                Button("Save") { profile.rename(to: draftName) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("It stays on this phone.")
            }
        }
        .presentationDragIndicator(.visible)
    }

    /// "Connected" once a Strap is paired with Serenix, else "Not found" (spec 002). Each sync
    /// connects to it, so this doesn't track the Bluetooth link between syncs.
    private var connectionText: String {
        connection.hasPairedStrap ? "Connected" : "Not found"
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

/// A running sync's progress bar and time left (spec 001, Sync progress).
private struct SyncProgressView: View {
    let progress: Double
    let timeLeft: TimeInterval?

    var body: some View {
        VStack(spacing: 4) {
            ProgressView(value: progress)
            if let timeLeft {
                Text(HistorySync.timeLeftText(timeLeft))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
