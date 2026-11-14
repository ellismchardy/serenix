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
