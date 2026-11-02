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
    /// Connecting only for Live HR. It stays set until the attempt resolves (ready, failed or
    /// disconnected), even once Live HR is no longer wanted, so a late callback never reads as a
    /// sync failing.
    private var connecting = false

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

    /// The link is ready, and no sync was asked for on it.
    public mutating func linkReady(at time: Date) -> [LiveHRAction] {
        guard connecting else { return [] }
        if isWanted { return beginSession(at: time) }
        connecting = false
        return endConnection()
    }

    /// The link disconnected.
    public mutating func linkDisconnected(facts: StrapLinkFacts) -> LiveHRLinkResponse {
        if !facts.syncRunning, !facts.syncWanted, connecting || heldPhase != nil {
            // A connection only for Live HR ended: back to the phase it stood in for.
            connecting = false
            let actions: [LiveHRAction] = [.stopConnectTimeout, .showPhase(heldPhase ?? .idle)]
            heldPhase = nil
            return LiveHRLinkResponse(actions: actions, wasLiveHRConnection: true)
        }
        // A sync's link: the shell ends it (spec 001).
        return LiveHRLinkResponse(actions: [], wasLiveHRConnection: false)
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

    /// Turns Live HR on: on the link if it's ready, or on a new connection of its own (ADR
    /// 0007). It never starts a sync.
    private mutating func start(_ facts: StrapLinkFacts, at time: Date) -> [LiveHRAction] {
        var actions: [LiveHRAction] = []
        if lastReading == nil { connection = .connecting }
        // An attempt already under way carries on: once it resolves, Live HR starts.
        guard session == nil, !connecting else { return actions }
        guard facts.hasStrap, facts.bluetoothOn else {
            connection = .unavailable
            return actions
        }
        if facts.linkReady { return actions + beginSession(at: time) }
        heldPhase = facts.phase
        connecting = true
        return actions + [.connect]
    }

    /// Turns Live HR off by ending its own connection.
    private mutating func stop(_ facts: StrapLinkFacts, at time: Date) -> [LiveHRAction] {
        var actions: [LiveHRAction] = []
        // The pill starts from "…" the next time it shows.
        lastReading = nil
        arrivedAt = nil
        if var session {
            actions += handle(session.stop(at: time), at: time)
            self.session = nil
            actions += keepLog()
            // Disconnecting also stops the stream, should Live HR off not get out first.
            actions += endConnection()
        } else if connecting, !facts.syncWanted {
            if facts.phase == .searching {
                // Nothing found yet, so nothing to call back: stop here.
                connecting = false
                actions.append(.stopScanning)
                actions += endConnection()
            } else {
                // The attempt resolves through a callback or the connect timeout, quietly.
                actions.append(.cancelConnecting)
            }
        }
        return actions
    }

    private mutating func beginSession(at time: Date) -> [LiveHRAction] {
        connecting = false
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

    private mutating func keepLog() -> [LiveHRAction] {
        guard !log.isEmpty else { return [] }
        defer { log = [] }
        return [.keepLog(log)]
    }
}
