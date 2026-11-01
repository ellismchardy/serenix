import SwiftUI

/// The profile avatar (spec 002, Profile): a circle with the name's first letter, or a person
/// icon with no name. Small in the top bar, large at the top of the profile menu.
struct Avatar: View {
    /// The Today view's avatar letter.
    let letter: String?
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(Color.accentColor)
            if let letter {
                Text(letter)
                    .font(.system(size: diameter * 0.45, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: diameter * 0.45))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}
