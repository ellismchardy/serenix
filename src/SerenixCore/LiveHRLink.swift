import Foundation

/// What only the shell knows about its Strap link when an event arrives.
public struct StrapLinkFacts: Equatable, Sendable {
    /// The shell's phase.
    public var phase: StrapPhase
    /// A History Sync session is running.
    public var syncRunning: Bool
    /// "Sync now" was asked for before the link was ready.
    public var syncWanted: Bool
    /// Bluetooth is powered on.
    public var bluetoothOn: Bool
    /// A Strap has been paired with Serenix.
    public var hasStrap: Bool
    /// Connected, with the command characteristic found and every notify channel subscribed.
    public var linkReady: Bool
    /// The link is still closing, so it can't be used yet.
    public var linkClosing: Bool

    public init(
        phase: StrapPhase = .idle,
        syncRunning: Bool = false,
        syncWanted: Bool = false,
        bluetoothOn: Bool = true,
        hasStrap: Bool = true,
        linkReady: Bool = false,
        linkClosing: Bool = false
    ) {
        self.phase = phase
        self.syncRunning = syncRunning
        self.syncWanted = syncWanted
        self.bluetoothOn = bluetoothOn
        self.hasStrap = hasStrap
        self.linkReady = linkReady
        self.linkClosing = linkClosing
    }
}

/// One thing the shell does for Live HR, in the order given.
public enum LiveHRAction: Equatable, Sendable {
    /// Turns Live HR on or off within the running History Sync.
    case setLiveHRInSync(Bool)
    /// Starts connecting to the remembered Strap.
    case connect
    /// Writes these whole Frames to the Strap, in order.
    case write([[UInt8]])
    /// Stops looking for the Strap.
    case stopScanning
    /// Cancels the connection attempt in progress; it resolves through a callback.
    case cancelConnecting
    /// Stops the connect timeout, forgets the link's characteristics and disconnects.
    case disconnect
    /// Stops the connect timeout, leaving the link as it is.
    case stopConnectTimeout
    /// Sets the shell's phase back to the one a connection only for Live HR stood in for.
    case showPhase(StrapPhase)
    /// Calls `retryDue` after this many seconds.
    case scheduleRetry(after: TimeInterval)
    /// Cancels the retry `scheduleRetry` asked for.
    case cancelRetry
    /// Keeps these messages as the one "Live HR" Sync Log (spec 006).
    case keepLog([SyncLogEntry])
    /// Logs Live HR Frames that gave no reading, and why.
    case logSkipped([LiveHRSkip])
}

/// What the link made of a failure or disconnect on the Strap link.
public struct LiveHRLinkResponse: Equatable, Sendable {
    public var actions: [LiveHRAction]
    /// Whether it was Live HR's own connection; if not, the shell deals with it as before.
    public var wasLiveHRConnection: Bool

    public init(actions: [LiveHRAction], wasLiveHRConnection: Bool) {
        self.actions = actions
        self.wasLiveHRConnection = wasLiveHRConnection
    }
}

/// Seconds after Live HR's connection fails or drops before trying again, while the pill is on
/// screen. An assumption: soon enough that a Strap back in range shows again within seconds.
let liveHRRetryDelay: TimeInterval = 1

/// Every Live HR decision for the shell's Strap link (spec 006; ADR 0007), as a pure state
/// machine.
///
/// Live HR runs while the pill on today's Load popup is shown and Serenix is in the foreground:
/// within a running History Sync, or on a connection of its own. That connection fails quietly
/// (the pill shows "—" and it retries) and stands in for the phase the shell showed before it, so
/// the sync pill keeps what it showed. The shell feeds in events with what it knows
/// (`StrapLinkFacts`) and carries out the returned actions in order.
public struct LiveHRLink: Sendable {
    /// Where Live HR's connection stands, the last reading and when it arrived on the phone, for
    /// the pill.
    public private(set) var connection: LiveHRConnection = .unavailable
    public private(set) var lastReading: LiveHRReading?
    public private(set) var arrivedAt: Date?
    /// The phase a connection only for Live HR stands in for: the sync pill shows it, and it
    /// comes back when that connection ends.
    public private(set) var heldPhase: StrapPhase?

    private var shown = false
    private var inForeground = true
    /// Live HR on a connection of its own, and its messages for the "Live HR" Sync Log.
    private var session: LiveHRSession?
    private var log: [SyncLogEntry] = []
    /// Whether Live HR is on within the running sync.
    private var onInSync = false
    /// Connecting only for Live HR. It lasts until the attempt resolves (ready, failed or
    /// disconnected), even once Live HR is no longer wanted, so a late callback never reads as a
    /// sync failing.
    private var attempt: Attempt?
    /// Live HR is to start once another connection in progress (not a sync, e.g. pairing) is
    /// ready. That connection stays the user's: its failures are not made quiet.
    private var startWhenReady = false
    /// A retry is scheduled and hasn't fallen due.
    private var retryPending = false

    public init() {}

    /// Live HR runs while its pill is shown and Serenix is in the foreground.
    public var isWanted: Bool { shown && inForeground }
    public var isStreaming: Bool { session != nil }

    public func pill(at now: Date) -> LiveHRPill {
        liveHRPill(connection: connection, last: lastReading, arrivedAt: arrivedAt, now: now)
    }

    /// The phase the sync pill reads: a connection only for Live HR isn't a sync, so the pill
    /// keeps showing what it showed before (spec 006: nothing else about syncing changes).
    public func phaseForSyncPill(_ facts: StrapLinkFacts) -> StrapPhase {
        facts.syncRunning || facts.syncWanted ? facts.phase : heldPhase ?? facts.phase
    }

    /// Shows or hides the Live HR pill, as today's Load popup opens or closes.
    public mutating func setShown(
        _ shown: Bool,
        facts: StrapLinkFacts,
        at time: Date
    ) -> [LiveHRAction] {
        self.shown = shown
        return update(facts, at: time)
    }

    /// Serenix came to or left the foreground.
    public mutating func setForeground(
        _ inForeground: Bool,
        facts: StrapLinkFacts,
        at time: Date
    ) -> [LiveHRAction] {
        self.inForeground = inForeground
        return update(facts, at: time)
    }

    /// The link connected (before pairing and subscribing). Only noted, for telling the end of
    /// Live HR's own attempt from the link before it closing late.
    public mutating func linkConnected() {
        if attempt == .pending { attempt = .connected }
    }

    /// The link is ready, and no sync was asked for on it.
    public mutating func linkReady(at time: Date) -> [LiveHRAction] {
        guard attempt != nil || startWhenReady else { return [] }
        startWhenReady = false
        if isWanted { return beginSession(at: time) }
        guard attempt != nil else { return [] }
        attempt = nil
        return endConnection()
    }

    /// Finding, connecting to or setting up the link failed. Live HR's own attempt fails
    /// quietly: the pill shows "—" and the sync pill keeps what it showed (spec 006).
    public mutating func linkFailed(facts: StrapLinkFacts) -> LiveHRLinkResponse {
        guard attempt != nil, !facts.syncRunning, !facts.syncWanted else {
            return LiveHRLinkResponse(actions: [], wasLiveHRConnection: false)
        }
        attempt = nil
        var actions: [LiveHRAction] = [.stopScanning]
        actions += endConnection()
        if lastReading == nil { connection = .unavailable }
        actions += scheduleRetry()
        return LiveHRLinkResponse(actions: actions, wasLiveHRConnection: true)
    }

    /// The link disconnected.
    public mutating func linkDisconnected(facts: StrapLinkFacts) -> LiveHRLinkResponse {
        if attempt == .pending {
            // The link before this attempt closing late: the attempt carries on, and the phase
            // it stands in for stays.
            return LiveHRLinkResponse(actions: [], wasLiveHRConnection: true)
        }
        var actions: [LiveHRAction] = []
        if session != nil {
            // The Strap went out of range or off: the pill shows "—" until it's back.
            actions += dropSession()
            connection = .unavailable
        }
        if !facts.syncRunning, facts.syncWanted, attempt != nil, !isWanted {
            // "Sync now" while a Live HR attempt that was cancelled was still closing: that
            // close isn't the sync's failure, so connect for the sync now.
            attempt = nil
            heldPhase = nil
            actions += [.showPhase(.idle), .connect]
            return LiveHRLinkResponse(actions: actions, wasLiveHRConnection: true)
        }
        if !facts.syncRunning, !facts.syncWanted, attempt != nil || heldPhase != nil {
            // A connection only for Live HR ended: back to the phase it stood in for, and Live
            // HR tries again while it's wanted.
            attempt = nil
            actions += [.stopConnectTimeout, .showPhase(heldPhase ?? .idle)]
            heldPhase = nil
            actions += scheduleRetry()
            return LiveHRLinkResponse(actions: actions, wasLiveHRConnection: true)
        }
        // Not Live HR's own connection (a sync's, or the user's): the shell deals with it, and
        // Live HR carries on after it.
        onInSync = false
        actions += scheduleRetry()
        return LiveHRLinkResponse(actions: actions, wasLiveHRConnection: false)
    }

    /// A History Sync is starting on the ready link. It takes over Live HR: a stream on this
    /// connection carries on into it.
    public mutating func syncStarting() -> [LiveHRAction] {
        forgetAttempt()
        var actions = dropSession()
        if isWanted {
            onInSync = true
            actions.append(.setLiveHRInSync(true))
        }
        return actions
    }

    /// The shell finished a sync, or the connection attempt for one, and disconnected (spec
    /// 001). Live HR, while still wanted, carries on on a connection of its own (spec 006).
    public mutating func syncFinished() -> [LiveHRAction] {
        onInSync = false
        forgetAttempt()
        guard isWanted, session == nil else { return [] }
        if lastReading == nil { connection = .unavailable }
        return scheduleRetry()
    }

    /// Notes Live HR readings a running sync passed out. Readings that arrive once Live HR is off in
    /// the sync are stale.
    public mutating func noteReadings(_ readings: [LiveHRReading], at time: Date) {
        guard onInSync else { return }
        note(readings, at: time)
    }

    /// Bluetooth came on. The shell calls this only when no connection (pairing or a sync) was
    /// waiting for Bluetooth; that one connects instead.
    public mutating func bluetoothOn(facts: StrapLinkFacts, at time: Date) -> [LiveHRAction] {
        isWanted ? start(facts, at: time) : []
    }

    /// Bluetooth went off or is resetting: every link is gone.
    public mutating func bluetoothOff() -> [LiveHRAction] {
        let actions = dropSession()
        forgetAttempt()
        onInSync = false
        connection = .unavailable
        return actions
    }

    /// The retry `scheduleRetry` asked for fell due.
    public mutating func retryDue(facts: StrapLinkFacts, at time: Date) -> [LiveHRAction] {
        retryPending = false
        return isWanted ? start(facts, at: time, retrying: true) : []
    }

    /// Feeds one message the Strap sent on Live HR's own connection.
    public mutating func receive(_ bytes: [UInt8], at time: Date) -> [LiveHRAction] {
        guard var session else { return [] }
        let output = session.receive(bytes, at: time)
        self.session = session
        return handle(output, at: time)
    }

    private mutating func update(_ facts: StrapLinkFacts, at time: Date) -> [LiveHRAction] {
        isWanted ? start(facts, at: time) : stop(facts, at: time)
    }

    /// Turns Live HR on: within the running sync, on the link if it's ready, or on a new
    /// connection of its own (ADR 0007). It never starts a sync. A retry after a failed attempt
    /// keeps the pill on "—" until a reading arrives.
    private mutating func start(
        _ facts: StrapLinkFacts,
        at time: Date,
        retrying: Bool = false
    ) -> [LiveHRAction] {
        var actions = cancelRetry()
        if lastReading == nil { connection = retrying ? .unavailable : .connecting }
        if facts.phase == .syncing, facts.syncRunning {
            guard !onInSync else { return actions }
            onInSync = true
            return actions + [.setLiveHRInSync(true)]
        }
        // An attempt already under way carries on: once it resolves, Live HR starts or retries.
        guard session == nil, attempt == nil else { return actions }
        if facts.syncWanted || facts.phase.isBusy {
            // A sync on its way turns Live HR on as it starts; any other connection starts it
            // once ready.
            if !facts.syncWanted { startWhenReady = true }
            return actions
        }
        guard facts.hasStrap, facts.bluetoothOn else {
            connection = .unavailable
            return actions
        }
        // A link still closing can't be used yet: try again once it has closed.
        if facts.linkClosing { return actions + scheduleRetry() }
        if facts.linkReady { return actions + beginSession(at: time) }
        heldPhase = facts.phase
        attempt = .pending
        return actions + [.connect]
    }

    /// Turns Live HR off: within the running sync, which carries on (ADR 0006), or by ending its
    /// own connection.
    private mutating func stop(_ facts: StrapLinkFacts, at time: Date) -> [LiveHRAction] {
        var actions = cancelRetry()
        // The pill starts from "…" the next time it shows.
        lastReading = nil
        arrivedAt = nil
        if onInSync, facts.phase == .syncing, facts.syncRunning {
            actions.append(.setLiveHRInSync(false))
        }
        onInSync = false
        if var session {
            actions += handle(session.stop(at: time), at: time)
            self.session = nil
            actions += keepLog()
            // Disconnecting also stops the stream, should Live HR off not get out first.
            actions += endConnection()
        } else if attempt != nil, !facts.syncWanted {
            if facts.phase == .searching {
                // Nothing found yet, so nothing to call back: stop here.
                attempt = nil
                actions.append(.stopScanning)
                actions += endConnection()
            } else {
                // The attempt resolves through a callback or the connect timeout, quietly.
                attempt = .cancelled
                actions.append(.cancelConnecting)
            }
        }
        return actions
    }

    private mutating func beginSession(at time: Date) -> [LiveHRAction] {
        attempt = nil
        var session = LiveHRSession()
        log = []
        let output = session.start(at: time)
        self.session = session
        return handle(output, at: time)
    }

    private mutating func handle(_ output: LiveHRSessionOutput, at time: Date) -> [LiveHRAction] {
        log += output.syncLog
        note(output.readings, at: time)
        var actions: [LiveHRAction] = []
        if !output.skipped.isEmpty { actions.append(.logSkipped(output.skipped)) }
        if !output.framesToSend.isEmpty { actions.append(.write(output.framesToSend)) }
        return actions
    }

    private mutating func note(_ readings: [LiveHRReading], at time: Date) {
        guard let last = readings.last else { return }
        lastReading = last
        arrivedAt = time
        connection = .connected
    }

    /// Disconnects a connection that was only for Live HR, back to the phase it stood in for.
    private mutating func endConnection() -> [LiveHRAction] {
        let phase = heldPhase ?? .idle
        heldPhase = nil
        return [.disconnect, .showPhase(phase)]
    }

    /// Ends the session, if any, keeping its Sync Log; the caller deals with the link.
    private mutating func dropSession() -> [LiveHRAction] {
        guard session != nil else { return [] }
        session = nil
        return keepLog()
    }

    private mutating func keepLog() -> [LiveHRAction] {
        guard !log.isEmpty else { return [] }
        defer { log = [] }
        return [.keepLog(log)]
    }

    /// Forgets a connection attempt and the phase it stood in for.
    private mutating func forgetAttempt() {
        attempt = nil
        heldPhase = nil
        startWhenReady = false
    }

    /// While Live HR is wanted, tries again a moment after its connection failed or dropped (a
    /// failed attempt itself takes up to the shell's connect timeout).
    private mutating func scheduleRetry() -> [LiveHRAction] {
        guard isWanted, !retryPending else { return [] }
        retryPending = true
        return [.scheduleRetry(after: liveHRRetryDelay)]
    }

    private mutating func cancelRetry() -> [LiveHRAction] {
        guard retryPending else { return [] }
        retryPending = false
        return [.cancelRetry]
    }

    /// Where Live HR's own connection attempt has got to. A disconnect while it's still pending
    /// is the link before it closing late, not this attempt ending: CoreBluetooth reports a
    /// failed connect with `didFailToConnect`, and a disconnect before `didConnect` only follows
    /// a cancel.
    private enum Attempt {
        case pending
        case connected
        case cancelled
    }
}
