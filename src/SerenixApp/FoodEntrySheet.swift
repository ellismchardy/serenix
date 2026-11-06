import SerenixCore
import SwiftUI

/// Logs or edits a Food Entry (spec 016): calories (required), and optionally protein, fat, carbs
/// and a short name. A new one's time defaults to now on today and to 12:00 on a past Day. An
/// entry Serenix would refuse shows why and can't be saved.
struct FoodEntrySheet: View {
    let day: Day
    /// True when editing an existing Food Entry.
    let isEditing: Bool
    let save: (FoodEntry) -> Void
    /// Deletes the Food Entry being edited; nil for a new one.
    let delete: (() -> Void)?
    @State private var time: Date
    @State private var name = ""
    @State private var kilocaloriesText = ""
    @State private var proteinText = ""
    @State private var fatText = ""
    @State private var carbsText = ""
    @Environment(\.dismiss) private var dismiss

    init(
        day: Day,
        editing existing: FoodEntry? = nil,
        delete: (() -> Void)? = nil,
        save: @escaping (FoodEntry) -> Void
    ) {
        self.day = day
        isEditing = existing != nil
        self.delete = delete
        self.save = save
        let today = Day(containing: Date(), in: .current)
        _time = State(
            initialValue: existing?.time ?? (day == today ? Date() : day.midday(in: .current))
        )
        if let existing {
            _name = State(initialValue: existing.name ?? "")
            _kilocaloriesText = State(initialValue: Self.text(existing.kilocalories))
            _proteinText = State(initialValue: existing.protein.map(Self.text) ?? "")
            _fatText = State(initialValue: existing.fat.map(Self.text) ?? "")
            _carbsText = State(initialValue: existing.carbs.map(Self.text) ?? "")
        }
    }

    private var refusal: FoodEntryRefusal? { draft?.refusal(now: Date()) }

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
                if let refusal {
                    Text(refusal.message).foregroundStyle(.red)
                }
            }
            .navigationTitle(isEditing ? "Edit Food Entry" : "Log Food Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                if let delete {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Delete Food Entry", role: .destructive) {
                            delete()
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let draft, refusal == nil { save(draft) }
                        dismiss()
                    }
                    .disabled(draft == nil || refusal != nil)
                }
            }
        }
    }

    /// A stored value as the field shows it, without a needless ".0".
    private static func text(_ value: Double) -> String {
        value.formatted(.number.grouping(.never))
    }

    /// A typed number in the phone's locale; nil when blank or unreadable.
    private static func number(_ text: String) -> Double? {
        try? Double(text, format: .number)
    }
}
