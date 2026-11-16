import SerenixCore
import SwiftUI
import UniformTypeIdentifiers

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
    /// The Body data the Export and Import rows back up (spec 015).
    @EnvironmentObject private var bodyStore: BodyStore
    /// The food data the backup carries too (spec 016).
    @EnvironmentObject private var foodStore: FoodStore
    @AppStorage(TodayLayout.storageKey) private var todayLayout = TodayLayout.rings
    @Environment(\.dismiss) private var dismiss
    @State private var editsName = false
    @State private var draftName = ""
    @State private var picksImportFile = false
    /// All Body data for Export, read when the menu opens and after an import, not per redraw.
    @State private var backup: Result<BodyData, Error>?
    /// What a picked file would import, while its confirmation shows.
    @State private var pendingImport: BodyImport?
    /// Why a picked file can't be imported, while that shows.
    @State private var importRefusal: String?

    var body: some View {
        NavigationStack {
            // Split in three so the type-checker can handle the body in reasonable time.
            backupHandling(menuList)
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

    /// The menu's rows: the Profile, the Strap, Appearance, Today layout, Body data and Debug.
    private var menuList: some View {
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
                Picker("Height", selection: $profile.heightCentimetres) {
                    Text("Not set").tag(Double?.none)
                    ForEach(Height.options(units: profile.units), id: \.self) { centimetres in
                        Text(Height.text(centimetres: centimetres, units: profile.units)).tag(
                            Double?.some(centimetres)
                        )
                    }
                }
                Picker("Units", selection: $profile.units) {
                    ForEach(WeightUnits.allCases, id: \.self) { Text($0.label).tag($0) }
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
            // Spec 013: Rings or Story, applied to the Today screen at once.
            Section("Today layout") {
                Picker("Today layout", selection: $todayLayout) {
                    ForEach(TodayLayout.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Theme.card)
            // Spec 015, Backup and import: all Body data as one JSON file, and back.
            Section("Body data") {
                switch backup {
                case .success(let data)?:
                    ShareLink(
                        item: BodyBackup(data: data),
                        preview: SharePreview("Serenix Body data")
                    ) {
                        Label("Export Body data", systemImage: "square.and.arrow.up")
                    }
                case .failure(let error)?:
                    // Shown in place of the row, so a read failure is never hidden.
                    Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                case nil:
                    EmptyView()
                }
                Button {
                    picksImportFile = true
                } label: {
                    Label("Import Body data", systemImage: "square.and.arrow.down")
                }
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
    }

    /// The backup's file picker and the import question, refusal and failure alerts (specs
    /// 015, 016), on `content`.
    private func backupHandling(_ content: some View) -> some View {
        content
            .onAppear { readBackup() }
            .fileImporter(isPresented: $picksImportFile, allowedContentTypes: [.json]) {
                readImport($0)
            }
            .alert(
                "Import Body data?",
                isPresented: Binding(
                    get: { pendingImport != nil },
                    set: { if !$0 { pendingImport = nil } }
                ),
                presenting: pendingImport
            ) { found in
                Button("Import") {
                    // Two store files, so two saves: food first, and Weigh-ins and goals only
                    // if that saved, so a failed food save imports nothing. Food then saved but
                    // the second save failed can be retried: what's here is skipped.
                    if foodStore.add(found) { bodyStore.add(found) }
                    readBackup()
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text(importQuestion)
            }
            .alert(
                "Nothing was imported",
                isPresented: Binding(
                    get: { importRefusal != nil },
                    set: { if !$0 { importRefusal = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importRefusal ?? "")
            }
            .alert(
                "Body data",
                isPresented: Binding(
                    get: { bodyStore.failure != nil },
                    set: { if !$0 { bodyStore.failure = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(bodyStore.failure ?? "")
            }
            .alert(
                "Food data",
                isPresented: Binding(
                    get: { foodStore.failure != nil },
                    set: { if !$0 { foodStore.failure = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(foodStore.failure ?? "")
            }
    }

    /// "Add N Weigh-ins and M Weight Goals? K already here will be skipped." (spec 015).
    private var importQuestion: String {
        guard let found = pendingImport else { return "" }
        let targets = found.foodTargetsToSet == nil ? "" : ", and your Calorie Target and macros"
        return "Add \(found.weighInsToAdd.count) Weigh-ins, \(found.goalsToAdd.count) Weight "
            + "Goals, \(found.foodEntriesToAdd.count) Food Entries and "
            + "\(found.completeDaysToAdd.count) Complete Days\(targets)? "
            + "\(found.skipped) already here or not needed will be skipped."
    }

    private func readBackup() {
        backup = Result { try allData() }
    }

    /// All Body data from both store files: Weigh-ins and Weight Goals, and food.
    private func allData() throws -> BodyData {
        let body = try bodyStore.allData()
        let food = try foodStore.storedFoodData()
        return BodyData(
            weighIns: body.weighIns,
            goals: body.goals,
            foodEntries: food.entries,
            completeDays: food.completeDays,
            foodTargets: food.targets
        )
    }

    /// Reads the picked file and asks before importing; a file that can't be read imports
    /// nothing and says why.
    private func readImport(_ picked: Result<URL, Error>) {
        do {
            let url = try picked.get()
            let opened = url.startAccessingSecurityScopedResource()
            defer { if opened { url.stopAccessingSecurityScopedResource() } }
            let file = try BodyDataFile.decode(try Data(contentsOf: url))
            if let refusal = BodyDataFile.refusal(file, now: Date()) { throw refusal }
            let current = try allData()
            pendingImport = BodyDataFile.importing(
                file,
                into: current,
                now: Date(),
                timeZone: .current
            )
        } catch let error as BodyDataFileError {
            importRefusal = error.message
        } catch {
            importRefusal = "The file couldn't be opened: \(error.localizedDescription)"
        }
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

extension WeightUnits {
    /// The Units picker's names.
    fileprivate var label: String {
        switch self {
        case .kilograms: "kg"
        case .pounds: "lb"
        case .stonesAndPounds: "st and lb"
        }
    }
}
