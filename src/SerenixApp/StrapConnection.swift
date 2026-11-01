import CoreBluetooth
import Foundation
import SerenixCore
import os

/// Where the Strap connection and its History Sync have got to, for display.
enum StrapPhase: Equatable {
    case idle
    case bluetoothUnavailable(String)
    case searching
    case connecting
    case connected
    case syncing
    case synced
    case failed(String, SyncFailureCause)

    var isBusy: Bool {
        switch self {
        case .searching, .connecting, .syncing: true
        default: false
        }
    }

    var displayText: String {
        switch self {
        case .idle: "Not connected"
        case .bluetoothUnavailable(let reason): reason
        case .searching: "Looking for your Strap…"
        case .connecting: "Connecting…"
        case .connected: "Connected"
        case .syncing: "Syncing…"
        case .synced: "Up to date"
        case .failed(let reason, _): "Failed: \(reason)"
        }
    }
}

/// Moves bytes between the Strap and a `HistorySync` session over CoreBluetooth.
///
/// Every decision about what to send lives in `SerenixCore`: this class scans, connects,
/// subscribes, writes what the session asks for and feeds back what the Strap sends. All state
/// lives on the main actor: SwiftUI calls in there, and the central manager delivers its
/// callbacks on the main queue (`queue: nil`), which the `@preconcurrency` delegate
/// conformances check at run time.
@MainActor
final class StrapConnection: NSObject, ObservableObject {
    @Published private(set) var phase: StrapPhase = .idle
    @Published private(set) var strapName: String?
    /// The current or last sync's Sync Log; `logArchive` keeps the last few on the phone. Not
    /// `@Published`: a day's sync is ~100,000 Frames, and redrawing the screen for each one
    /// slowed the first phone sync to a crawl. `syncTimer` redraws instead.
    private(set) var syncLog: [SyncLogEntry] = []
    /// History Records received in the current or last sync.
    private(set) var historyRecordsReceived = 0
    @Published private(set) var storeStats = HistoryRecordStats()
    var historyRecordsStored: Int { storeStats.count }
    /// Every stored Night, oldest first, for the Today screen (spec 003).
    @Published private(set) var nights: [Night] = []
    /// Every stored Day Load, oldest first, for the Today screen (spec 005).
    @Published private(set) var dayLoads: [DayLoad] = []
    /// From the Strap's Device Info service, kept across launches.
    @Published private(set) var strapModel: String?
    @Published private(set) var strapFirmware: String?
    /// What the Strap last reported during a sync, kept across launches.
    @Published private(set) var lastBatteryLevel: Int?
    @Published private(set) var lastDataRange: HistoryDataRange?
    /// The last few syncs' Sync Logs, or why they can't be kept.
    let logArchive: Result<SyncLogArchive, Error>
    /// When the last sync completed and how many History Records it received, kept across
    /// launches.
    @Published private(set) var lastSyncCompleted: Date?
    @Published private(set) var lastSyncRecordCount = 0
    /// The running sync's progress (0 to 1) and seconds left, from the session; nil before
    /// they're known. `syncTimer` redraws the screen to show them.
    var syncProgress: Double? { session?.progress }
    var syncTimeLeft: TimeInterval? { session?.timeLeft(at: Date()) }
    /// The phase as the Today view's sync pill reads it (spec 002): looking for or connecting
    /// to the Strap counts as syncing, and Bluetooth being unavailable as the Strap being
    /// unreachable.
    var syncStatus: SyncStatus {
        switch phase {
        case .searching, .connecting, .syncing: .syncing
        case .synced: .justFinished
        case .idle, .connected: .idle
        // Bluetooth being off only pauses a sync that was wanted; otherwise there's nothing
        // to say (spec 002, Sync pill).
        case .bluetoothUnavailable(let reason):
            wantsSync || wantsConnection
                ? .failed(reason: reason, cause: .strapUnreachable) : .idle
        case .failed(let reason, let cause): .failed(reason: reason, cause: cause)
        }
    }

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var commandCharacteristic: CBCharacteristic?
    private var subscribed: Set<CBUUID> = []
    private var session: HistorySync?
    /// When the current sync started, to name its archived Sync Log.
    private var syncStartedAt: Date?
    /// The store, or why it couldn't be opened; a sync then fails with that reason.
    private let store: Result<HistoryRecordStore, Error>
    /// Gives up on finding or connecting to the Strap after `connectTimeout`.
    private var connectTimer: Timer?
    /// Whether Serenix has already synced on open since launch.
    private var hasOpened = false
    /// Whether a sync was running (or starting) when Serenix went to the background. Coming
    /// back then shows that sync or its result rather than starting another (spec 001).
    private var syncWasUnderwayInBackground = false
    /// Asked to connect before Bluetooth was powered on.
    private var wantsConnection = false
    /// Asked to sync before the Strap was connected and subscribed.
    private var wantsSync = false
    /// The latest store-stats refresh and Sync Log save. Each new one waits for the one before,
    /// so stats never land out of order and two saves never prune the same old Sync Log.
    private var storeStatsRefresh: Task<Void, Never>?
    private var syncLogSave: Task<Void, Never>?
    /// The latest Night and Day Load rebuild. Each new one waits for the one before, so two
    /// never replace the same Nights or Loads at once.
    private var nightsRebuild: Task<Void, Never>?
    /// The queued rebuilds being worked out right now, if any.
    private var rebuildInProgress: NightRebuild?
    private var dayRebuildInProgress: DayRebuild?
    /// When each History Record inserted since the last save was taken. Just before the save,
    /// the dates they touch are queued to be worked out again (`NightStore.pendingRebuilds`).
    private var unsavedRecordTimes: [Date] = []
    /// Fires every `syncTimerInterval` while a sync runs: redraws the screen and checks whether
    /// the Strap went silent.
    private var syncTimer: Timer?

    override init() {
        store = Result { try HistoryRecordStore() }
        logArchive = Result { try SyncLogArchive() }
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
        let defaults = UserDefaults.standard
        lastSyncCompleted = defaults.object(forKey: lastSyncCompletedKey) as? Date
        lastSyncRecordCount = defaults.integer(forKey: lastSyncRecordCountKey)
        strapModel = defaults.string(forKey: strapModelKey)
        strapFirmware = defaults.string(forKey: strapFirmwareKey)
        lastBatteryLevel = defaults.object(forKey: batteryLevelKey) as? Int
        if let oldest = defaults.object(forKey: dataRangeOldestKey) as? Date,
            let newest = defaults.object(forKey: dataRangeNewestKey) as? Date
        {
            lastDataRange = HistoryDataRange(oldest: oldest, newest: newest)
        }
        refreshStoreStats()
        ReopenProbe.log(
            "launch: queued Nights \(NightStore.pendingRebuilds.count), Days \(DayLoadStore.pendingRebuilds.count)"
        )  // [DEBUG-n7r4]
        rebuildNights()
    }

    /// Syncs when Serenix launches or comes back from the background, once a Strap has been
    /// connected (before that, pulling down or Sync now in the profile menu starts one). Not on
    /// returning from Control Center or a notification, which is the app staying open (spec 001
    /// non-goals).
    func sceneBecameActive(fromBackground: Bool) {
        ReopenProbe.log("active, fromBackground \(fromBackground), phase \(phase)")  // [DEBUG-n7r4]
        // A sync that went silent while Serenix was in the background shows as failed now.
        failIfStrapWentSilent(at: Date())
        let syncWasUnderway = syncWasUnderwayInBackground
        syncWasUnderwayInBackground = false
        guard !syncWasUnderway else { return }
        guard fromBackground || !hasOpened else { return }
        hasOpened = true
        guard rememberedStrap != nil else { return }
        syncNow()
    }

    /// Notes whether a sync is underway as Serenix goes to the background, where it carries on
    /// (ADR 0006).
    func sceneWentToBackground() {
        ReopenProbe.log("background, phase \(phase)")  // [DEBUG-n7r4]
        syncWasUnderwayInBackground = phase.isBusy
    }

    func connect() {
        guard !phase.isBusy, !isReady else { return }
        guard central.state == .poweredOn else {
            // `centralManagerDidUpdateState` carries on once Bluetooth is on.
            wantsConnection = true
            return
        }
        startConnecting()
    }

    func syncNow() {
        guard phase != .syncing else { return }
        if isReady {
            startSync()
        } else {
            wantsSync = true
            connect()
        }
    }

    /// Works out Load again for every Day whose History Records may still be on the phone, after
    /// the birth year, sex or Max HR changed (spec 005, Profile changes). Older Days keep theirs.
    func redoLoadAfterProfileChange() {
        queueDayRebuilds(dayRebuildsDue(now: Date(), in: .current))
        rebuildNights()
    }

    /// Stops looking for, connecting to or syncing with the Strap. CoreBluetooth never gives up
    /// on a scan or a connection by itself.
    func cancel() {
        guard phase.isBusy else { return }
        central.stopScan()
        finish(as: phase == .syncing ? .failed("Cancelled mid-sync.", .cancelled) : .idle)
    }

    private var isReady: Bool {
        peripheral?.state == .connected && commandCharacteristic != nil
            && subscribed == StrapGATT.notifyCharacteristics
    }

    /// The Strap connected before, by its Bluetooth identifier, kept across launches.
    private var rememberedStrap: UUID? {
        UserDefaults.standard.string(forKey: rememberedStrapKey).flatMap(UUID.init(uuidString:))
    }

    /// Whether a Strap has been paired with Serenix. Each sync connects to it, so the link
    /// itself only lasts while syncing.
    var hasPairedStrap: Bool { rememberedStrap != nil }

    private func startConnecting() {
        connectTimer?.invalidate()
        connectTimer = Timer.scheduledTimer(withTimeInterval: connectTimeout, repeats: false) {
            [weak self] _ in
            // Scheduled on the main run loop, so it fires on the main actor.
            MainActor.assumeIsolated { self?.connectTimedOut() }
        }
        if let peripheral {
            phase = .connecting
            central.connect(peripheral)
            return
        }
        // Reconnect to the remembered Strap without scanning: iOS still has its pairing.
        if let rememberedStrap,
            let known = central.retrievePeripherals(withIdentifiers: [rememberedStrap]).first
        {
            use(known)
            return
        }
        // A Strap that's still linked to the iPhone doesn't advertise, so look there first.
        if let linked = central.retrieveConnectedPeripherals(withServices: [StrapGATT.service])
            .first
        {
            use(linked)
            return
        }
        phase = .searching
        central.scanForPeripherals(withServices: nil)
    }

    private func connectTimedOut() {
        guard phase == .searching || phase == .connecting else { return }
        central.stopScan()
        fail(
            "Couldn't find the Strap. Check it's nearby and charged, then try again.",
            .strapUnreachable
        )
    }

    /// Reads the store stats off the main thread (a month is ~2.6 million History Records),
    /// then shows them.
    private func refreshStoreStats() {
        guard case .success(let store) = self.store else { return }
        let container = store.container
        let previous = storeStatsRefresh
        storeStatsRefresh = Task.detached(priority: .utility) { [self] in
            await previous?.value
            do {
                let stats = try HistoryRecordStore.stats(in: container)
                await MainActor.run { self.storeStats = stats }
            } catch {
                storeLog.error(
                    "Couldn't read stored History Records: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    /// Queues the dates and Days that History Records about to be saved at `recordTimes` touch,
    /// so their Nights and Loads are worked out again even if iOS ends Serenix before the sync
    /// does (spec 003, When; spec 005, When).
    private func queueNightRebuilds(after recordTimes: [Date]) {
        let now = Date()
        var pending = NightStore.pendingRebuilds
        let countBefore = pending.count  // [DEBUG-n7r4]
        for rebuild in nightRebuilds(after: recordTimes, now: now, in: .current) {
            // A date being worked out right now may be reading History Records from before this
            // save, so it's queued once more to be worked out again afterwards.
            let copiesWanted = rebuild == rebuildInProgress ? 2 : 1
            if pending.filter({ $0 == rebuild }).count < copiesWanted { pending.append(rebuild) }
        }
        NightStore.pendingRebuilds = pending
        if pending.count != countBefore {
            // [DEBUG-n7r4]
            ReopenProbe.log("sync queued Nights: \(countBefore) -> \(pending.count)")
        }
        queueDayRebuilds(dayRebuilds(after: recordTimes, now: now, in: .current))
    }

    /// Queues `added`, as `queueNightRebuilds(after:)` queues dates.
    private func queueDayRebuilds(_ added: [DayRebuild]) {
        var pending = DayLoadStore.pendingRebuilds
        for rebuild in added {
            let copiesWanted = rebuild == dayRebuildInProgress ? 2 : 1
            if pending.filter({ $0 == rebuild }).count < copiesWanted { pending.append(rebuild) }
        }
        DayLoadStore.pendingRebuilds = pending
    }

    /// Takes away one queued copy of `rebuild`, leaving any copy queued while it was worked out.
    private static func removeOnePending(_ rebuild: NightRebuild) {
        var pending = NightStore.pendingRebuilds
        if let index = pending.firstIndex(of: rebuild) { pending.remove(at: index) }
        NightStore.pendingRebuilds = pending
    }

    /// Takes away one queued copy of `rebuild`, as for a Night rebuild.
    private static func removeOnePending(_ rebuild: DayRebuild) {
        var pending = DayLoadStore.pendingRebuilds
        if let index = pending.firstIndex(of: rebuild) { pending.remove(at: index) }
        DayLoadStore.pendingRebuilds = pending
    }

    /// Works out, off the main thread and one date at a time, every queued Night rebuild still
    /// due, then every queued Day rebuild still due (so a Day's Load sees that morning's Night),
    /// then shows every stored Night and Day Load. A rebuild that fails goes to the back of its
    /// queue, to be tried after the next sync or launch; it never stops what's stored from
    /// showing.
    private func rebuildNights() {
        guard case .success(let store) = self.store else { return }
        let container = store.container
        let timeZone = TimeZone.current
        let previous = nightsRebuild
        nightsRebuild = Task.detached(priority: .utility) { [self] in
            await previous?.value
            let now = Date()
            let queued = await MainActor.run { NightStore.pendingRebuilds }
            // [DEBUG-n7r4]
            await MainActor.run { ReopenProbe.log("rebuild start: \(queued.count) Nights queued") }
            for rebuild in queued {
                await MainActor.run { self.rebuildInProgress = rebuild }
                do {
                    if rebuild.isDue(at: now) {
                        let started = Date()  // [DEBUG-n7r4]
                        try NightStore.apply(rebuild, in: container, timeZone: timeZone)
                        // [DEBUG-n7r4]
                        let took = String(format: "%.1f", Date().timeIntervalSince(started))
                        await MainActor.run {
                            ReopenProbe.log("Night \(rebuild.day) worked out in \(took)s")
                        }  // [DEBUG-n7r4]
                    }
                    await MainActor.run {
                        Self.removeOnePending(rebuild)
                        self.rebuildInProgress = nil
                    }
                } catch {
                    storeLog.error(
                        "Couldn't work out a Night: \(error.localizedDescription, privacy: .public)"
                    )
                    await MainActor.run {
                        Self.removeOnePending(rebuild)
                        NightStore.pendingRebuilds.append(rebuild)
                        self.rebuildInProgress = nil
                    }
                }
            }
            let nights: [Night]?
            do {
                let stored = try NightStore.nights(in: container)
                nights = stored
                await MainActor.run { self.nights = stored }
                // [DEBUG-n7r4]
                await MainActor.run { ReopenProbe.log("Nights shown: \(stored.count)") }
            } catch {
                nights = nil
                storeLog.error(
                    "Couldn't read stored Nights: \(error.localizedDescription, privacy: .public)"
                )
            }
            // Without the stored Nights, Resting HR would be wrong, so the Days stay queued.
            var queuedDays: [DayRebuild] = []
            if nights != nil {
                queuedDays = await MainActor.run { DayLoadStore.pendingRebuilds }
            }
            for rebuild in queuedDays {
                guard let nights else { break }
                await MainActor.run { self.dayRebuildInProgress = rebuild }
                // Read per Day, after marking it in progress: a Profile change from here on queues
                // this Day once more, so it's never left worked out with the old Profile.
                let profile = ProfileStore.storedProfile
                do {
                    if rebuild.isDue(at: now) {
                        let started = Date()  // [DEBUG-n7r4]
                        defer {
                            let took = String(format: "%.1f", Date().timeIntervalSince(started))
                            Task { @MainActor in
                                ReopenProbe.log("Day \(rebuild.day) Load worked out in \(took)s")
                            }
                        }  // [DEBUG-n7r4]
                        try DayLoadStore.apply(
                            rebuild,
                            nights: nights,
                            profile: profile,
                            in: container,
                            timeZone: timeZone
                        )
                    }
                    await MainActor.run {
                        Self.removeOnePending(rebuild)
                        self.dayRebuildInProgress = nil
                    }
                } catch {
                    storeLog.error(
                        "Couldn't work out a Day's Load: \(error.localizedDescription, privacy: .public)"
                    )
                    await MainActor.run {
                        Self.removeOnePending(rebuild)
                        DayLoadStore.pendingRebuilds.append(rebuild)
                        self.dayRebuildInProgress = nil
                    }
                }
            }
            do {
                let dayLoads = try DayLoadStore.dayLoads(in: container)
                await MainActor.run { self.dayLoads = dayLoads }
                // [DEBUG-n7r4]
                await MainActor.run { ReopenProbe.log("Day Loads shown: \(dayLoads.count)") }
            } catch {
                storeLog.error(
                    "Couldn't read stored Day Loads: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    /// Keeps what the finished sync learnt about the Strap, and its Sync Log.
    private func keepSyncResults(of session: HistorySync) {
        let defaults = UserDefaults.standard
        if let battery = session.batteryLevel {
            lastBatteryLevel = battery
            defaults.set(battery, forKey: batteryLevelKey)
        }
        if let range = session.dataRange {
            lastDataRange = range
            defaults.set(range.oldest, forKey: dataRangeOldestKey)
            defaults.set(range.newest, forKey: dataRangeNewestKey)
        }
        guard let syncStartedAt, case .success(let archive) = logArchive else { return }
        // A day's Sync Log is ~25 MB of text, so build and write it off the main thread.
        let entries = syncLog
        let previous = syncLogSave
        syncLogSave = Task.detached(priority: .utility) {
            await previous?.value
            do {
                try archive.save(entries, syncStartedAt: syncStartedAt)
            } catch {
                storeLog.error(
                    "Couldn't keep the Sync Log: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    private func use(_ found: CBPeripheral) {
        central.stopScan()
        peripheral = found
        found.delegate = self
        strapName = found.name
        phase = .connecting
        central.connect(found)
    }

    private func startSync() {
        wantsSync = false
        if case .failure(let error) = store {
            fail("Couldn't open the History Record store: \(error.localizedDescription)", .other)
            return
        }
        syncLog = []
        historyRecordsReceived = 0
        unsavedRecordTimes = []
        var session = HistorySync()
        let now = Date()
        let output = session.start(at: now)
        self.session = session
        syncStartedAt = now
        phase = .syncing
        ReopenProbe.log("sync started")  // [DEBUG-n7r4]
        syncTimer?.invalidate()
        let timer = Timer(timeInterval: syncTimerInterval, repeats: true) { [weak self] _ in
            // Added to the main run loop below, so it fires on the main actor.
            MainActor.assumeIsolated { self?.syncTimerFired() }
        }
        // `.common`, so the screen keeps updating while the user scrolls.
        RunLoop.main.add(timer, forMode: .common)
        syncTimer = timer
        handle(output, state: session.state)
    }

    private func syncTimerFired() {
        objectWillChange.send()
        failIfStrapWentSilent(at: Date())
    }

    /// Fails the sync if the session says the Strap went silent. The sync timer checks this,
    /// and so do the next Frame and Serenix returning to the foreground, because timers don't
    /// run while iOS keeps Serenix suspended in the background (ADR 0006). Returns whether it
    /// failed the sync.
    @discardableResult
    private func failIfStrapWentSilent(at now: Date) -> Bool {
        guard var session else { return false }
        session.timeOutIfSilent(at: now)
        self.session = session
        guard case .failed(let failure) = session.state else { return false }
        finish(as: .failed(failure.reason, .other))
        return true
    }

    /// Forgets the session and redraws the screen one last time with the final Sync Log.
    private func endSession() {
        // [DEBUG-n7r4]
        ReopenProbe.log("sync ended, \(historyRecordsReceived) History Records, phase \(phase)")
        if let session { keepSyncResults(of: session) }
        session = nil
        syncStartedAt = nil
        syncTimer?.invalidate()
        syncTimer = nil
        // Anything still unsaved was never acknowledged, so the Strap sends it again; drop it
        // rather than carry it into the next sync.
        if case .success(let store) = self.store { store.discardUnsaved() }
        refreshStoreStats()
        unsavedRecordTimes = []
        // Whatever the sync saved was queued as it went, also if it ended early (spec 003, When).
        rebuildNights()
        objectWillChange.send()
    }

    /// Stores the History Records the session produced, writes what it asked for, and ends the
    /// sync if the session completed or failed.
    private func handle(_ output: HistorySyncOutput, state: HistorySyncState) {
        syncLog += output.syncLog
        historyRecordsReceived += output.historyRecords.count
        unsavedRecordTimes += output.historyRecords.map(\.timestamp)
        guard case .success(let store) = self.store else { return }
        store.insert(output.historyRecords)
        if !output.framesToSend.isEmpty || state != .running {
            // The dates these History Records touch are queued before they're saved, so no kill
            // in between can lose them; if the save fails, a queued date is just worked out from
            // what is stored.
            queueNightRebuilds(after: unsavedRecordTimes)
            unsavedRecordTimes = []
            // Save before writing: once the Strap has an acknowledgement it never sends those
            // History Records again, so they must be on the phone first.
            do {
                try store.save()
            } catch {
                store.discardUnsaved()
                fail("Couldn't store History Records: \(error.localizedDescription)", .other)
                return
            }
        }
        if let peripheral, let commandCharacteristic {
            for frame in output.framesToSend {
                // With response, as the captured app writes (spec 001, Notes).
                peripheral.writeValue(Data(frame), for: commandCharacteristic, type: .withResponse)
            }
        }
        switch state {
        case .running:
            break
        case .completed:
            let now = Date()
            lastSyncCompleted = now
            lastSyncRecordCount = historyRecordsReceived
            UserDefaults.standard.set(now, forKey: lastSyncCompletedKey)
            UserDefaults.standard.set(historyRecordsReceived, forKey: lastSyncRecordCountKey)
            finish(as: .synced)
        case .failed(let failure):
            finish(as: .failed(failure.reason, .other))
        }
    }

    /// Ends the connection; the spec disconnects after every sync.
    private func finish(as newPhase: StrapPhase) {
        connectTimer?.invalidate()
        connectTimer = nil
        endSession()
        wantsSync = false
        wantsConnection = false
        phase = newPhase
        // Forget the link now, not when iOS reports the disconnect, so a quick "Sync now"
        // reconnects instead of writing to a connection that's closing.
        commandCharacteristic = nil
        subscribed = []
        if let peripheral {
            central.cancelPeripheralConnection(peripheral)
        }
    }

    private func fail(_ reason: String, _ cause: SyncFailureCause) {
        finish(as: .failed(reason, cause))
    }
}

extension StrapConnection: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if case .bluetoothUnavailable = phase { phase = .idle }
            if wantsConnection {
                wantsConnection = false
                startConnecting()
            }
        case .poweredOff, .resetting:
            // iOS may not report the disconnect, and the peripheral objects are no longer valid.
            let wasSyncing = phase == .syncing
            endSession()
            commandCharacteristic = nil
            subscribed = []
            peripheral = nil
            phase =
                wasSyncing
                ? .failed("Bluetooth turned off mid-sync.", .strapUnreachable)
                : .bluetoothUnavailable("Bluetooth is off.")
        case .unauthorized:
            phase = .bluetoothUnavailable(
                "Serenix isn't allowed to use Bluetooth. Allow it in Settings."
            )
        case .unsupported:
            phase = .bluetoothUnavailable("This iPhone doesn't support Bluetooth LE.")
        default:
            break
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi: NSNumber
    ) {
        let name =
            advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? ""
        guard name.uppercased().hasPrefix(StrapGATT.namePrefix) else { return }
        use(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // Connected: pairing, if iOS needs it, happens next and isn't timed.
        connectTimer?.invalidate()
        connectTimer = nil
        peripheral.discoverServices([StrapGATT.service, StrapGATT.deviceInfoService])
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        fail(
            "Couldn't connect to the Strap: \(error?.localizedDescription ?? "no reason given").",
            .strapUnreachable
        )
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        commandCharacteristic = nil
        subscribed = []
        switch phase {
        case .syncing:
            endSession()
            let reason = error.map { ": \($0.localizedDescription)" } ?? ""
            phase = .failed("The Strap disconnected mid-sync\(reason).", .strapUnreachable)
        case .connecting, .connected:
            // Dropping before a sync that was asked for has started is the Strap being out of
            // reach (spec 002, Sync pill); otherwise there's nothing to say.
            if wantsSync {
                wantsSync = false
                fail("The Strap disconnected before the sync started.", .strapUnreachable)
            } else {
                phase = .idle
            }
        default:
            break
        }
    }
}

extension StrapConnection: @preconcurrency CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            fail("Couldn't read the Strap's services: \(error.localizedDescription)", .other)
            return
        }
        if let deviceInfo = peripheral.services?.first(where: {
            $0.uuid == StrapGATT.deviceInfoService
        }) {
            peripheral.discoverCharacteristics(
                [StrapGATT.modelCharacteristic, StrapGATT.firmwareCharacteristic],
                for: deviceInfo
            )
        }
        guard let service = peripheral.services?.first(where: { $0.uuid == StrapGATT.service })
        else {
            fail(
                "This doesn't look like a Whoop 5.0 Strap: its command service is missing.",
                .other
            )
            return
        }
        peripheral.discoverCharacteristics(
            [StrapGATT.commandCharacteristic] + StrapGATT.notifyCharacteristics,
            for: service
        )
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if service.uuid == StrapGATT.deviceInfoService {
            // Model and firmware are only shown on the debug screen, so a failure here is
            // logged rather than failing the connection.
            if let error {
                strapLog.error(
                    "Couldn't read Device Info: \(error.localizedDescription, privacy: .public)"
                )
            }
            for characteristic in service.characteristics ?? [] {
                peripheral.readValue(for: characteristic)
            }
            return
        }
        if let error {
            fail("Couldn't read the Strap's characteristics: \(error.localizedDescription)", .other)
            return
        }
        let characteristics = service.characteristics ?? []
        commandCharacteristic = characteristics.first {
            $0.uuid == StrapGATT.commandCharacteristic
        }
        let notifying = characteristics.filter {
            StrapGATT.notifyCharacteristics.contains($0.uuid)
        }
        guard commandCharacteristic != nil, notifying.count == StrapGATT.notifyCharacteristics.count
        else {
            fail("The Strap is missing a characteristic Serenix needs.", .other)
            return
        }
        // The Strap refuses these until the link is encrypted, so subscribing is what makes
        // iOS pair (hr-tracker `docs/protocol.md`, GATT).
        for characteristic in notifying {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error {
            fail(
                "Couldn't subscribe to the Strap (\(error.localizedDescription)). If it isn't "
                    + "paired yet, put it in pairing mode and try again.",
                .other
            )
            return
        }
        guard characteristic.isNotifying else { return }
        subscribed.insert(characteristic.uuid)
        guard isReady else { return }
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: rememberedStrapKey)
        phase = .connected
        if wantsSync { startSync() }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if keepDeviceInfo(from: characteristic, error: error) { return }
        let now = Date()
        // A long gap means nothing arrived, whether the Strap went silent or iOS held Serenix
        // up; either way it counts as the Strap not responding (spec 001).
        if failIfStrapWentSilent(at: now) { return }
        guard phase == .syncing, var session else { return }
        if let error {
            fail("Couldn't read from the Strap: \(error.localizedDescription)", .other)
            return
        }
        guard let value = characteristic.value else { return }
        let output = session.receive(Array(value), at: now)
        self.session = session
        handle(output, state: session.state)
    }

    /// Keeps the model or firmware if `characteristic` is one of them; returns whether it was.
    /// A failed read is logged, and the last known value stays.
    private func keepDeviceInfo(from characteristic: CBCharacteristic, error: Error?) -> Bool {
        let isModel = characteristic.uuid == StrapGATT.modelCharacteristic
        guard isModel || characteristic.uuid == StrapGATT.firmwareCharacteristic else {
            return false
        }
        if let error {
            strapLog.error(
                "Couldn't read Device Info: \(error.localizedDescription, privacy: .public)"
            )
            return true
        }
        guard let value = characteristic.value else { return true }
        let text = String(decoding: value, as: UTF8.self)
        if isModel {
            strapModel = text
            UserDefaults.standard.set(text, forKey: strapModelKey)
        } else {
            strapFirmware = text
            UserDefaults.standard.set(text, forKey: strapFirmwareKey)
        }
        return true
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error, phase == .syncing {
            fail("Couldn't write to the Strap: \(error.localizedDescription)", .other)
        }
    }
}

/// The Strap's Bluetooth layout, from hr-tracker `docs/protocol.md` (Advertising, GATT).
private enum StrapGATT {
    /// Its advertised local name is `WHOOP <serial>`.
    static let namePrefix = "WHOOP"
    static var service: CBUUID { CBUUID(string: "fd4b0001-cce1-4033-93ce-002d5875f58a") }
    /// Commands are written here.
    static var commandCharacteristic: CBUUID {
        CBUUID(string: "fd4b0002-cce1-4033-93ce-002d5875f58a")
    }
    /// The standard Device Info service, and its model number and firmware revision.
    static var deviceInfoService: CBUUID { CBUUID(string: "180A") }
    static var modelCharacteristic: CBUUID { CBUUID(string: "2A24") }
    static var firmwareCharacteristic: CBUUID { CBUUID(string: "2A26") }
    /// Replies, events, data and console logs, and misc events: the four channels a sync
    /// listens on.
    static var notifyCharacteristics: Set<CBUUID> {
        [
            CBUUID(string: "fd4b0003-cce1-4033-93ce-002d5875f58a"),
            CBUUID(string: "fd4b0004-cce1-4033-93ce-002d5875f58a"),
            CBUUID(string: "fd4b0005-cce1-4033-93ce-002d5875f58a"),
            CBUUID(string: "fd4b0007-cce1-4033-93ce-002d5875f58a"),
        ]
    }
}

/// Seconds between screen redraws (and timeout checks) during a sync: often enough to watch the
/// counts move, rare enough that drawing never competes with Bluetooth on the main thread.
private let syncTimerInterval: TimeInterval = 0.5

/// UserDefaults keys. The remembered Strap is its CoreBluetooth identifier, which is specific to
/// this iPhone.
private let rememberedStrapKey = "rememberedStrap"
private let lastSyncCompletedKey = "lastSyncCompleted"
private let lastSyncRecordCountKey = "lastSyncRecordCount"
private let strapModelKey = "strapModel"
private let strapFirmwareKey = "strapFirmware"
private let batteryLevelKey = "batteryLevel"
private let dataRangeOldestKey = "dataRangeOldest"
private let dataRangeNewestKey = "dataRangeNewest"

/// Seconds to look for or connect to the Strap before the attempt fails (spec 001: "can't be
/// found or connected"). An assumption: a Strap in range connects within a second or two.
private let connectTimeout: TimeInterval = 30

private let storeLog = Logger(subsystem: "com.ellismchardy.Serenix", category: "store")
private let strapLog = Logger(subsystem: "com.ellismchardy.Serenix", category: "strap")
