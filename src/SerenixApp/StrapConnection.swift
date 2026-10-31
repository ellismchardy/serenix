import CoreBluetooth
import Foundation
import SerenixCore

/// Where the Strap connection and its History Sync have got to, for display.
enum StrapPhase: Equatable {
    case idle
    case bluetoothUnavailable(String)
    case searching
    case connecting
    case connected
    case syncing
    case synced
    case failed(String)

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
        case .failed(let reason): "Failed: \(reason)"
        }
    }
}

/// Moves bytes between the Strap and a `HistorySync` session over CoreBluetooth.
///
/// Every decision about what to send lives in `SerenixCore`: this class scans, connects,
/// subscribes, writes what the session asks for and feeds back what the Strap sends. The
/// central manager delivers its callbacks on the main queue (`queue: nil`) and SwiftUI calls in
/// on the main thread, so all state is only ever touched there.
final class StrapConnection: NSObject, ObservableObject, @unchecked Sendable {
    @Published private(set) var phase: StrapPhase = .idle
    @Published private(set) var strapName: String?
    /// The current or last sync's Sync Log. In memory only for now (plan 001, task 4). Not
    /// `@Published`: a day's sync is ~100,000 Frames, and redrawing the screen for each one
    /// slowed the first phone sync to a crawl. `refreshTimer` redraws instead.
    private(set) var syncLog: [SyncLogEntry] = []
    private(set) var historyRecordsReceived = 0

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var commandCharacteristic: CBCharacteristic?
    private var subscribed: Set<CBUUID> = []
    private var session: HistorySync?
    /// Asked to connect before Bluetooth was powered on.
    private var wantsConnection = false
    /// Asked to sync before the Strap was connected and subscribed.
    private var wantsSync = false
    /// Redraws the screen every `screenRefreshInterval` while a sync runs.
    private var refreshTimer: Timer?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
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

    /// Stops looking for, connecting to or syncing with the Strap. CoreBluetooth never gives up
    /// on a scan or a connection by itself.
    func cancel() {
        guard phase.isBusy else { return }
        central.stopScan()
        finish(as: phase == .syncing ? .failed("Cancelled mid-sync.") : .idle)
    }

    private var isReady: Bool {
        peripheral?.state == .connected && commandCharacteristic != nil
            && subscribed == StrapGATT.notifyCharacteristics
    }

    private func startConnecting() {
        if let peripheral {
            phase = .connecting
            central.connect(peripheral)
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
        syncLog = []
        historyRecordsReceived = 0
        var session = HistorySync()
        let output = session.start(at: Date())
        self.session = session
        phase = .syncing
        refreshTimer?.invalidate()
        let timer = Timer(timeInterval: screenRefreshInterval, repeats: true) { [weak self] _ in
            self?.objectWillChange.send()
        }
        // `.common`, so the screen keeps updating while the user scrolls.
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
        handle(output, state: session.state)
    }

    /// Forgets the session and redraws the screen one last time with the final Sync Log.
    private func endSession() {
        session = nil
        refreshTimer?.invalidate()
        refreshTimer = nil
        objectWillChange.send()
    }

    /// Writes what the session asked for, records what it produced, and ends the sync if the
    /// session completed or failed.
    private func handle(_ output: HistorySyncOutput, state: HistorySyncState) {
        syncLog += output.syncLog
        historyRecordsReceived += output.historyRecords.count
        if let peripheral, let commandCharacteristic {
            for frame in output.framesToSend {
                // With response, as the captured app writes (plan 001).
                peripheral.writeValue(Data(frame), for: commandCharacteristic, type: .withResponse)
            }
        }
        switch state {
        case .running:
            break
        case .completed:
            finish(as: .synced)
        case .failed(let failure):
            finish(as: .failed("\(failure)"))
        }
    }

    /// Ends the connection; the spec disconnects after every sync.
    private func finish(as newPhase: StrapPhase) {
        endSession()
        wantsSync = false
        wantsConnection = false
        phase = newPhase
        if let peripheral {
            central.cancelPeripheralConnection(peripheral)
        }
    }

    private func fail(_ reason: String) {
        finish(as: .failed(reason))
    }
}

extension StrapConnection: CBCentralManagerDelegate {
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
                ? .failed("Bluetooth turned off mid-sync.")
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
        peripheral.discoverServices([StrapGATT.service])
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        fail("Couldn't connect to the Strap: \(error?.localizedDescription ?? "no reason given").")
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
            phase = .failed("The Strap disconnected mid-sync\(reason).")
        case .connecting, .connected:
            phase = .idle
        default:
            break
        }
    }
}

extension StrapConnection: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            fail("Couldn't read the Strap's services: \(error.localizedDescription)")
            return
        }
        guard let service = peripheral.services?.first(where: { $0.uuid == StrapGATT.service })
        else {
            fail("This doesn't look like a Whoop 5.0 Strap: its command service is missing.")
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
        if let error {
            fail("Couldn't read the Strap's characteristics: \(error.localizedDescription)")
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
            fail("The Strap is missing a characteristic Serenix needs.")
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
                    + "paired yet, put it in pairing mode and try again."
            )
            return
        }
        guard characteristic.isNotifying else { return }
        subscribed.insert(characteristic.uuid)
        guard isReady else { return }
        phase = .connected
        if wantsSync { startSync() }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard phase == .syncing, var session else { return }
        if let error {
            fail("Couldn't read from the Strap: \(error.localizedDescription)")
            return
        }
        guard let value = characteristic.value else { return }
        let output = session.receive(Array(value), at: Date())
        self.session = session
        handle(output, state: session.state)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error, phase == .syncing {
            fail("Couldn't write to the Strap: \(error.localizedDescription)")
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

/// Seconds between screen redraws during a sync: often enough to watch the counts move, rare
/// enough that drawing never competes with Bluetooth on the main thread.
private let screenRefreshInterval: TimeInterval = 0.5
