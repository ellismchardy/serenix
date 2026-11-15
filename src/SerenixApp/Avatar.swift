import SwiftUI

/// The profile avatar (spec 002, Profile): an ink circle with the name's first letter in the
/// paper colour, or a person icon with no name (spec 018). Small in the masthead, large at the
/// top of the profile menu.
struct Avatar: View {
    /// The Today view's avatar letter.
    let letter: String?
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(Poster.ink)
            if let letter {
                Text(letter)
                    .font(.system(size: diameter * 0.45, weight: .semibold, design: .rounded))
                    .foregroundStyle(Poster.paper)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: diameter * 0.45))
                    .foregroundStyle(Poster.paper)
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}
