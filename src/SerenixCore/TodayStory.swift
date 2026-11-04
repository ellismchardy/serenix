import Foundation

/// The Story layout's body for the Day shown (spec 012): a timeline from the Night to the Day
/// so far, drawn from the same values as the Rings layout.
public struct TodayStory: Equatable, Sendable {
    public let steps: [StoryStep]
    /// 002's "No Night yet" / "No Night recorded" when the Day has no Night, in place of the
    /// Night's steps; nil otherwise.
    public let noNightMessage: String?

    init(
        night: Night?,
        noNightMessage: String?,
        tiles: [MetricTile],
        readiness: StoryReadiness,
        loadText: String,
        load dayLoad: Int?,
        typicalLoad: TypicalLoad,
        isToday: Bool,
        timeZone: TimeZone
    ) {
        self.noNightMessage = noNightMessage
        let load = StoryStep(
            kind: .todaySoFar,
            timeLabel: isToday ? "Today so far" : "That Day",
            title: "Load \(loadText)",
            loadVsTypical: loadAgainstTypical(dayLoad, typicalLoad)
        )
        guard let night else {
            steps = [load]
            return
        }
        steps = [
            StoryStep(
                kind: .sleep,
                timeLabel: sleepSpanText(night, timeZone),
                title: sleptText(night)
            ),
            StoryStep(
                kind: .overnight,
                timeLabel: "Overnight",
                title: "Nightly Metrics",
                // Only the Nightly Metrics the Night has get a row (spec 012, Story body).
                metrics: tiles.filter { night.value(of: $0.metric) != nil }
            ),
            StoryStep(
                kind: .thisMorning,
                timeLabel: "This morning",
                title: readiness.title,
                // The Today view gives no advice while Calibrating (no band).
                advice: readiness.advice
            ),
            load,
        ]
    }
}

/// One step of the Story: a small time label over a title (spec 012, Story body).
public struct StoryStep: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case sleep, overnight, thisMorning, todaySoFar }

    public let kind: Kind
    public let timeLabel: String
    public let title: String
    /// The Overnight step's rows, in tile order; empty for every other step.
    public let metrics: [MetricTile]
    /// The This morning step's advice, as in the Readiness message; nil for every other step and
    /// while Readiness is Calibrating.
    public let advice: String?
    /// The Today so far step's bar: the Day's Load against its typical Load, 0 to 1, full at or
    /// above typical. Nil with no Load, while typical Load is calibrating or is 0, and on every
    /// other step.
    public let loadVsTypical: Double?
    /// The popup a tap on the step opens, as the Rings layout's would; nil for Overnight, whose
    /// rows are tapped instead. Whether the popup has content is the shell's check.
    public var tap: StoryTap? {
        switch kind {
        case .sleep: .sleep
        case .overnight: nil
        case .thisMorning: .readiness
        case .todaySoFar: .load
        }
    }
    /// One metric popup per Overnight row, in the same order; empty for every other step.
    public var rowTaps: [StoryTap] { metrics.map { .metric($0.metric) } }

    init(
        kind: Kind,
        timeLabel: String,
        title: String,
        metrics: [MetricTile] = [],
        advice: String? = nil,
        loadVsTypical: Double? = nil
    ) {
        self.kind = kind
        self.timeLabel = timeLabel
        self.title = title
        self.metrics = metrics
        self.advice = advice
        self.loadVsTypical = loadVsTypical
    }
}

/// A popup a tap in the Story opens (spec 012): the same popups as the Rings layout's.
public enum StoryTap: Equatable, Sendable {
    case sleep
    case metric(NightlyMetric)
    case readiness
    case load
}

/// The Readiness values the This morning step is drawn from, as the Today view worked them out.
struct StoryReadiness {
    /// The ring's text: the score, "—", or "n/4" while Calibrating.
    let text: String
    let band: ReadinessBand?
    let isCalibrating: Bool
    let advice: String?

    /// "Readiness 72 — Ready", "Readiness calibrating — 2/4", or "Readiness —" without a score.
    var title: String {
        if isCalibrating { return "Readiness calibrating \u{2014} \(text)" }
        guard let band else { return "Readiness \(text)" }
        return "Readiness \(text) \u{2014} \(band.word)"
    }
}

/// The Day's Load ÷ its typical Load, capped at 1 (spec 012, Story body); nil without both.
private func loadAgainstTypical(_ load: Int?, _ typical: TypicalLoad) -> Double? {
    guard let load, case .value(let typical) = typical, typical > 0 else { return nil }
    return min(Double(load) / Double(typical), 1)
}

/// Sleep Onset → Final Wake in local time, e.g. "23:18 → 06:51"; empty when either is missing.
private func sleepSpanText(_ night: Night, _ timeZone: TimeZone) -> String {
    guard let onset = night.sleepOnset, let wake = night.finalWake else { return "" }
    return "\(clockText(onset, in: timeZone)) \u{2192} \(clockText(wake, in: timeZone))"
}

/// "You slept 7h 12m", or "You slept –" without a Time Asleep.
private func sleptText(_ night: Night) -> String {
    "You slept \(night.timeAsleep.map(durationText) ?? "–")"
}
