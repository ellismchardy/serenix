import Foundation

/// The Load of `day` (spec 005): per-second Banister TRIMP over the Day's History Records,
/// counting only heart rates at or over the floor, scaled to 0–100. Max HR is the one entered,
/// else estimated from age in the Day's year. Missing with no History Records or no Max HR. Only
/// records from the Day's local midnight to the next local midnight count; their order and any
/// repeats don't matter. Resting HR comes from `days`; missing too when Max HR isn't above it.
/// With records and a Max HR, it also carries the Day's HR Zones and the Max HR used (spec 006).
/// It always carries the Day's own Resting HR from `days` (spec 007), nil when it has none. When
/// `days` holds a Day more than once, its last entry wins, so a rebuild can pass the stored Days
/// followed by this Day's new Resting HR.
public func load(
    of day: Day,
    records: [HistoryRecord],
    days: [DayLoad],
    profile: Profile,
    in timeZone: TimeZone
) -> DayLoad {
    let latest = Array(Dictionary(days.map { ($0.day, $0) }) { _, later in later }.values)
    var dayLoad = DayLoad(
        day: day,
        load: nil,
        restingHR: latest.first { $0.day == day }?.restingHR
    )
    let span = day.span(in: timeZone)
    let unique = records.unique(in: span)
    guard !unique.isEmpty else {
        dayLoad.missingReason = .noRecords
        return dayLoad
    }
    let maxHRUsed: MaxHRUsed
    if let entered = profile.maxHR {
        maxHRUsed = MaxHRUsed(bpm: Double(entered), source: .entered)
    } else if let estimated = profile.estimatedMaxHR(in: day.year) {
        maxHRUsed = MaxHRUsed(bpm: estimated, source: .estimated)
    } else {
        dayLoad.missingReason = .noMaxHR
        return dayLoad
    }
    let maxHR = maxHRUsed.bpm
    let heartRates = unique.map(\.heartRate)
    dayLoad.heartRate = DayHeartRate(records: unique, span: span, maxHRUsed: maxHRUsed)
    let restingHR = LoadMethod.typicalRestingHR(for: day, among: latest)
    guard maxHR > restingHR else {
        dayLoad.missingReason = .maxHRNotAboveRestingHR
        return dayLoad
    }
    let constants = LoadMethod.BanisterConstants(for: profile.sex)
    let sum = LoadMethod.trimp(
        of: heartRates,
        restingHR: restingHR,
        maxHR: maxHR,
        constants: constants
    )
    dayLoad.load = LoadMethod.scaled(sum, constants: constants)
    return dayLoad
}

/// The pieces of Load's method (spec 005; issue 16; docs/research/cardio-load-methods.md).
enum LoadMethod {
    /// Banister's weighting k · e^(b·r), by sex.
    struct BanisterConstants: Equatable {
        let k: Double
        let b: Double

        /// Male k 0.64, b 1.92; Female k 0.86, b 1.67 (Banister 1991, via Milanez & Pedro
        /// 2012); Prefer not to say their average (issue 16).
        init(for sex: Sex) {
            switch sex {
            case .male: (k, b) = (0.64, 1.92)
            case .female: (k, b) = (0.86, 1.67)
            case .preferNotToSay: (k, b) = (0.75, 1.795)
            }
        }
    }

    /// Resting HR with no Days that have one, bpm. Assumption: a typical adult value (issue 16).
    static let fallbackRestingHR = 60.0
    /// At most this many of the most recent Days give Resting HR (issue 16; as Baseline's 14).
    static let restingHRDays = 14

    /// The median Resting HR (spec 007) of up to `restingHRDays` of the most recent Days on or
    /// before `day`, so the Day's own Resting HR so far counts; Days without one are skipped.
    /// With none, `fallbackRestingHR`.
    static func typicalRestingHR(for day: Day, among days: [DayLoad]) -> Double {
        let recent =
            days
            .filter { $0.day <= day }
            .sorted { $0.day > $1.day }
            .compactMap(\.restingHR)
            .prefix(restingHRDays)
        return recent.isEmpty ? fallbackRestingHR : median(of: Array(recent))
    }

    /// Only heart rates at or over this fraction of Max HR count (Edwards' 50% floor, issue 16).
    static let floorFractionOfMaxHR = 0.5
    /// Seconds at Max HR that score 100: 24 hours (spec 005, Scale; issue 16).
    static let scaleTopSeconds = 24.0 * 60 * 60

    /// Banister TRIMP summed over `heartRates`, one per second: each at or over the floor adds
    /// r · k · e^(b·r) / 60, with r its share of heart-rate reserve, between 0 and 1. A heart rate
    /// of 0 (Strap not worn) is under the floor, so counts nothing.
    static func trimp(
        of heartRates: [Int],
        restingHR: Double,
        maxHR: Double,
        constants: BanisterConstants
    ) -> Double {
        heartRates.reduce(0) { sum, heartRate in
            // Under the floor is exactly in no HR Zone (spec 006), so both use one comparison.
            guard HRZone.zone(forHeartRate: heartRate, maxHR: maxHR) != nil else { return sum }
            let bpm = Double(heartRate)
            let r = min(max((bpm - restingHR) / (maxHR - restingHR), 0), 1)
            return sum + perSecond(r, constants: constants)
        }
    }

    /// `100 · ln(1 + L) / ln(1 + L_max)`, rounded, with L_max 24 hours at Max HR (r = 1).
    static func scaled(_ trimp: Double, constants: BanisterConstants) -> Int {
        let top = scaleTopSeconds * perSecond(1, constants: constants)
        return Int((100 * log1p(trimp) / log1p(top)).rounded())
    }

    /// One second's TRIMP at heart-rate reserve share `r`; per minute, Banister's r · k · e^(b·r).
    private static func perSecond(_ r: Double, constants: BanisterConstants) -> Double {
        r * constants.k * exp(constants.b * r) / 60
    }
}
