/// A headline's short verdict, in capitals ending with a full stop, telling the user where they
/// stand (spec 018, Verdicts). The shell draws it beside the headline number.
public struct Verdict: Equatable, Sendable {
    /// Whether a verdict is about the user's state, or says there isn't enough data yet.
    public enum Kind: Equatable, Sendable {
        /// About where the user stands.
        case state
        /// There isn't enough data yet; never a warning.
        case waiting
    }

    public let text: String
    public let kind: Kind

    public init(text: String, kind: Kind) {
        self.text = text
        self.kind = kind
    }
}

extension Verdict {
    /// Readiness's verdict (spec 018): no Night first, then Calibrating with the Nights still
    /// needed, then the band, then "NO HRV." for a Night without HRV (spec 008); none if
    /// Readiness is missing with HRV present.
    static func readiness(
        hasNight: Bool,
        calibratingNightsStillNeeded: Int?,
        band: ReadinessBand?,
        hasHRV: Bool
    ) -> Verdict? {
        guard hasNight else { return Verdict(text: "NO NIGHT.", kind: .waiting) }
        if let stillNeeded = calibratingNightsStillNeeded {
            return Verdict(text: "\(stillNeeded) TO GO.", kind: .waiting)
        }
        switch band {
        case .ready: return Verdict(text: "GO HARD.", kind: .state)
        case .steady: return Verdict(text: "HOLD STEADY.", kind: .state)
        case .takeItEasy: return Verdict(text: "EASE OFF.", kind: .state)
        case nil: return hasHRV ? nil : Verdict(text: "NO HRV.", kind: .waiting)
        }
    }
}
