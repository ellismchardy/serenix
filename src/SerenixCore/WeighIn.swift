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
    /// True for the first point and for one that restarts Trend Weight after a long gap: the
    /// chart's line breaks before it.
    public let startsNewLine: Bool

    public init(day: Day, weighIn: Double, trendWeight: Double, startsNewLine: Bool = false) {
        self.day = day
        self.weighIn = weighIn
        self.trendWeight = trendWeight
        self.startsNewLine = startsNewLine
    }
}

/// Why a Weigh-in can't be saved (spec 014, Weigh-ins).
public enum WeighInRefusal: Equatable, Sendable {
    case tooLight
    case tooHeavy
    case inTheFuture

    public var message: String {
        switch self {
        case .tooLight: "A Weigh-in can't be under 20 kg."
        case .tooHeavy: "A Weigh-in can't be over 350 kg."
        case .inTheFuture: "A Weigh-in can't be in the future."
        }
    }

    /// The message with its limit in the user's units, e.g. "A Weigh-in can't be under 44.1 lb."
    public func message(in units: WeightUnits) -> String {
        switch self {
        case .tooLight:
            "A Weigh-in can't be under \(units.text(WeighIn.allowedKilograms.lowerBound))."
        case .tooHeavy:
            "A Weigh-in can't be over \(units.text(WeighIn.allowedKilograms.upperBound))."
        case .inTheFuture: message
        }
    }
}

extension WeighIn {
    /// The lightest and heaviest Weigh-in Serenix accepts, in kg (spec 014): wide enough for any
    /// adult, narrow enough to catch a typo such as 8.24 or 824.
    static let allowedKilograms = 20.0...350.0

    /// Why this Weigh-in can't be saved at `now`; nil when it can.
    public func refusal(now: Date) -> WeighInRefusal? {
        if kilograms < Self.allowedKilograms.lowerBound { return .tooLight }
        if kilograms > Self.allowedKilograms.upperBound { return .tooHeavy }
        if time > now { return .inTheFuture }
        return nil
    }
}
