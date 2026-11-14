import SerenixCore
import SwiftUI

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
