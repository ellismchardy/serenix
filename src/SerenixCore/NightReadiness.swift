import Foundation

/// Everything the Today view needs about one Night's Readiness (specs 002, 008, 009), worked out
/// once so the ring, advice and popup can't disagree, and reusable for any Day.
struct NightReadiness {
    /// HRV's and Sleeping HR's Baselines; nil when there's no Night that Day.
    let baselines: (hrv: Baseline, sleepingHR: Baseline)?
    /// "n" of "n/4": the Nights so far while Calibrating; nil once both Baselines are formed.
    let calibratingNightsSoFar: Int?
    /// The Load of the Day before the Day: "yesterday" in Readiness (spec 008, Inputs).
    let previousDayLoad: Int?
    let previousDayTypicalLoad: TypicalLoad
    /// The Night's Sleep Need (spec 009), worked out each time from the Nights and birth year.
    let sleepNeed: SleepNeed
    /// Nil while Calibrating, with no Night, or when Readiness is missing.
    let breakdown: Readiness.Breakdown?

    var score: Int? { breakdown?.score }

    init(for day: Day, among nights: [Night], dayLoads: [DayLoad], birthYear: Int?) {
        let night = nights.first { $0.day == day }
        let baselines = night.map { night in
            (
                hrv: Baseline(.hrv, for: night, among: nights),
                sleepingHR: Baseline(.sleepingHR, for: night, among: nights)
            )
        }
        self.baselines = baselines
        // Readiness is Calibrating while either Baseline it's drawn from is (spec 002, Rings).
        // "n/4" counts the Nights so far, by the metric with the fewest.
        calibratingNightsSoFar = baselines.flatMap { baselines in
            baselines.hrv.isCalibrating || baselines.sleepingHR.isCalibrating
                ? 1 + min(baselines.hrv.earlierNights, baselines.sleepingHR.earlierNights) : nil
        }
        let previousDay = day.adding(days: -1)
        previousDayLoad = dayLoads.first { $0.day == previousDay }?.load
        previousDayTypicalLoad = typicalLoad(for: previousDay, among: dayLoads)
        sleepNeed = SleepNeed(for: day, among: nights, birthYear: birthYear)
        breakdown =
            if calibratingNightsSoFar == nil, let night, let baselines {
                Readiness.breakdown(
                    of: night,
                    hrv: baselines.hrv,
                    sleepingHR: baselines.sleepingHR,
                    sleepNeed: sleepNeed.sleepNeed,
                    previousDayLoad: previousDayLoad,
                    typicalLoad: previousDayTypicalLoad
                )
            } else {
                nil
            }
    }
}
