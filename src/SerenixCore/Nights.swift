import Foundation

/// The Nights found in `records`, each dated by the local date of its Final Wake in `timeZone`
/// (spec 003). Records are grouped into night windows, local noon to the next local noon, and
/// each window gives at most one Night: its main Sleep Period. The order of `records` and any
/// repeats don't matter. Oldest Night first.
public func nights(from records: [HistoryRecord], in timeZone: TimeZone) -> [Night] {
    var seen = Set<String>()
    let unique = records.filter { seen.insert($0.identity).inserted }
    let byWindow = Dictionary(grouping: unique) {
        nightWindowEnd(containing: $0.timestamp, in: timeZone)
    }
    return byWindow.values
        .compactMap { windowRecords -> Night? in
            let sorted = windowRecords.sorted {
                ($0.timestamp, $0.recordCounter) < ($1.timestamp, $1.recordCounter)
            }
            guard let period = SleepPeriod(records: sorted) else { return nil }
            // The Nightly Metrics use the Sleep Period's records with a heart rate (metrics.py).
            let asleep = sorted.filter {
                $0.timestamp >= period.sleepOnset && $0.timestamp < period.finalWake
                    && $0.heartRate > 0
            }
            return Night(
                day: Day(containing: period.finalWake, in: timeZone),
                restingHR: NightlyMetrics.restingHR(of: asleep),
                hrv: NightlyMetrics.hrv(of: asleep),
                skinTemperature: NightlyMetrics.skinTemperature(of: asleep),
                sleepOnset: period.sleepOnset,
                finalWake: period.finalWake,
                timeAsleep: period.timeAsleep,
                timeInBedStart: period.timeInBedStart,
                timeInBedEnd: period.timeInBedEnd
            )
        }
        .sorted { $0.day < $1.day }
}

/// The Day whose local noon ends the night window `time` falls in.
private func nightWindowEnd(containing time: Date, in timeZone: TimeZone) -> Day {
    let day = Day(containing: time, in: timeZone)
    return time < day.midday(in: timeZone) ? day : day.adding(days: 1)
}
