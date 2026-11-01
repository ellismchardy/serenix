import SwiftUI
import UIKit

/// The Look (spec 002): a light grey background with white, rounded cards and soft shadows, and
/// purple as the app's accent, each with a dark version for Dark appearance. Band and Zone colours
/// stay green, amber and red (see `ReadinessBand.colour` and `Zone.colour`). The values are
/// prototype variant F's (`?variant=F`, branch `prototype/homescreen`).
enum Theme {
    /// Behind everything.
    static let background = adaptive(light: 0xF3F2F8, dark: 0x0F0E14)
    /// Cards, round buttons and the sync pill.
    static let card = adaptive(light: 0xFFFFFF, dark: 0x1C1B24)
    /// A soft accent tint, for tracks and icon circles.
    static let accentSoft = adaptive(light: 0xEFEAFE, dark: 0x2A2440)
    /// The app's accent: the avatar, the Day shown, buttons, the pill's outline and the Sleep
    /// Score ring.
    static let accent = adaptive(light: 0x7C5CFF, dark: 0x9B85FF)
    /// Card shadows show in Light only.
    static let shadow = adaptive(light: 0x1A1A1A, lightAlpha: 0.07, dark: 0x000000, darkAlpha: 0)

    /// Corner radius of a card.
    static let cardRadius: CGFloat = 20

    /// A colour that follows the light or dark appearance, from 0xRRGGBB values.
    private static func adaptive(
        light: UInt32,
        lightAlpha: CGFloat = 1,
        dark: UInt32,
        darkAlpha: CGFloat = 1
    ) -> Color {
        Color(
            UIColor {
                $0.userInterfaceStyle == .dark
                    ? uiColor(dark, alpha: darkAlpha) : uiColor(light, alpha: lightAlpha)
            }
        )
    }

    private static func uiColor(_ hex: UInt32, alpha: CGFloat) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension View {
    /// A white (or dark) rounded card with the Look's soft shadow.
    func themeCard() -> some View {
        themeCard(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    /// The card colour and shadow in any shape, e.g. a circle for a round button.
    func themeCard<S: Shape>(_ shape: S) -> some View {
        background(Theme.card, in: shape).shadow(color: Theme.shadow, radius: 12, y: 4)
    }
}
