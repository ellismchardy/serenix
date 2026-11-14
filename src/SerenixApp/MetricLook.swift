import SerenixCore
import SwiftUI

extension NightlyMetric {
    /// The SF Symbol in its popup's heading.
    var icon: String {
        switch self {
        case .sleepingHR: "heart"
        case .hrv: "waveform.path.ecg"
        case .respiratoryRate: "lungs"
        case .skinTemperature: "thermometer.medium"
        case .spo2: "drop"
        }
    }
}

extension Zone {
    /// The Zone's colour (spec 018, Colour): the Poster look's green, amber and red.
    var colour: Color {
        switch self {
        case .inRange: Poster.green
        case .watch: Poster.amber
        case .outOfRange: Poster.red
        }
    }
}
