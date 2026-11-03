import Foundation

/// The Sleep popup's "When you slept" timeline (spec 010, Sleep popup): the Night's Sleep Period
/// on an axis of whole local hours. It decides every position; the shell only draws.
public struct SleepTimeline: Equatable, Sendable {
    /// The earliest time drawn, rounded down to the whole local hour.
    public let axisStart: Date
    /// The latest time drawn, rounded up to the whole local hour (a time on the hour stays).
    public let axisEnd: Date
    /// The local hour labelled every `hourLabelStep` from the axis start, e.g. "22", "00".
    public let hours: [TimelineMark]
    public let sleepOnset: TimelineMark
    public let finalWake: TimelineMark

    /// How far apart the hour labels are (spec 010: every 2 hours), seconds.
    static let hourLabelStep: TimeInterval = 2 * 3_600

    /// The timeline of `night` with clock times in `timeZone`; nil without both ends of its Sleep
    /// Period.
    init?(_ night: Night, timeZone: TimeZone) {
        guard let onset = night.sleepOnset, let wake = night.finalWake else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let drawn = [onset, wake]
        guard let earliest = drawn.min(), let latest = drawn.max(),
            let start = calendar.dateInterval(of: .hour, for: earliest)?.start,
            let latestHour = calendar.dateInterval(of: .hour, for: latest)
        else { return nil }
        let end = latestHour.start == latest ? latest : latestHour.end
        axisStart = start
        axisEnd = end
        let span = end.timeIntervalSince(start)
        func position(_ date: Date) -> Double {
            span > 0 ? date.timeIntervalSince(start) / span : 0
        }
        hours = stride(from: 0, through: span, by: Self.hourLabelStep).map { offset in
            let time = start.addingTimeInterval(offset)
            let hour = calendar.component(.hour, from: time)
            return TimelineMark(text: String(format: "%02ld", hour), position: position(time))
        }
        sleepOnset = TimelineMark(text: clockText(onset, in: timeZone), position: position(onset))
        finalWake = TimelineMark(text: clockText(wake, in: timeZone), position: position(wake))
    }
}

/// One labelled point on the Sleep popup's timeline.
public struct TimelineMark: Equatable, Sendable {
    /// What the point is labelled with, e.g. "23:00" or "22".
    public let text: String
    /// Where it sits, as a share of the axis from its start: 0 to 1.
    public let position: Double
}
