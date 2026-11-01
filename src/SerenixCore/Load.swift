import Foundation

/// The Load of `day` (spec 005): per-second Banister TRIMP over the Day's History Records,
/// counting only heart rates at or over the floor, scaled to 0–100. Missing with no History
/// Records or no Max HR. The order of `records` and any repeats don't matter. For now Resting HR
/// is always the 60 bpm fallback and every record counts toward the Day.
public func load(
    of day: Day,
    records: [HistoryRecord],
    nights: [Night],
    profile: Profile,
    in timeZone: TimeZone
) -> DayLoad {
    var seen = Set<String>()
    let unique = records.filter { seen.insert($0.identity).inserted }
    guard !unique.isEmpty else { return DayLoad(day: day, load: nil, missingReason: .noRecords) }
    guard let maxHR = profile.maxHR.map(Double.init) else {
        return DayLoad(day: day, load: nil, missingReason: .noMaxHR)
    }
    let restingHR = LoadMethod.fallbackRestingHR
    let constants = LoadMethod.BanisterConstants(for: profile.sex)
    let sum = LoadMethod.trimp(
        of: unique.map(\.heartRate),
        restingHR: restingHR,
        maxHR: maxHR,
        constants: constants
    )
    return DayLoad(day: day, load: LoadMethod.scaled(sum, constants: constants))
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

    /// Resting HR with no Nights, bpm. Assumption: a typical adult value (issue 16).
    static let fallbackRestingHR = 60.0
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
        let floor = floorFractionOfMaxHR * maxHR
        return heartRates.reduce(0) { sum, heartRate in
            let bpm = Double(heartRate)
            guard bpm >= floor else { return sum }
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
