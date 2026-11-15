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
    static let strongNightFrom = ReadinessBand.readyFrom
    /// The lowest Sleep Score that reads "FAIR NIGHT." (spec 018: borrows Readiness's Steady
    /// edge, `ReadinessBand.steadyFrom`).
    static let fairNightFrom = ReadinessBand.steadyFrom

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

    /// How far either side of the Calorie Target Intake still reads "ON TARGET.", as a share of
    /// it (spec 018: within 10%).
    static let onTargetShare = 0.1

    /// Intake's verdict (spec 018): "NOTHING LOGGED." with no Food Entries, "LOGGED." with no
    /// Calorie Target, "LOGGING." while today is still being logged, else Intake against the
    /// Calorie Target: within 10% "ON TARGET.", beyond it "UNDER." or "OVER.".
    static func intake(
        _ kilocalories: Double,
        hasEntries: Bool,
        calorieTarget: Double?,
        isStillLogging: Bool
    ) -> Verdict {
        guard hasEntries else { return Verdict(text: "NOTHING LOGGED.", kind: .waiting) }
        guard let calorieTarget else { return Verdict(text: "LOGGED.", kind: .state) }
        if isStillLogging { return Verdict(text: "LOGGING.", kind: .waiting) }
        let share = kilocalories / calorieTarget
        let text =
            if share < 1 - onTargetShare {
                "UNDER."
            } else if share > 1 + onTargetShare {
                "OVER."
            } else {
                "ON TARGET."
            }
        return Verdict(text: text, kind: .state)
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
