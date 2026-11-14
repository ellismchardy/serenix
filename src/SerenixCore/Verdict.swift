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
    /// The lowest Sleep Score that reads "STRONG NIGHT." (spec 018: borrows Readiness's Ready
    /// edge, `ReadinessBand.readyFrom`, as Sleep Score has no bands of its own).
    static let strongNightFrom = 67
    /// The lowest Sleep Score that reads "FAIR NIGHT." (spec 018: borrows Readiness's Steady
    /// edge, `ReadinessBand.steadyFrom`).
    static let fairNightFrom = 34

    /// A Sleep Score's verdict (spec 018): 67–100 "STRONG NIGHT.", 34–66 "FAIR NIGHT.", 0–33
    /// "ROUGH NIGHT.".
    public static func sleepScore(_ score: Int) -> Verdict {
        let text =
            if score >= strongNightFrom {
                "STRONG NIGHT."
            } else if score >= fairNightFrom {
                "FAIR NIGHT."
            } else {
                "ROUGH NIGHT."
            }
        return Verdict(text: text, kind: .state)
    }

    /// A Weight Goal's pace verdict (spec 018): the pace badge's, or waiting "SETTLING IN.".
    public static func pace(_ status: PaceStatus) -> Verdict {
        switch status {
        case .settlingIn: Verdict(text: "SETTLING IN.", kind: .waiting)
        case .badge(.onPace): Verdict(text: "ON PACE.", kind: .state)
        case .badge(.behind): Verdict(text: "A BIT BEHIND.", kind: .state)
        case .badge(.offPace): Verdict(text: "OFF PACE.", kind: .state)
        case .badge(.tooFast): Verdict(text: "TOO FAST.", kind: .state)
        }
    }

    /// A hold goal's verdict (spec 018): where Trend Weight sits against the band.
    public static func hold(_ state: HoldState) -> Verdict {
        switch state {
        case .inBand: Verdict(text: "IN BAND.", kind: .state)
        case .aboveBand: Verdict(text: "ABOVE BAND.", kind: .state)
        case .belowBand: Verdict(text: "BELOW BAND.", kind: .state)
        }
    }

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
