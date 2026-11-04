import Foundation

/// The Story layout's body for the Day shown (spec 012): a timeline from the Night to the Day
/// so far, drawn from the same values as the Rings layout.
public struct TodayStory: Equatable, Sendable {
    public let steps: [StoryStep]

    init(night: Night?, timeZone: TimeZone) {
        guard let night else {
            steps = []
            return
        }
        steps = [
            StoryStep(
                kind: .sleep,
                timeLabel: sleepSpanText(night, timeZone),
                title: sleptText(night)
            ),
            StoryStep(kind: .overnight, timeLabel: "", title: ""),
            StoryStep(kind: .thisMorning, timeLabel: "", title: ""),
            StoryStep(kind: .todaySoFar, timeLabel: "", title: ""),
        ]
    }
}

/// One step of the Story: a small time label over a title (spec 012, Story body).
public struct StoryStep: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case sleep, overnight, thisMorning, todaySoFar }

    public let kind: Kind
    public let timeLabel: String
    public let title: String
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
