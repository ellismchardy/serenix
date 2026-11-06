import SerenixCore
import SwiftUI

/// Logs a Food Entry (spec 016): calories (required), and optionally protein, fat, carbs and a
/// short name. The time defaults to now on today and to 12:00 on a past Day.
struct FoodEntrySheet: View {
    let day: Day
    let save: (FoodEntry) -> Void
    @State private var time: Date
    @State private var name = ""
    @State private var kilocaloriesText = ""
    @State private var proteinText = ""
    @State private var fatText = ""
    @State private var carbsText = ""
    @Environment(\.dismiss) private var dismiss

    init(day: Day, save: @escaping (FoodEntry) -> Void) {
        self.day = day
        self.save = save
        let today = Day(containing: Date(), in: .current)
        _time = State(initialValue: day == today ? Date() : day.midday(in: .current))
    }

    /// The Food Entry as typed, once calories read.
    private var draft: FoodEntry? {
        guard let kilocalories = Self.number(kilocaloriesText) else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return FoodEntry(
            time: time,
            kilocalories: kilocalories,
            protein: Self.number(proteinText),
            fat: Self.number(fatText),
            carbs: Self.number(carbsText),
            name: trimmed.isEmpty ? nil : trimmed
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name (optional)", text: $name)
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                Section("Calories") {
                    TextField("kcal", text: $kilocaloriesText).keyboardType(.decimalPad)
                }
                Section("Macros (optional)") {
                    TextField("Protein (g)", text: $proteinText).keyboardType(.decimalPad)
                    TextField("Fat (g)", text: $fatText).keyboardType(.decimalPad)
                    TextField("Carbs (g)", text: $carbsText).keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Log Food Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let draft { save(draft) }
                        dismiss()
                    }
                    .disabled(draft == nil)
                }
            }
        }
    }

    /// A typed number in the phone's locale; nil when blank or unreadable.
    private static func number(_ text: String) -> Double? {
        try? Double(text, format: .number)
    }
}
