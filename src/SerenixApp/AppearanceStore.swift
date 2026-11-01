import SwiftUI
import UIKit

/// Light, dark, or following iOS (spec 002, Look).
enum Appearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// The window's style: System leaves it to iOS (`.unspecified`).
    var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }
}

/// The Appearance setting, kept in UserDefaults on this phone; System until changed.
@MainActor
final class AppearanceStore: ObservableObject {
    @Published var selected: Appearance {
        didSet {
            UserDefaults.standard.set(selected.rawValue, forKey: appearanceKey)
            apply()
        }
    }

    init() {
        _selected = Published(
            initialValue: UserDefaults.standard.string(forKey: appearanceKey)
                .flatMap(Appearance.init(rawValue:)) ?? .system
        )
    }

    /// Sets every window's style, sheets included, so a change shows at once. SwiftUI's
    /// `preferredColorScheme` can miss going back to System on a sheet that's already open.
    func apply() {
        for scene in UIApplication.shared.connectedScenes {
            for window in (scene as? UIWindowScene)?.windows ?? [] {
                window.overrideUserInterfaceStyle = selected.userInterfaceStyle
            }
        }
    }
}

private let appearanceKey = "appearance"
