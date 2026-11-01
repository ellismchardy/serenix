import Foundation

/// One stored Night (GLOSSARY): a Sleep Period with the Nightly Metrics and scores drawn from it.
/// Each value is missing until the spec that computes it has shipped.
public struct Night: Equatable, Sendable {
    /// The local date of its Final Wake.
    public var day: Day

    public init(day: Day) {
        self.day = day
    }
}
