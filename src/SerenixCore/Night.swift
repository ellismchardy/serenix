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

    public init(day: Day, sleepScore: Int? = nil, readiness: Int? = nil) {
        self.day = day
        self.sleepScore = sleepScore
        self.readiness = readiness
    }
}
