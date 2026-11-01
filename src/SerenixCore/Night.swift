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
    /// br/min.
    public var respiratoryRate: Double?
    /// °C.
    public var skinTemperature: Double?
    /// %.
    public var spo2: Double?
    /// UTC.
    public var sleepOnset: Date?
    /// UTC.
    public var finalWake: Date?
    /// Seconds.
    public var timeAsleep: TimeInterval?
    /// UTC.
    public var timeInBedStart: Date?
    /// UTC.
    public var timeInBedEnd: Date?

    public init(
        day: Day,
        sleepScore: Int? = nil,
        readiness: Int? = nil,
        restingHR: Double? = nil,
        hrv: Double? = nil,
        respiratoryRate: Double? = nil,
        skinTemperature: Double? = nil,
        spo2: Double? = nil,
        sleepOnset: Date? = nil,
        finalWake: Date? = nil,
        timeAsleep: TimeInterval? = nil,
        timeInBedStart: Date? = nil,
        timeInBedEnd: Date? = nil
    ) {
        self.day = day
        self.sleepScore = sleepScore
        self.readiness = readiness
        self.restingHR = restingHR
        self.hrv = hrv
        self.respiratoryRate = respiratoryRate
        self.skinTemperature = skinTemperature
        self.spo2 = spo2
        self.sleepOnset = sleepOnset
        self.finalWake = finalWake
        self.timeAsleep = timeAsleep
        self.timeInBedStart = timeInBedStart
        self.timeInBedEnd = timeInBedEnd
    }
}

/// One of the Nightly Metrics (GLOSSARY).
public enum NightlyMetric: Equatable, Sendable {
    case restingHR
    case hrv
    case respiratoryRate
    case skinTemperature
    case spo2

    /// The tiles' order (spec 002, Tiles).
    static let tileOrder: [NightlyMetric] = [
        .restingHR, .hrv, .respiratoryRate, .skinTemperature, .spo2,
    ]

    /// The name on its tile (GLOSSARY terms).
    public var name: String {
        switch self {
        case .restingHR: "Resting HR"
        case .hrv: "HRV"
        case .respiratoryRate: "Respiratory rate"
        case .skinTemperature: "Skin temperature"
        case .spo2: "SpO2"
        }
    }

    /// SpO2 has no Baseline; its Zone comes from fixed levels (GLOSSARY).
    var hasBaseline: Bool { self != .spo2 }
}

extension Night {
    /// The Night's value for `metric`, or nil when it's missing or not a plausible number.
    func value(of metric: NightlyMetric) -> Double? {
        let value =
            switch metric {
            case .restingHR: restingHR
            case .hrv: hrv
            case .respiratoryRate: respiratoryRate
            case .skinTemperature: skinTemperature
            case .spo2: spo2
            }
        return plausible(value)
    }

    /// Time Asleep, or nil when it's missing, negative or not a plausible number.
    var plausibleTimeAsleep: TimeInterval? {
        plausible(timeAsleep).flatMap { $0 >= 0 ? $0 : nil }
    }
}

/// A bad value (not a number, infinite, or far too large to be a reading) counts as missing, so
/// it's never shown, used in a Baseline or Zone, or able to crash formatting
/// (docs/architecture.md, Errors).
private func plausible(_ value: Double?) -> Double? {
    value.flatMap { $0.isFinite && abs($0) <= largestPlausibleValue ? $0 : nil }
}

/// Far above any Nightly Metric, or Time Asleep in seconds (a Day is 86 400 s).
private let largestPlausibleValue = 1_000_000.0
