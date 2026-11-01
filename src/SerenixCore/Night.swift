import Foundation

/// One stored Night (GLOSSARY): a Sleep Period with the Nightly Metrics and scores drawn from it.
/// Each value is missing until the spec that computes it has shipped.
public struct Night: Equatable, Sendable {
    /// The local date of its Final Wake.
    public var day: Day
    /// 0–100 (ADR 0005).
    public var sleepScore: Int?
    /// 0–100 (ADR 0005).
    public var readiness: Int?
    /// bpm.
    public var restingHR: Double?
    /// RMSSD, ms.
    public var hrv: Double?

    public init(
        day: Day,
        sleepScore: Int? = nil,
        readiness: Int? = nil,
        restingHR: Double? = nil,
        hrv: Double? = nil
    ) {
        self.day = day
        self.sleepScore = sleepScore
        self.readiness = readiness
        self.restingHR = restingHR
        self.hrv = hrv
    }
}

/// One of the Nightly Metrics (GLOSSARY).
public enum NightlyMetric: Equatable, Sendable {
    case restingHR
    case hrv

    /// The tiles' order (spec 002, Tiles). Task 4 adds the rest.
    static let tileOrder: [NightlyMetric] = [.hrv]
}

extension Night {
    /// The Night's value for `metric`. One that isn't a finite number counts as missing, so a
    /// bad value is never shown or used in a Baseline.
    func value(of metric: NightlyMetric) -> Double? {
        let value =
            switch metric {
            case .restingHR: restingHR
            case .hrv: hrv
            }
        return value.flatMap { $0.isFinite ? $0 : nil }
    }
}
