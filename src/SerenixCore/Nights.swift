import Foundation

/// The Nights found in `records`, each dated by the local date of its Final Wake in `timeZone`
/// (spec 003). Records are grouped into night windows, local noon to the next local noon, and
/// each window gives at most one Night: its main Sleep Period. When two windows give Nights with
/// the same date, the one with more Time Asleep is kept (on a tie, the one that ends first). The
/// order of `records` and any repeats don't matter. Oldest Night first.
public func nights(from records: [HistoryRecord], in timeZone: TimeZone) -> [Night] {
    var seen = Set<String>()
    let unique = records.filter { seen.insert($0.identity).inserted }
    let byWindow = Dictionary(grouping: unique) {
        nightWindow(containing: $0.timestamp, in: timeZone).start
    }
    let found = byWindow.values.compactMap {
        windowRecords -> (night: Night, period: SleepPeriod)? in
        let sorted = windowRecords.sorted {
            ($0.timestamp, $0.recordCounter) < ($1.timestamp, $1.recordCounter)
        }
        guard let period = SleepPeriod(records: sorted) else { return nil }
        return (night(from: sorted, period: period, in: timeZone), period)
    }
    return Dictionary(grouping: found) { $0.night.day }.values
        .compactMap { sameDate in
            sameDate.min { kept, other in
                kept.period.timeAsleep != other.period.timeAsleep
                    ? kept.period.timeAsleep > other.period.timeAsleep
                    : kept.period.finalWake < other.period.finalWake
            }?.night
        }
        .sorted { $0.day < $1.day }
}

/// The Night of one window's Sleep Period, with its Nightly Metrics. `records` oldest first.
private func night(from records: [HistoryRecord], period: SleepPeriod, in timeZone: TimeZone)
    -> Night
{
    // The Nightly Metrics use the Sleep Period's records with a heart rate (metrics.py).
    let asleep = records.filter {
        $0.timestamp >= period.sleepOnset && $0.timestamp < period.finalWake
            && $0.heartRate > 0
    }
    return Night(
        day: Day(containing: period.finalWake, in: timeZone),
        restingHR: NightlyMetrics.restingHR(of: asleep),
        hrv: NightlyMetrics.hrv(of: asleep),
        respiratoryRate: NightlyMetrics.respiratoryRate(
            of: asleep,
            sleepOnset: period.sleepOnset,
            finalWake: period.finalWake
        ),
        skinTemperature: NightlyMetrics.skinTemperature(of: asleep),
        spo2: NightlyMetrics.spo2(of: asleep),
        sleepOnset: period.sleepOnset,
        finalWake: period.finalWake,
        timeAsleep: period.timeAsleep,
        timeInBedStart: period.timeInBedStart,
        timeInBedEnd: period.timeInBedEnd
    )
}

/// The night window `time` falls in: local noon to the next local noon in `timeZone` (23 or 25
/// hours across a clock change).
func nightWindow(containing time: Date, in timeZone: TimeZone) -> DateInterval {
    let day = Day(containing: time, in: timeZone)
    let noon = day.midday(in: timeZone)
    return time < noon
        ? DateInterval(start: day.adding(days: -1).midday(in: timeZone), end: noon)
        : DateInterval(start: noon, end: day.adding(days: 1).midday(in: timeZone))
}
