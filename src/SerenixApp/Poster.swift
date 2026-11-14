import SerenixCore
import SwiftUI
import UIKit

/// The Poster look (spec 018): paper and ink, one signal red, ruled sections instead of cards,
/// and a headline number with its verdict. Values are prototype concept M's (branch
/// `prototype/performance-home`); Dark swaps paper and ink and keeps red, green and amber.
enum Poster {
    /// Behind everything: off-white in Light, near-black in Dark.
    static let paper = adaptive(light: 0xF2F0EB, dark: 0x0B0B0B)
    /// Type and heavy rules: the opposite of the paper.
    static let ink = adaptive(light: 0x111111, dark: 0xF2F0EB)
    /// The one accent: verdicts, headline bars, the Day's Load.
    static let red = fixed(0xE3241B)
    /// In range, In band, On pace.
    static let green = fixed(0x138A4B)
    /// Watch, short Time Asleep, warnings.
    static let amber = fixed(0xC27C0E)
    /// Rules between rows.
    static let hairline = adaptive(light: 0xC9C6BD, dark: 0x2A2A2A)
    /// The empty part of a bar.
    static let track = adaptive(light: 0xDEDAD0, dark: 0x262626)
    /// Captions, notes and labels.
    static let secondary = adaptive(light: 0x555555, dark: 0xA8A59C)
    /// A waiting verdict: grey, so it never reads as a warning (spec 018, Verdicts).
    static let waiting = fixed(0x8A877E)

    /// The masthead's rule across the top, points.
    static let mastheadRule: CGFloat = 6
    /// The heavy rule over each section, points.
    static let sectionRule: CGFloat = 2
    /// The hairline between rows, points.
    static let rowRule: CGFloat = 1

    /// A tab's headline number size, points (prototype concept M's popup and Body headline).
    static let headlineSize: CGFloat = 120
    /// The Body tab's headline number size, points: smaller, so "82.4 kg" and "1,840 kcal" fit.
    static let bodyHeadlineSize: CGFloat = 88

    /// A tab's headline number: very large, tight and bold.
    static func headlineFont(size: CGFloat = headlineSize) -> Font {
        .system(size: size, weight: .bold)
    }

    /// A verdict: condensed bold italic (always written in capitals).
    static func verdictFont(size: CGFloat = 40) -> Font {
        .system(size: size, weight: .heavy).width(.condensed).italic()
    }

    /// A section's name and a masthead's words: small and bold.
    static let labelFont = Font.footnote.weight(.semibold)

    /// The verdict's colour: red for the user's state, grey while waiting for data.
    static func colour(of verdict: Verdict) -> Color {
        switch verdict.kind {
        case .state: red
        case .waiting: waiting
        }
    }

    /// A colour that follows the light or dark appearance, from 0xRRGGBB values.
    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? uiColor(dark) : uiColor(light) })
    }

    /// The same colour in Light and Dark.
    private static func fixed(_ hex: UInt32) -> Color {
        Color(uiColor(hex))
    }

    private static func uiColor(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// A full-width rule in ink.
struct PosterRule: View {
    var width: CGFloat = Poster.sectionRule
    var colour: Color = Poster.ink

    var body: some View {
        Rectangle().fill(colour).frame(height: width).frame(maxWidth: .infinity)
    }
}

/// The 6 pt rule across the top, the screen or popup's name on the left and its Day or Night on
/// the right, with any buttons after it (spec 018, Masthead).
struct Masthead<Trailing: View>: View {
    let title: String
    let detail: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PosterRule(width: Poster.mastheadRule)
            HStack(spacing: 12) {
                Text(title).font(Poster.labelFont)
                Spacer(minLength: 8)
                Text(detail).font(Poster.labelFont)
                trailing()
            }
            .foregroundStyle(Poster.ink)
            .lineLimit(1)
        }
    }
}

extension Masthead where Trailing == EmptyView {
    init(title: String, detail: String) {
        self.init(title: title, detail: detail) { EmptyView() }
    }
}

/// A section: a heavy rule with its name in small bold type on the left and an optional note on
/// the right, then its rows (spec 018, Paper).
struct RuledSection<Content: View>: View {
    let name: String
    var note: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PosterRule()
            HStack(alignment: .firstTextBaseline) {
                Text(name.uppercased()).font(Poster.labelFont).foregroundStyle(Poster.ink)
                Spacer(minLength: 8)
                if let note {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(Poster.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A row inside a section, with a hairline under it.
struct RuledRow<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 9) {
            content().frame(maxWidth: .infinity, alignment: .leading)
            PosterRule(width: Poster.rowRule, colour: Poster.hairline)
        }
    }
}

/// A short status as white text on a solid colour: a Zone, band, pace badge or hold state.
struct PosterTag: View {
    let text: String
    let colour: Color

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.bold).monospaced())
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(colour)
            .foregroundStyle(.white)
    }
}

/// A tab or popup's headline: the number, its verdict beside it, and a caption under it (spec
/// 018, Headline).
struct PosterHeadline: View {
    let number: String
    var unit: String?
    let verdict: Verdict?
    var caption: String?
    var size: CGFloat = Poster.headlineSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline, spacing: 12) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(number)
                        .font(Poster.headlineFont(size: size))
                        .tracking(-size * 0.06)
                        .minimumScaleFactor(0.4)
                    if let unit {
                        Text(unit).font(.title2.weight(.bold))
                    }
                }
                .foregroundStyle(Poster.ink)
                .lineLimit(1)
                if let verdict {
                    Text(verdict.text)
                        .font(Poster.verdictFont(size: size / 3))
                        .foregroundStyle(Poster.colour(of: verdict))
                        .minimumScaleFactor(0.5)
                        .lineLimit(2)
                }
            }
            if let caption {
                Text(caption)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Poster.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// A flat bar: a track, a fill from 0 to `fill` (0 to 1), and an optional ink tick at `tick`.
struct PosterBar: View {
    let fill: Double
    var tick: Double?
    var colour: Color = Poster.red
    var height: CGFloat = 16

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Rectangle().fill(Poster.track)
                Rectangle().fill(colour).frame(width: width * Self.clamped(fill))
                if let tick {
                    Rectangle()
                        .fill(Poster.ink)
                        .frame(width: 3, height: height + 10)
                        .offset(x: width * Self.clamped(tick) - 1.5)
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    private static func clamped(_ value: Double) -> Double { min(max(value, 0), 1) }
}

/// Options as equal cells under a heavy border; the picked one a solid ink block with paper
/// text, like the tab bar (spec 018).
struct SegmentedBar<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    @Binding var selection: Value
    /// What the bar picks, for VoiceOver, e.g. "Activity Level"; each cell keeps its own name.
    var label: String?

    var body: some View {
        bar
            .accessibilityElement(children: .contain)
            .accessibilityLabel(label ?? "")
    }

    private var bar: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let picked = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    Text(option.label)
                        .font(.footnote.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(picked ? Poster.ink : Color.clear)
                        .foregroundStyle(picked ? Poster.paper : Poster.ink)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(picked ? .isSelected : [])
            }
        }
        .overlay(Rectangle().stroke(Poster.ink, lineWidth: Poster.sectionRule))
    }
}

/// A full-width block button: solid in its colour with paper text, or outlined.
struct BlockButtonStyle: ButtonStyle {
    var colour: Color = Poster.ink
    var outlined = false

    func makeBody(configuration: Configuration) -> some View {
        BlockButton(
            configuration: configuration,
            colour: colour,
            outlined: outlined
        )
    }

    /// The block itself, a view so it can read whether the button is enabled.
    private struct BlockButton: View {
        let configuration: Configuration
        let colour: Color
        let outlined: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(outlined ? Color.clear : colour)
                .foregroundStyle(outlined ? colour : Poster.paper)
                .overlay(Rectangle().stroke(colour, lineWidth: Poster.sectionRule))
                // Pressed and disabled both fade it, as the system buttons do.
                .opacity(!isEnabled ? 0.35 : configuration.isPressed ? 0.7 : 1)
        }
    }
}

/// A sheet's last rows: Save as a solid ink block and, when there is one, the destructive
/// action as a red block (spec 018, Sheets).
struct SheetActions: View {
    let saveDisabled: Bool
    let save: () -> Void
    var destructive: (title: String, action: () -> Void)?

    var body: some View {
        Section {
            VStack(spacing: 10) {
                Button("Save", action: save)
                    .buttonStyle(BlockButtonStyle())
                    .disabled(saveDisabled)
                if let destructive {
                    Button(destructive.title, role: .destructive, action: destructive.action)
                        .buttonStyle(BlockButtonStyle(colour: Poster.red))
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
        }
    }
}

extension View {
    /// A sheet's form in the Poster look (spec 018, Sheets): paper behind it, ink controls.
    /// Each section adds `posterRows()`, so its fields are ruled rows on the paper.
    func posterForm() -> some View {
        scrollContentBackground(.hidden)
            .background(Poster.paper.ignoresSafeArea())
            .tint(Poster.ink)
    }

    /// A form section's rows on the paper, ruled by hairlines.
    func posterRows() -> some View {
        listRowBackground(Poster.paper).listRowSeparatorTint(Poster.hairline)
    }
}
