import Foundation

/// How well the user slept in a Night's Sleep Period, from its parts (spec 010). Every constant
/// is an assumption from issue #35 and docs/research/sleep-score-without-stages.md: tune with
/// real Nights.
struct SleepScore: Equatable, Sendable {
    /// Sleep Sufficiency's share of Sleep Score, before re-weighting (spec 010). Unitless.
    static let sufficiencyWeight = 0.6
    /// Sleep Efficiency's share of Sleep Score, before re-weighting (spec 010). Unitless.
    static let efficiencyWeight = 0.2
    /// Sleep Consistency's share of Sleep Score, before re-weighting (spec 010). Unitless.
    static let consistencyWeight = 0.2
    /// Minutes off the usual Sleep Onset and Final Wake at or beyond which Sleep Consistency is 0
    /// (spec 010: 2 h).
    static let zeroConsistencyMinutes = 120.0
    /// The fewest earlier Nights with both Sleep Onset and Final Wake that Sleep Consistency needs
    /// (spec 010: 3; a median of fewer is noise).
    static let fewestConsistencyNights = 3
    /// Minutes in a day, for clock times.
    private static let minutesPerDay = 24.0 * 60
    /// The share of the Sleep Period asleep at or above which Sleep Efficiency is 100 (spec 010:
    /// 95%). Unitless.
    static let fullEfficiency = 0.95
    /// The share of the Sleep Period asleep at or below which Sleep Efficiency is 0 (spec 010:
    /// 75%, bracketing the NSF's "85% or more is good"). Unitless.
    static let zeroEfficiency = 0.75

    /// The Night's Time Asleep, seconds.
    let timeAsleep: TimeInterval
    /// The Night's Sleep Need it's measured against, seconds (spec 009).
    let sleepNeed: TimeInterval
    /// How much of the Night's Sleep Need its Time Asleep met, 0–100, unrounded.
    let sufficiency: Double
    /// The share of the Sleep Period asleep, 0 to 1; nil when Sleep Efficiency is left out.
    let asleepShare: Double?
    /// `asleepShare` scored 0–100 and unrounded: Sleep Efficiency; nil when left out.
    let efficiency: Double?
    /// Tonight's Sleep Onset minus the week before's, in minutes the shortest way round the clock:
    /// the median signed difference, unrounded; nil when Sleep Consistency is left out.
    let onsetDifference: Double?
    /// Tonight's Final Wake minus the week before's, likewise; nil when Sleep Consistency is left
    /// out.
    let wakeDifference: Double?
    /// How far tonight's Sleep Onset and Final Wake were from the week before's, in minutes,
    /// unrounded: the mean of the two differences' sizes; nil when Sleep Consistency is left out.
    let minutesOff: Double?
    /// How close tonight's times came to the week before's, scored 0–100 and unrounded; nil when
    /// left out.
    let consistency: Double?
    /// The Sleep Score, 0–100, rounded with halves up.
    let score: Int

    /// The Sleep Score of `night` against its Sleep Need, in seconds (spec 009), with clock times
    /// in `timeZone`; nil when the Night has no plausible Time Asleep. `nights` are the stored
    /// Nights, from which the week before is taken.
    init?(of night: Night, among nights: [Night], sleepNeed: TimeInterval, timeZone: TimeZone) {
        guard let timeAsleep = night.plausibleTimeAsleep else { return nil }
        self.timeAsleep = timeAsleep
        self.sleepNeed = sleepNeed
        sufficiency = min(timeAsleep / sleepNeed, 1) * 100
        // Left out without both ends of the Sleep Period, or when Time Asleep is longer than it
        // (spec 010, Missing and left out).
        let period = night.sleepOnset.flatMap { onset in
            night.finalWake.map { $0.timeIntervalSince(onset) }
        }
        let asleepShare: Double? =
            if let period, period > 0, timeAsleep <= period { timeAsleep / period } else { nil }
        self.asleepShare = asleepShare
        efficiency = asleepShare.map {
            Self.scaled($0, zeroAt: Self.zeroEfficiency, fullAt: Self.fullEfficiency)
        }
        let differences = Self.differences(of: night, among: nights, timeZone: timeZone)
        onsetDifference = differences?.onset
        wakeDifference = differences?.wake
        let minutesOff = differences.map { (abs($0.onset) + abs($0.wake)) / 2 }
        self.minutesOff = minutesOff
        // 100 at 0 minutes off, down to 0 at `zeroConsistencyMinutes`.
        let consistency = minutesOff.map {
            100 - Self.scaled($0, zeroAt: 0, fullAt: Self.zeroConsistencyMinutes)
        }
        self.consistency = consistency
        // The parts left are scaled up to add to 1.
        var parts = [(score: sufficiency, weight: Self.sufficiencyWeight)]
        if let efficiency { parts.append((efficiency, Self.efficiencyWeight)) }
        if let consistency { parts.append((consistency, Self.consistencyWeight)) }
        let totalWeight = parts.reduce(0) { $0 + $1.weight }
        let weighted = parts.reduce(0) { $0 + $1.score * $1.weight / totalWeight }
        score = halvesUp(weighted)
    }

    /// How far `night`'s Sleep Onset and Final Wake were from those of the Nights dated D − 7 to
    /// D − 1 that have both, in minutes: for each, the median signed difference the shortest way
    /// round the clock. Nil when the Night lacks either time or fewer than
    /// `fewestConsistencyNights` earlier Nights count (spec 010).
    private static func differences(
        of night: Night,
        among nights: [Night],
        timeZone: TimeZone
    ) -> (onset: Double, wake: Double)? {
        guard let onset = night.sleepOnset, let wake = night.finalWake else { return nil }
        let window = SleepNeed.window(before: night.day)
        let earlier = nights.filter { window.contains($0.day) }.compactMap { other in
            other.sleepOnset.flatMap { earlierOnset in
                other.finalWake.map { (onset: earlierOnset, wake: $0) }
            }
        }
        guard earlier.count >= fewestConsistencyNights else { return nil }
        return (
            onset: median(of: earlier.map { clockDifference(onset, $0.onset, in: timeZone) }),
            wake: median(of: earlier.map { clockDifference(wake, $0.wake, in: timeZone) })
        )
    }

    /// Minutes from `other`'s local clock time to `time`'s, the shortest way round the clock:
    /// −720 to +720, so 00:10 is 20 minutes after 23:50. (IEEE remainder rounds to the nearest
    /// whole day, so exactly 12 h keeps its sign.)
    private static func clockDifference(_ time: Date, _ other: Date, in timeZone: TimeZone)
        -> Double
    {
        (clockMinutes(time, in: timeZone) - clockMinutes(other, in: timeZone))
            .remainder(dividingBy: minutesPerDay)
    }

    /// Minutes since local midnight of `date` in `timeZone`.
    private static func clockMinutes(_ date: Date, in timeZone: TimeZone) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        return Double(parts.hour ?? 0) * 60 + Double(parts.minute ?? 0)
            + Double(parts.second ?? 0) / 60
    }

    /// `value` on a straight line from 0 (at `zeroAt`) to 100 (at `fullAt`), held at 0 and 100
    /// beyond them.
    private static func scaled(_ value: Double, zeroAt: Double, fullAt: Double) -> Double {
        min(max((value - zeroAt) / (fullAt - zeroAt), 0), 1) * 100
    }
}
