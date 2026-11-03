import Foundation

/// Local clock times compared the shortest way round the clock, so 00:10 is 20 minutes after
/// 23:50 (spec 010, Sleep Consistency; spec 012, Tonight).
enum ClockTime {
    /// Minutes in a day, for clock times.
    static let minutesPerDay = 24.0 * 60

    /// Minutes since local midnight of `date` in `timeZone`.
    static func minutes(of date: Date, in timeZone: TimeZone) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        return Double(parts.hour ?? 0) * 60 + Double(parts.minute ?? 0)
            + Double(parts.second ?? 0) / 60
    }

    /// Minutes from `other`'s local clock time to `time`'s, the shortest way round the clock:
    /// −720 to +720. (IEEE remainder rounds to the nearest whole day, so exactly 12 h keeps its
    /// sign.)
    static func difference(_ time: Date, _ other: Date, in timeZone: TimeZone) -> Double {
        (minutes(of: time, in: timeZone) - minutes(of: other, in: timeZone))
            .remainder(dividingBy: minutesPerDay)
    }

    /// The median local clock time of `dates`, in minutes since midnight (0 to 1440), compared
    /// the shortest way round the clock from the latest, so the order of `dates` doesn't matter.
    /// `dates` must not be empty.
    static func median(of dates: [Date], in timeZone: TimeZone) -> Double {
        guard let reference = dates.max() else {
            preconditionFailure("no dates to take a median of")
        }
        let offset = SerenixCore.median(of: dates.map { difference($0, reference, in: timeZone) })
        return wrapped(minutes(of: reference, in: timeZone) + offset)
    }

    /// `minutes` since midnight as a clock time, "HH:mm", cut to the whole minute (as
    /// `clockText(_:in:)` shows a time) and wrapped round the clock, so −60 reads "23:00".
    static func text(minutes: Double) -> String {
        let whole = Int(wrapped(minutes.rounded(.down)))
        return String(format: "%02d:%02d", whole / 60, whole % 60)
    }

    /// `minutes` wrapped into one day, 0 up to 1440.
    static func wrapped(_ minutes: Double) -> Double {
        let clock = minutes.truncatingRemainder(dividingBy: minutesPerDay)
        return clock < 0 ? clock + minutesPerDay : clock
    }
}
