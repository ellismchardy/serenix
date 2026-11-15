import SerenixCore
import SwiftUI

extension ReadinessBand {
    /// The band's colour (spec 018, Colour): the Poster look's green, amber and red. Missing
    /// Readiness has no band and no colour.
    var colour: Color {
        switch self {
        case .ready: Poster.green
        case .steady: Poster.amber
        case .takeItEasy: Poster.red
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

extension HRZone {
    /// Cool to hot, HR Zone 1 to 5, in the Poster look's colours (spec 018): grey, blue, green,
    /// amber, red.
    var colour: Color {
        switch self {
        case .one: Poster.hrZoneOne
        case .two: Poster.hrZoneTwo
        case .three: Poster.green
        case .four: Poster.amber
        case .five: Poster.red
        }
    }
}
