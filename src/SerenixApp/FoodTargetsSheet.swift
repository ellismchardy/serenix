import SerenixCore
import SwiftUI

/// Sets the Calorie Target and, optionally, protein and fat in place of the suggested Macro
/// Targets (spec 016). Carbs always fill what's left. A blank field means none (the Calorie
/// Target) or the suggestion (protein, fat). Anything Serenix would refuse shows why and can't
/// be saved.
struct FoodTargetsSheet: View {
    /// The suggested Macro Targets at a Calorie Target, from the core; nil without Trend Weight.
    let suggested: (Double) -> MacroTargets?
    /// Saves the targets as typed.
    let save: (FoodTargets) -> Void
    @State private var calorieTargetText: String
    @State private var proteinText: String
    @State private var fatText: String
    @Environment(\.dismiss) private var dismiss

    init(
        targets: FoodTargets,
        suggested: @escaping (Double) -> MacroTargets?,
        save: @escaping (FoodTargets) -> Void
    ) {
        self.suggested = suggested
        self.save = save
        _calorieTargetText = State(initialValue: targets.calorieTarget.map(NumberText.text) ?? "")
        _proteinText = State(initialValue: targets.proteinOverride.map(NumberText.text) ?? "")
        _fatText = State(initialValue: targets.fatOverride.map(NumberText.text) ?? "")
    }

    private var calorieTarget: Double? { NumberText.number(calorieTargetText) }
    private var proteinOverride: Double? { NumberText.number(proteinText) }
    private var fatOverride: Double? { NumberText.number(fatText) }

    /// A field has text that doesn't read as a number.
    private var unreadable: Bool {
        (!calorieTargetText.isEmpty && calorieTarget == nil)
            || (!proteinText.isEmpty && proteinOverride == nil)
            || (!fatText.isEmpty && fatOverride == nil)
    }

    /// The suggestions at the typed Calorie Target, for the placeholders and the check.
    private var suggestion: MacroTargets? { calorieTarget.flatMap(suggested) }

    private var calorieRefusal: CalorieTargetRefusal? {
        calorieTarget.flatMap(CalorieTarget.refusal)
    }

    /// Why the overrides can't be saved, as the core decides.
    private var overrideRefusal: MacroOverrideRefusal? {
        MacroTargets.overrideRefusal(
            proteinOverride: proteinOverride,
            fatOverride: fatOverride,
            calorieTarget: calorieTarget,
            suggested: suggestion
        )
    }

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
                Section {
                    TextField(placeholder("Protein", suggestion?.protein), text: $proteinText)
                        .keyboardType(.decimalPad)
                    TextField(placeholder("Fat", suggestion?.fat), text: $fatText)
                        .keyboardType(.decimalPad)
                    Button("Use suggested") {
                        proteinText = ""
                        fatText = ""
                    }
                    .disabled(proteinText.isEmpty && fatText.isEmpty)
                } header: {
                    Text("Macro Targets")
                } footer: {
                    Text("Leave protein or fat blank to use the suggestion. Carbs fill the rest.")
                }
                if let message = calorieRefusal?.message ?? overrideRefusal?.message {
                    Text(message).foregroundStyle(.red)
                }
            }
            .navigationTitle("Targets")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save(
                            FoodTargets(
                                calorieTarget: calorieTarget,
                                proteinOverride: proteinOverride,
                                fatOverride: fatOverride
                            )
                        )
                        dismiss()
                    }
                    .disabled(calorieRefusal != nil || overrideRefusal != nil || unreadable)
                }
            }
        }
    }

    /// "Protein (suggested 176 g)", or "Protein (g)" with no suggestion.
    private func placeholder(_ name: String, _ grams: Double?) -> String {
        grams.map { "\(name) (suggested \(NumberText.text($0.rounded())) g)" } ?? "\(name) (g)"
    }
}
