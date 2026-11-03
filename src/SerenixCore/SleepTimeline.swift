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
    /// Time in Bed, drawn as a band; nil when the Night has no Time in Bed, or it ends before it
    /// starts.
    public let timeInBed: TimelineSpan?
    /// The user's usual Sleep Onset, drawn as a dashed line labelled with its clock time; nil when
    /// Sleep Consistency is left out.
    public let usualSleepOnset: TimelineMark?
    /// The user's usual Final Wake, likewise.
    public let usualFinalWake: TimelineMark?

    /// How far apart the hour labels are (spec 010: every 2 hours), seconds.
    static let hourLabelStep: TimeInterval = 2 * 3_600

    /// The timeline of `night` with clock times in `timeZone`; nil without both ends of its Sleep
    /// Period. `sleepScore` gives the median differences from the user's usual times (spec 010),
    /// so the gap drawn is the one Sleep Consistency measured.
    init?(_ night: Night, sleepScore: SleepScore?, timeZone: TimeZone) {
        guard let onset = night.sleepOnset, let wake = night.finalWake else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let bed = night.timeInBedStart.flatMap { start in
            night.timeInBedEnd.flatMap { end in end > start ? (start: start, end: end) : nil }
        }
        // Usual time: tonight's less the median signed difference, in minutes.
        let usualOnset = sleepScore?.onsetDifference.map { onset.addingTimeInterval(-$0 * 60) }
        let usualWake = sleepScore?.wakeDifference.map { wake.addingTimeInterval(-$0 * 60) }
        let drawn =
            [onset, wake] + [bed?.start, bed?.end, usualOnset, usualWake].compactMap { $0 }
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
        func mark(_ date: Date) -> TimelineMark {
            TimelineMark(text: clockText(date, in: timeZone), position: position(date))
        }
        sleepOnset = mark(onset)
        finalWake = mark(wake)
        timeInBed = bed.map { TimelineSpan(start: position($0.start), end: position($0.end)) }
        usualSleepOnset = usualOnset.map(mark)
        usualFinalWake = usualWake.map(mark)
    }
}

/// A stretch of the Sleep popup's timeline, from `start` to `end` (start ≤ end), each a share of
/// the axis from its start: 0 to 1.
public struct TimelineSpan: Equatable, Sendable {
    public let start: Double
    public let end: Double
}

/// One labelled point on the Sleep popup's timeline.
public struct TimelineMark: Equatable, Sendable {
    /// What the point is labelled with, e.g. "23:00" or "22".
    public let text: String
    /// Where it sits, as a share of the axis from its start: 0 to 1.
    public let position: Double
}
