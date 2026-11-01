import SerenixCore
import SwiftUI

/// The week strip under the top bar (spec 002, Week strip): the month, ‹ and › to move a week,
/// and seven Days with the Day shown highlighted. It decides nothing; tapping sends the Day back.
struct WeekStripView: View {
    let strip: WeekStrip
    let show: (Day) -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(strip.title).font(.headline)
                Spacer()
                arrow("chevron.left", label: "Earlier week", to: strip.earlierDay)
                arrow("chevron.right", label: "Later week", to: strip.laterDay)
            }
            HStack(spacing: 2) {
                ForEach(strip.days, id: \.day) { day in
                    Button {
                        show(day.day)
                    } label: {
                        VStack(spacing: 6) {
                            Text(day.letter).font(.caption)
                            Text("\(day.number)").font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(foreground(day))
                        .background(
                            day.isShown ? Theme.accent : .clear,
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                        .opacity(day.isInRange ? 1 : 0.35)
                    }
                    .buttonStyle(.plain)
                    .disabled(!day.isInRange)
                }
            }
        }
        .padding(14)
        .themeCard()
    }

    private func arrow(_ symbol: String, label: String, to day: Day?) -> some View {
        Button {
            if let day { show(day) }
        } label: {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 30, height: 30)
                .background(Theme.accentSoft, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(day == nil)
        .opacity(day == nil ? 0.35 : 1)
        .accessibilityLabel(label)
    }

    /// The Day shown reads on the accent; a Day without a Night is dimmed.
    private func foreground(_ day: WeekStripDay) -> Color {
        day.isShown ? .white : day.hasNight ? .primary : .secondary
    }
}
