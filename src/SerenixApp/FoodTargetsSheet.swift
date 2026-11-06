import SerenixCore
import SwiftUI

/// Sets the Calorie Target (spec 016): kcal a Day, from 800 to 6,000, or none. A number Serenix
/// would refuse shows why and can't be saved.
struct FoodTargetsSheet: View {
    let save: (Double?) -> Void
    @State private var calorieTargetText: String
    @Environment(\.dismiss) private var dismiss

    init(calorieTarget: Double?, save: @escaping (Double?) -> Void) {
        self.save = save
        _calorieTargetText = State(
            initialValue: calorieTarget.map { $0.formatted(.number.grouping(.never)) } ?? ""
        )
    }

    /// The Calorie Target as typed; nil when the field is blank, which clears it.
    private var calorieTarget: Double? { try? Double(calorieTargetText, format: .number) }

    /// The field has text that doesn't read as a number.
    private var unreadable: Bool { !calorieTargetText.isEmpty && calorieTarget == nil }

    private var refusal: CalorieTargetRefusal? { calorieTarget.flatMap(CalorieTarget.refusal) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("kcal a Day", text: $calorieTargetText).keyboardType(.decimalPad)
                } header: {
                    Text("Calorie Target")
                } footer: {
                    Text("Leave it blank for no Calorie Target.")
                }
                if let refusal {
                    Text(refusal.message).foregroundStyle(.red)
                }
            }
            .navigationTitle("Targets")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save(calorieTarget)
                        dismiss()
                    }
                    .disabled(refusal != nil || unreadable)
                }
            }
        }
    }
}
