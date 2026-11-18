import Foundation

/// How well Serenix's sleep/wake calls agree with PSG over some compared Epochs (spec 019).
/// Sleep is the positive class. A rate whose denominator is 0 is nil.
public struct EpochAgreement: Equatable, Codable, Sendable {
    public let comparedEpochs: Int
    /// Share of PSG sleep Epochs Serenix called asleep.
    public let sensitivity: Double?
    /// Share of PSG wake Epochs Serenix called wake.
    public let specificity: Double?
    /// Share of Epochs where the two agree.
    public let accuracy: Double?
    /// Cohen's κ: agreement beyond what the two sides' sleep shares give by chance.
    public let kappa: Double?

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
        let total = referenceAsleep.count
        comparedEpochs = total
        sensitivity = share(sleepAsSleep, of: sleepAsSleep + sleepAsWake)
        specificity = share(wakeAsWake, of: wakeAsSleep + wakeAsWake)
        accuracy = share(sleepAsSleep + wakeAsWake, of: total)
        if let observed = accuracy {
            let n = Double(total)
            let referenceSleep = Double(sleepAsSleep + sleepAsWake) / n
            let serenixSleep = Double(sleepAsSleep + wakeAsSleep) / n
            let chance =
                referenceSleep * serenixSleep + (1 - referenceSleep) * (1 - serenixSleep)
            kappa = chance == 1 ? nil : (observed - chance) / (1 - chance)
        } else {
            kappa = nil
        }
    }
}

/// `part / whole`, nil when `whole` is 0.
private func share(_ part: Int, of whole: Int) -> Double? {
    whole == 0 ? nil : Double(part) / Double(whole)
}
