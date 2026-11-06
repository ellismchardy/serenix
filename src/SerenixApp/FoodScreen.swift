import SerenixCore
import SwiftUI

/// The Body tab's Food view (spec 016): one Day's Food Entries and Intake, any past Day by the
/// date picker, and + to log a Food Entry. It draws the Food view and decides nothing.
struct FoodScreen: View {
    @ObservedObject var store: FoodStore
    /// The Day picked; nil is today, whatever today is when the view draws, so it rolls over at
    /// midnight as the Today and Sleep tabs do.
    @State private var pickedDay: Day?
    @State private var showsEntrySheet = false
    /// The row being edited, while its sheet shows.
    @State private var editing: FoodEntryRow?

    var body: some View {
        let today = Day(containing: Date(), in: .current)
        let view = FoodView(
            foodEntries: store.entries,
            day: pickedDay ?? today,
            now: Date(),
            timeZone: .current
        )
        VStack(alignment: .leading, spacing: 12) {
            DatePicker(
                "Day",
                selection: Binding(
                    get: { view.day.midday(in: .current) },
                    // Picking today goes back to following today.
                    set: {
                        let picked = Day(containing: $0, in: .current)
                        pickedDay = picked == today ? nil : picked
                    }
                ),
                in: ...Date(),
                displayedComponents: .date
            )
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Self.whole(view.intake.kilocalories)) kcal")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text(
                    "Protein \(Self.whole(view.intake.protein)) g · Fat \(Self.whole(view.intake.fat)) g · Carbs \(Self.whole(view.intake.carbs)) g"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .themeCard()
            if view.entries.isEmpty {
                Text("Nothing logged on this Day.").foregroundStyle(.secondary)
            }
            // Tap to edit or delete; holding also offers Delete (spec 016: any Food Entry can be
            // edited or deleted).
            ForEach(Self.rows(for: view.entries, in: store.rows)) { row in
                Button {
                    editing = row
                } label: {
                    entryRow(row.entry)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Delete", role: .destructive) { store.delete(row.id) }
                }
            }
            Button {
                showsEntrySheet = true
            } label: {
                Label("Log a Food Entry", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
        .sheet(isPresented: $showsEntrySheet) {
            FoodEntrySheet(day: view.day) { store.add($0) }
        }
        .sheet(item: $editing) { row in
            FoodEntrySheet(
                day: view.day,
                editing: row.entry,
                delete: { store.delete(row.id) },
                save: { store.replace(row.id, with: $0) }
            )
        }
        .alert(
            "Body data",
            isPresented: Binding(
                get: { store.failure != nil },
                set: { if !$0 { store.failure = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.failure ?? "")
        }
    }

    /// The stored rows for `entries`, in their order: each entry paired with a row holding the
    /// same values, each row used once, so identical entries still get their own rows. Both come
    /// from `store.rows`, so every entry has a row.
    private static func rows(for entries: [FoodEntry], in rows: [FoodEntryRow]) -> [FoodEntryRow] {
        var unused = rows
        return entries.compactMap { entry in
            guard let index = unused.firstIndex(where: { $0.entry == entry }) else { return nil }
            return unused.remove(at: index)
        }
    }

    /// One Food Entry: its time and name, calories, and the macros it has.
    private func entryRow(_ entry: FoodEntry) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name ?? "Food Entry").font(.headline)
                Text(entry.time.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Self.whole(entry.kilocalories)) kcal")
                let macros = [("P", entry.protein), ("F", entry.fat), ("C", entry.carbs)]
                    .compactMap { label, grams in grams.map { "\(label) \(Self.whole($0)) g" } }
                if !macros.isEmpty {
                    Text(macros.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .themeCard()
    }

    /// A value as a whole number, as kcal and grams are shown (spec 016).
    private static func whole(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }
}
