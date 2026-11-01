import Foundation

/// The user's typical Load: the Load part of their Baseline (spec 006; GLOSSARY).
public enum TypicalLoad: Equatable, Sendable {
    /// The median Load of the Days before the Day, rounded to a whole number with halves up.
    case value(Int)
    /// Too few Days with a Load to say; how many there are so far.
    case calibrating(soFar: Int)

    /// Typical Load comes from the Loads of up to this many Days before the Day
    /// (docs/architecture.md, Baseline: "typical Load comes from the last 28 Days").
    static let days = 28
    /// With fewer Days with a Load than this, typical Load is calibrating (spec 006; as
    /// Readiness's 4 Nights).
    static let minimumDays = 4
}

/// The typical Load for `day` (spec 006): the median Load of the 28 Days before it, not counting
/// it. Missing Loads are skipped and a Load of 0 counts; an even count takes the mean of the
/// middle two. With fewer than 4 such Days, calibrating. `dayLoads` holds each Day at most once.
public func typicalLoad(for day: Day, among dayLoads: [DayLoad]) -> TypicalLoad {
    let first = day.adding(days: -TypicalLoad.days)
    let loads =
        dayLoads
        .filter { first <= $0.day && $0.day < day }
        .compactMap(\.load)
    guard loads.count >= TypicalLoad.minimumDays else {
        return .calibrating(soFar: loads.count)
    }
    // Loads are never negative, so rounding away from zero is rounding halves up.
    let middle = median(of: loads.map(Double.init))
    return .value(Int(middle.rounded(.toNearestOrAwayFromZero)))
}
