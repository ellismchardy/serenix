import Foundation

/// The Nightly Metrics, each worked out exactly as hr-tracker's `tools/metrics.py` does (methods:
/// hr-tracker `docs/protocol.md#sleep-metrics`), quirks kept so the two give the same numbers
/// (spec 003). Each takes the Sleep Period's History Records with heart rate above 0, oldest
/// first, and is nil when its method has nothing to work on. Means are summed in order, where
/// Python's `fmean` sums exactly; the two differ only in the last digits.
enum NightlyMetrics {
    /// The span Resting HR averages over: 30 minutes, which is also 1,800 records at one a
    /// second. metrics.py `RHR_SPAN`.
    private static let restingHRSpan = 1800
    /// Records between Resting HR start points: one minute at one a second. metrics.py
    /// `resting_hr()`.
    private static let restingHRStep = 60
    /// ms: the shortest and longest RR interval kept for HRV and respiratory rate. metrics.py
    /// `RR_MIN`, `RR_MAX`.
    private static let keptRRIntervals = 600...1600
    /// ms: successive RR differences at least this big are dropped from HRV. metrics.py
    /// `RR_DIFF`.
    private static let largestRRDifference = 200

    /// bpm: the lowest mean heart rate over `restingHRSpan` seconds, trying a start every
    /// `restingHRStep` records (records, not seconds, as metrics.py `resting_hr()` does).
    static func restingHR(of records: [HistoryRecord]) -> Double? {
        guard let last = records.last?.timestamp.timeIntervalSince1970 else { return nil }
        var lowest: Double?
        for start in stride(from: 0, to: records.count, by: restingHRStep) {
            let startTime = records[start].timestamp.timeIntervalSince1970
            let endTime = startTime + Double(restingHRSpan)
            if endTime > last { break }
            // metrics.py looks at most one span plus one step of records ahead.
            let ahead = records[start..<min(records.count, start + restingHRSpan + restingHRStep)]
            let rates = ahead.filter { $0.timestamp.timeIntervalSince1970 < endTime }
                .map(\.heartRate)
            let mean = Double(rates.reduce(0, +)) / Double(rates.count)
            lowest = min(lowest ?? mean, mean)
        }
        return lowest
    }

    /// ms: RMSSD over every RR interval in order, keeping `keptRRIntervals` and successive
    /// differences under `largestRRDifference`. metrics.py `rmssd()`.
    static func hrv(of records: [HistoryRecord]) -> Double? {
        let kept = records.flatMap(\.rrIntervals).filter { keptRRIntervals.contains($0) }
        let differences = zip(kept, kept.dropFirst())
            .map { $1 - $0 }
            .filter { abs($0) < largestRRDifference }
        guard !differences.isEmpty else { return nil }
        let meanSquare =
            Double(differences.map { $0 * $0 }.reduce(0, +)) / Double(differences.count)
        return meanSquare.squareRoot()
    }

    /// Seconds in each respiratory-rate window. metrics.py `RESP_WIN`.
    private static let respiratoryWindow = 300
    /// Kept RR intervals a window needs for a respiratory rate. metrics.py `RESP_MIN_BEATS`.
    private static let fewestRespiratoryBeats = 200
    /// Hz: the band breathing is looked for in, 7–24 breaths a minute. metrics.py `RESP_BAND`.
    private static let breathingBand = 0.12...0.4
    /// Seconds between tachogram samples once resampled (4 Hz). metrics.py `RESAMPLE`.
    private static let resampleInterval = 0.25

    /// Breaths a minute: the mean over every `respiratoryWindow` from Sleep Onset to Final Wake
    /// with at least `fewestRespiratoryBeats` kept RR intervals of that window's breathing peak.
    /// metrics.py `resp_rate()`; windows start on whole seconds and stop one window short of
    /// `finalWake`, as there.
    static func respiratoryRate(
        of records: [HistoryRecord],
        sleepOnset: Date,
        finalWake: Date
    ) -> Double? {
        let first = Int(sleepOnset.timeIntervalSince1970)
        let stop = Int(finalWake.timeIntervalSince1970) - respiratoryWindow
        let rates = stride(from: first, to: stop, by: respiratoryWindow).compactMap { start in
            let window = Double(start)..<Double(start + respiratoryWindow)
            let intervals =
                records
                .filter { window.contains($0.timestamp.timeIntervalSince1970) }
                .flatMap(\.rrIntervals)
                .filter { keptRRIntervals.contains($0) }
            return intervals.count >= fewestRespiratoryBeats ? breathingPeak(intervals) : nil
        }
        guard !rates.isEmpty else { return nil }
        return rates.reduce(0, +) / Double(rates.count)
    }

    /// Breaths a minute in one window of RR intervals (ms): the strongest frequency in
    /// `breathingBand` of the RR tachogram, linearly resampled every `resampleInterval` seconds,
    /// mean removed and Hann-windowed. metrics.py `resp_peak()`. Nil when the window is too short
    /// to hold a frequency in the band, so it's left out rather than counted as 0.
    private static func breathingPeak(_ intervals: [Int]) -> Double? {
        var beatTimes: [Double] = []
        var elapsed = 0.0
        for interval in intervals {
            elapsed += Double(interval) / 1000
            beatTimes.append(elapsed)
        }
        let count = Int(elapsed / resampleInterval)
        guard intervals.count >= 2, count >= 2 else { return nil }
        var samples: [Double] = []
        var beat = 0
        for index in 0..<count {
            let time = Double(index) * resampleInterval
            while beat < beatTimes.count - 2, beatTimes[beat + 1] < time { beat += 1 }
            let fraction = min(
                1,
                max(0, (time - beatTimes[beat]) / (beatTimes[beat + 1] - beatTimes[beat]))
            )
            let from = Double(intervals[beat])
            samples.append(from + fraction * (Double(intervals[beat + 1]) - from))
        }
        let mean = samples.reduce(0, +) / Double(count)
        let windowed = samples.enumerated().map { index, value in
            (value - mean) * (0.5 - 0.5 * cos(2 * .pi * Double(index) / Double(count - 1)))
        }
        // A plain DFT over only the bins whose frequency (bin ÷ span Hz) is in the band, the
        // same loop metrics.py runs.
        let span = Double(count) * resampleInterval
        let lowest = Int((breathingBand.lowerBound * span).rounded(.up))
        let highest = Int((breathingBand.upperBound * span).rounded(.down))
        guard lowest <= highest else { return nil }
        var best: (power: Double, hertz: Double)?
        for bin in lowest...highest {
            let angle = 2 * .pi * Double(bin) / Double(count)
            var real = 0.0
            var imaginary = 0.0
            for (index, value) in windowed.enumerated() {
                real += value * cos(angle * Double(index))
                imaginary += value * sin(angle * Double(index))
            }
            let power = real * real + imaginary * imaginary
            if best.map({ power > $0.power }) ?? true {
                best = (power, Double(bin) / span)
            }
        }
        return best.map { $0.hertz * 60 }
    }

    /// Seconds between two records in an SpO2 Window that still count as one window. metrics.py
    /// `SPO2_GAP`.
    private static let longestSpO2Gap = 5.0
    /// %: the SpO2 readings kept; other values inside a window look like status bits.
    /// metrics.py `spo2_windows()`.
    private static let keptSpO2Readings = 85...100

    /// %: each SpO2 Window's median of its kept readings, then the mean of the windows that have
    /// one. metrics.py `spo2_windows()` and `main()`.
    static func spo2(of records: [HistoryRecord]) -> Double? {
        var windows: [[HistoryRecord]] = []
        for record in records where record.isInSpO2Window {
            if let last = windows.last?.last,
                record.timestamp.timeIntervalSince(last.timestamp) <= longestSpO2Gap
            {
                windows[windows.count - 1].append(record)
            } else {
                windows.append([record])
            }
        }
        let medians = windows.compactMap { window -> Double? in
            let readings = window.map(\.spo2).filter { keptSpO2Readings.contains($0) }
            return readings.isEmpty ? nil : median(of: readings.map(Double.init))
        }
        guard !medians.isEmpty else { return nil }
        return medians.reduce(0, +) / Double(medians.count)
    }

    /// °C: the mean of every record's skin temperature, including the minutes while the Strap
    /// warms up. metrics.py `main()`.
    static func skinTemperature(of records: [HistoryRecord]) -> Double? {
        guard !records.isEmpty else { return nil }
        return records.map(\.skinTemperature).reduce(0, +) / Double(records.count)
    }
}
