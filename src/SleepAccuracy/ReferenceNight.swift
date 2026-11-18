import Foundation
import SerenixCore

/// The label a sleep technician gave one Epoch from PSG (spec 019).
public enum EpochLabel: String, Codable, Sendable {
    case wake
    case n1
    case n2
    case n3
    case rem
    case unscored

    /// Whether the Epoch was sleep; nil when it was not scored.
    var isAsleep: Bool? {
        switch self {
        case .wake: false
        case .n1, .n2, .n3, .rem: true
        case .unscored: nil
        }
    }
}

/// Seconds in an Epoch (AASM scoring).
let epochSeconds: TimeInterval = 30
/// Seconds in a minute, for errors given in minutes.
let secondsPerMinute: TimeInterval = 60

/// One Epoch of a Reference Night: 30 seconds and its PSG label.
public struct Epoch: Equatable, Sendable {
    /// UTC.
    public var start: Date
    public var label: EpochLabel

    public init(start: Date, label: EpochLabel) {
        self.start = start
        self.label = label
    }
}

/// A Reference Night as a dataset adapter gives it: the per-second labelling input for the whole
/// recording, and the PSG label of each Epoch.
public struct ReferenceNight: Sendable {
    /// The dataset's name for the recording.
    public var id: String
    /// Oldest first, without repeats; may run before and after the Epochs.
    public var seconds: [LabellingSecond]
    /// Consecutive, 30 s apart, the first on a whole UTC minute, so each Serenix minute covers
    /// exactly two Epochs.
    public var epochs: [Epoch]

    public init(id: String, seconds: [LabellingSecond], epochs: [Epoch]) {
        self.id = id
        self.seconds = seconds
        self.epochs = epochs
    }
}
