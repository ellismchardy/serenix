import Foundation

/// How well Serenix's sleep/wake calls agree with PSG over some compared Epochs (spec 019).
/// Sleep is the positive class. A rate whose denominator is 0 is nil.
public struct EpochAgreement: Equatable, Codable, Sendable {
    /// PSG sleep Epochs Serenix called asleep.
    public let sleepAsSleep: Int
    /// PSG sleep Epochs Serenix called wake.
    public let sleepAsWake: Int
    /// PSG wake Epochs Serenix called asleep.
    public let wakeAsSleep: Int
    /// PSG wake Epochs Serenix called wake.
    public let wakeAsWake: Int

    public var comparedEpochs: Int { sleepAsSleep + sleepAsWake + wakeAsSleep + wakeAsWake }
    /// Share of PSG sleep Epochs Serenix called asleep.
    public var sensitivity: Double? { share(sleepAsSleep, of: sleepAsSleep + sleepAsWake) }
    /// Share of PSG wake Epochs Serenix called wake.
    public var specificity: Double? { share(wakeAsWake, of: wakeAsSleep + wakeAsWake) }
    /// Share of Epochs where the two agree.
    public var accuracy: Double? { share(sleepAsSleep + wakeAsWake, of: comparedEpochs) }
    /// Cohen's κ: agreement beyond what the two sides' sleep shares give by chance.
    public var kappa: Double? {
        guard let observed = accuracy else { return nil }
        let n = Double(comparedEpochs)
        let referenceSleep = Double(sleepAsSleep + sleepAsWake) / n
        let serenixSleep = Double(sleepAsSleep + wakeAsSleep) / n
        let chance = referenceSleep * serenixSleep + (1 - referenceSleep) * (1 - serenixSleep)
        return chance == 1 ? nil : (observed - chance) / (1 - chance)
    }

    /// `referenceAsleep[i]` and `serenixAsleep[i]` are one compared Epoch; same length.
    public init(referenceAsleep: [Bool], serenixAsleep: [Bool]) {
        precondition(referenceAsleep.count == serenixAsleep.count, "one call per side per Epoch")
        var (sleepAsSleep, sleepAsWake, wakeAsSleep, wakeAsWake) = (0, 0, 0, 0)
        for (reference, serenix) in zip(referenceAsleep, serenixAsleep) {
            switch (reference, serenix) {
            case (true, true): sleepAsSleep += 1
            case (true, false): sleepAsWake += 1
            case (false, true): wakeAsSleep += 1
            case (false, false): wakeAsWake += 1
            }
        }
        self.init(
            sleepAsSleep: sleepAsSleep,
            sleepAsWake: sleepAsWake,
            wakeAsSleep: wakeAsSleep,
            wakeAsWake: wakeAsWake
        )
    }

    private init(sleepAsSleep: Int, sleepAsWake: Int, wakeAsSleep: Int, wakeAsWake: Int) {
        self.sleepAsSleep = sleepAsSleep
        self.sleepAsWake = sleepAsWake
        self.wakeAsSleep = wakeAsSleep
        self.wakeAsWake = wakeAsWake
    }

    /// The agreement over every Epoch of `agreements` together: their counts summed.
    public static func pooled(_ agreements: [EpochAgreement]) -> EpochAgreement {
        EpochAgreement(
            sleepAsSleep: agreements.map(\.sleepAsSleep).reduce(0, +),
            sleepAsWake: agreements.map(\.sleepAsWake).reduce(0, +),
            wakeAsSleep: agreements.map(\.wakeAsSleep).reduce(0, +),
            wakeAsWake: agreements.map(\.wakeAsWake).reduce(0, +)
        )
    }
}

/// `part / whole`, nil when `whole` is 0.
private func share(_ part: Int, of whole: Int) -> Double? {
    whole == 0 ? nil : Double(part) / Double(whole)
}
