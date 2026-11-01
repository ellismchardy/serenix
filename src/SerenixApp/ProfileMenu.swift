import SerenixCore
import SwiftUI

/// The profile menu (spec 002), opened from the Today screen's avatar: the Profile's avatar and
/// name, which can be edited, with its birth year, sex and Max HR (spec 005); the Strap's
/// connection and model, battery and last sync, with Sync now; the Appearance; Debug; and a footer
/// with the version, licence and disclaimer. Rounded, grouped rows on the Look's background,
/// closed with an ✕.
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
                Section {
                    Picker("Birth year", selection: $profile.birthYear) {
                        Text("Not set").tag(Int?.none)
                        ForEach(birthYearOptions, id: \.self) { year in
                            Text(String(year)).tag(Int?.some(year))
                        }
                    }
                    Picker(selection: $profile.sex) {
                        ForEach(Sex.allCases, id: \.self) { Text($0.label).tag($0) }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sex")
                            Text("Used only for heart-rate calculations")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Picker("Max HR", selection: $profile.maxHR) {
                        Text(maxHRBlankText).tag(Int?.none)
                        ForEach(Profile.allowedMaxHR, id: \.self) { bpm in
                            Text("\(bpm) bpm").tag(Int?.some(bpm))
                        }
                    }
                }
                .pickerStyle(.navigationLink)
                .listRowBackground(Theme.card)
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
                    HStack(spacing: 10) {
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
                        Spacer(minLength: 0)
                        // 001's time left and progress, once the running sync reports progress.
                        if showsSyncProgress, let progress = connection.syncProgress {
                            SyncProgressView(progress: progress, timeLeft: connection.syncTimeLeft)
                        }
                    }
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
                        DebugView(connection: connection)
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

    private var currentYear: Int {
        Calendar(identifier: .gregorian).component(.year, from: Date())
    }

    /// The birth years the picker offers this year, newest first: 100 to 13 years ago (spec 005,
    /// Profile), plus a stored one that has since fallen outside, so it still shows.
    private var birthYearOptions: [Int] {
        var years = Array(Profile.allowedBirthYears(in: currentYear))
        if let stored = profile.birthYear, !years.contains(stored) { years.append(stored) }
        return years.sorted(by: >)
    }

    /// A blank Max HR: the estimate from age for this year, e.g. "Estimated 180 from your age",
    /// or "Not set" with no birth year.
    private var maxHRBlankText: String {
        let estimate = Profile(name: nil, birthYear: profile.birthYear)
            .estimatedMaxHR(in: currentYear)
        return estimate.map { "Estimated \(Int($0.rounded())) from your age" } ?? "Not set"
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

/// A running sync's time left, then its progress as a small circle filling clockwise (spec 001,
/// Sync progress; spec 002, Profile menu).
private struct SyncProgressView: View {
    let progress: Double
    let timeLeft: TimeInterval?

    var body: some View {
        HStack(spacing: 8) {
            if let timeLeft {
                Text(HistorySync.timeLeftText(timeLeft))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            ZStack {
                Circle().stroke(Theme.accentSoft, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 22, height: 22)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(Int((progress * 100).rounded())) percent synced")
    }
}

extension Sex {
    /// How the profile menu shows it (spec 005, Profile).
    fileprivate var label: String {
        switch self {
        case .female: "Female"
        case .male: "Male"
        case .preferNotToSay: "Prefer not to say"
        }
    }
}
