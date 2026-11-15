import SerenixCore
import SwiftUI

/// The week strip under the masthead (spec 002, Week strip; spec 018): the month, ‹ and › to move
/// a week, and seven Days with the Day shown as a solid ink block. It decides nothing; tapping
/// sends the Day back.
struct WeekStripView: View {
    let strip: WeekStrip
    let show: (Day) -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(strip.title.uppercased())
                    .font(Poster.labelFont)
                    .foregroundStyle(Poster.ink)
                Spacer()
                arrow("chevron.left", label: "Earlier week", to: strip.earlierDay)
                arrow("chevron.right", label: "Later week", to: strip.laterDay)
            }
            HStack(spacing: 0) {
                ForEach(strip.days, id: \.day) { day in
                    Button {
                        show(day.day)
                    } label: {
                        VStack(spacing: 4) {
                            Text(day.letter).font(.caption2.weight(.semibold))
                            Text("\(day.number)").font(.subheadline.weight(.bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(foreground(day))
                        .background(day.isShown ? Poster.ink : .clear)
                        .opacity(day.isInRange ? 1 : 0.35)
                    }
                    .buttonStyle(.plain)
                    .disabled(!day.isInRange)
                }
            }
            PosterRule(width: Poster.rowRule, colour: Poster.hairline)
        }
    }

    private func arrow(_ symbol: String, label: String, to day: Day?) -> some View {
        Button {
            if let day { show(day) }
        } label: {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Poster.ink)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(day == nil)
        .opacity(day == nil ? 0.35 : 1)
        .accessibilityLabel(label)
    }

    /// The Day shown reads in paper on the ink block; a Day without a Night is dimmed.
    private func foreground(_ day: WeekStripDay) -> Color {
        day.isShown ? Poster.paper : day.hasNight ? Poster.ink : Poster.secondary
    }
}
