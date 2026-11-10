import SerenixCore
import SwiftUI

/// Sets the Calorie Target and, optionally, protein and fat in place of the suggested Macro
/// Targets (spec 016). Carbs always fill what's left. A blank field means none (the Calorie
/// Target) or the suggestion (protein, fat). Anything Serenix would refuse shows why and can't
/// be saved.
struct FoodTargetsSheet: View {
    /// The suggested Macro Targets at a Calorie Target, from the core; nil without Trend Weight.
    let suggested: (Double) -> MacroTargets?
    /// What the starting estimate of Expenditure lacks, from the Food view (spec 017).
    let missingForExpenditure: [ExpenditureInput]
    /// What the window of logged data says Expenditure is; nil without enough data.
    let windowFigure: Double?
    /// The Expenditure the suggestion starts from, kcal a Day; nil without one.
    let expenditure: Double?
    /// The Calorie Target that meets the Pace at this Expenditure; nil without Expenditure.
    let suggestedCalorieTarget: Double?
    /// The Pace can't be met safely at this Expenditure (spec 017, floor).
    let paceNotSafelyReachable: Bool
    /// Spec 015's easier goal, when one is on offer.
    let easierGoal: FoodScreen.EasierGoal?
    /// Asks for the Weight Goal sheet once this sheet has closed.
    let changePace: () -> Void
    /// Saves the targets as typed.
    let save: (FoodTargets) -> Void
    @State private var calorieTargetText: String
    @State private var proteinText: String
    @State private var fatText: String
    @State private var activityLevel: ActivityLevel
    @Environment(\.dismiss) private var dismiss

    init(
        targets: FoodTargets,
        missingForExpenditure: [ExpenditureInput],
        windowFigure: Double?,
        expenditure: Double?,
        suggestedCalorieTarget: Double?,
        paceNotSafelyReachable: Bool,
        easierGoal: FoodScreen.EasierGoal?,
        changePace: @escaping () -> Void,
        suggested: @escaping (Double) -> MacroTargets?,
        save: @escaping (FoodTargets) -> Void
    ) {
        self.suggested = suggested
        self.missingForExpenditure = missingForExpenditure
        self.windowFigure = windowFigure
        self.expenditure = expenditure
        self.suggestedCalorieTarget = suggestedCalorieTarget
        self.paceNotSafelyReachable = paceNotSafelyReachable
        self.easierGoal = easierGoal
        self.changePace = changePace
        self.save = save
        _calorieTargetText = State(initialValue: targets.calorieTarget.map(NumberText.text) ?? "")
        _proteinText = State(initialValue: targets.proteinOverride.map(NumberText.text) ?? "")
        _fatText = State(initialValue: targets.fatOverride.map(NumberText.text) ?? "")
        _activityLevel = State(initialValue: targets.activityLevel ?? .light)
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
                Section {
                    // How Expenditure was worked out (spec 017): the logged data's figure.
                    if let windowFigure {
                        LabeledContent(
                            "Your last \(FoodView.expenditureWindowDays) Days",
                            value:
                                "~\(windowFigure.formatted(.number.precision(.fractionLength(0)))) kcal a Day"
                        )
                    }
                    Picker("Activity Level", selection: $activityLevel) {
                        ForEach(ActivityLevel.allCases, id: \.self) { level in
                            Text(Self.label(level)).tag(level)
                        }
                    }
                } header: {
                    Text("Expenditure")
                } footer: {
                    if missingForExpenditure.isEmpty {
                        Text("Used to estimate your Expenditure until you've logged enough Days.")
                    } else {
                        // The spec: the targets sheet says which is missing.
                        Text(
                            "To estimate your Expenditure from your Profile, Serenix needs \(Self.missingText(missingForExpenditure))."
                        )
                    }
                }
                // The suggestion, and the floor message when the Pace can't be met (spec 017).
                if let suggestedCalorieTarget {
                    Section("Suggested Calorie Target") {
                        // How it was worked out (spec 017, Screen): Expenditure, less or plus
                        // the Pace's energy.
                        if let expenditure {
                            LabeledContent(
                                "Your Expenditure",
                                value: "~\(Self.whole(expenditure)) kcal a Day"
                            )
                        }
                        LabeledContent(
                            "For your Pace",
                            value: "\(Self.whole(suggestedCalorieTarget)) kcal a Day"
                        )
                        if paceNotSafelyReachable {
                            Text(
                                "Your Pace needs less than is safe at this Expenditure, so this is the lowest Serenix suggests."
                            )
                            .font(.footnote)
                            .foregroundStyle(Color.orange)
                            if let easierGoal {
                                Button(easierGoal.label) {
                                    easierGoal.apply()
                                    dismiss()
                                }
                            } else {
                                Button("Change my Pace") {
                                    changePace()
                                    dismiss()
                                }
                            }
                        }
                    }
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
                                fatOverride: fatOverride,
                                activityLevel: activityLevel
                            )
                        )
                        dismiss()
                    }
                    .disabled(calorieRefusal != nil || overrideRefusal != nil || unreadable)
                }
            }
        }
    }

    /// "your height and a Weigh-in": what the starting estimate lacks, in words.
    private static func missingText(_ missing: [ExpenditureInput]) -> String {
        let names = missing.map { input in
            switch input {
            case .height: "your height"
            case .birthYear: "your birth year"
            case .weighIn: "a Weigh-in"
            }
        }
        return ListFormatter.localizedString(byJoining: names)
    }

    /// A kcal figure as a whole number with a thousands separator ("1,850").
    private static func whole(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }

    /// The Activity Level's name in the picker (GLOSSARY, Activity Level).
    private static func label(_ level: ActivityLevel) -> String {
        switch level {
        case .mostlySitting: "Mostly sitting"
        case .light: "Light"
        case .moderate: "Moderate"
        case .veryActive: "Very active"
        }
    }

    /// "Protein (suggested 176 g)", or "Protein (g)" with no suggestion.
    private func placeholder(_ name: String, _ grams: Double?) -> String {
        grams.map { "\(name) (suggested \(NumberText.text($0.rounded())) g)" } ?? "\(name) (g)"
    }
}
