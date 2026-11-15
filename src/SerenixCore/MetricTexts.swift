/// The fixed texts on each metric's popup (spec 011, Text): what the metric is, and what tends
/// to move it. The same every Night or Day.
enum MetricTexts {
    /// "What it is" for a Nightly Metric.
    static func whatItIs(_ metric: NightlyMetric) -> String {
        switch metric {
        case .sleepingHR:
            "Your lowest sustained heart rate while asleep. Lower than usual is fine; a rise of a "
                + "few bpm over your Baseline often comes with a late meal, alcohol, illness or "
                + "hard training."
        case .hrv:
            "How much the time between your heartbeats varies while you sleep, as RMSSD. It's "
                + "personal, so compare it only with your own Baseline. Higher than usual is "
                + "generally a good sign; a drop well below it is worth noticing."
        case .respiratoryRate:
            "Breaths per minute while you sleep. It barely changes from Night to Night, so even "
                + "a small rise above your Baseline stands out."
        case .skinTemperature:
            "The temperature of the skin under the Strap while you sleep. Only the change from "
                + "your Baseline matters: the number itself depends on the room, your bedding and "
                + "how the Strap sits."
        case .spo2:
            "How much oxygen your blood is carrying, measured in short SpO2 Windows while you "
                + "sleep. It's judged against fixed levels, not a Baseline."
        }
    }

    /// "What moves it" for a Nightly Metric, in order.
    static func whatMovesIt(_ metric: NightlyMetric) -> [String] {
        switch metric {
        case .sleepingHR:
            [
                "Alcohol", "A late, heavy meal", "Illness coming on",
                "Hard training the day before", "A warm bedroom",
            ]
        case .hrv:
            ["Alcohol", "Short or broken sleep", "Illness", "Hard training", "Stress"]
        case .respiratoryRate:
            ["Illness, especially of the chest or airways", "Being at altitude", "Alcohol"]
        case .skinTemperature:
            [
                "Fever or illness", "The menstrual cycle", "Room temperature and bedding",
                "How tightly the Strap is worn",
            ]
        case .spo2:
            ["Being at altitude", "Pauses in breathing during sleep", "A loose Strap"]
        }
    }

    /// "What it is" for Resting HR, which isn't a Nightly Metric.
    static let restingHRWhatItIs =
        "Your lowest sustained heart rate on a Day while awake and still, outside your Sleep "
        + "Period. Load is worked out against it. It has no Baseline or Zone, so it isn't coloured."

    /// "What moves it" for Resting HR, in order.
    static let restingHRWhatMovesIt = [
        "Caffeine", "Stress", "How still you were during the Day", "Fitness, over weeks",
    ]
}
