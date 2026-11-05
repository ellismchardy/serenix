import Foundation

/// One reading of the user's body weight (GLOSSARY, Weigh-in; spec 014). Kept in kg and UTC;
/// its Day is the local date it was taken (ADR 0008).
public struct WeighIn: Hashable, Codable, Sendable {
    public let time: Date
    public let kilograms: Double

    public init(time: Date, kilograms: Double) {
        self.time = time
        self.kilograms = kilograms
    }
}

/// One Day's point on the Trend Weight line (spec 014, Trend Weight).
public struct TrendPoint: Equatable, Sendable {
    public let day: Day
    /// The Weigh-in that counted that Day (the lowest), in kg.
    public let weighIn: Double
    /// Trend Weight after that Weigh-in, in kg.
    public let trendWeight: Double

    public init(day: Day, weighIn: Double, trendWeight: Double) {
        self.day = day
        self.weighIn = weighIn
        self.trendWeight = trendWeight
    }
}
