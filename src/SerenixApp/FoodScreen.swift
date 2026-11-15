import SerenixCore
import SwiftUI

/// The Body tab's Food view (spec 016): one Day's Food Entries and Intake, any past Day by the
/// date picker, and + to log a Food Entry. It draws the Food view and decides nothing.
struct FoodScreen: View {
    @ObservedObject var store: FoodStore
    /// For Trend Weight and the Weight Goal, which the Macro Targets are drawn from.
    @ObservedObject var bodyStore: BodyStore
    /// For the height the Macro Targets' BMI rule uses.
    @ObservedObject var profile: ProfileStore
    /// Spec 015's easier goal, when one is on offer; the floor message offers it (spec 017).
    let easierGoal: EasierGoal?
    /// Opens the Weight Goal sheet, for the floor message's "Change my Pace".
    let changePace: () -> Void

    /// An easier Weight Goal offered as one tap: its label and what it does.
    struct EasierGoal {
        let label: String
        let apply: () -> Void
    }
    /// The Day picked; nil is today, whatever today is when the view draws, so it rolls over at
    /// midnight as the Today and Sleep tabs do.
    @State private var pickedDay: Day?
    @State private var showsEntrySheet = false
    @State private var showsTargetsSheet = false
    /// "Change my Pace" was tapped; the Weight Goal sheet opens once the targets sheet has gone.
    @State private var wantsPaceChange = false
    /// The row being edited, while its sheet shows.
    @State private var editing: FoodEntryRow?

    var body: some View {
        let today = Day(containing: Date(), in: .current)
        // One snapshot of the stored rows: the view gets their entries, and its entry positions
        // index back into this same array, so the two can't fall out of step.
        let rows = store.rows
        let view = foodView(rows, day: pickedDay ?? today, today: today, targets: store.targets)
        VStack(alignment: .leading, spacing: 24) {
            RuledRow {
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
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Poster.ink)
            }
            intakeHeadline(view)
            macroSection(view)
            // Only a Day with a Food Entry can be marked complete (spec 016).
            if view.canBeMarkedComplete {
                RuledRow {
                    Toggle(
                        "Day complete",
                        isOn: Binding(
                            get: { view.isComplete },
                            set: { store.setComplete($0, on: view.day) }
                        )
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Poster.ink)
                    .tint(Poster.ink)
                }
            }
            RuledSection(name: "Food Entries") {
                if view.entries.isEmpty {
                    Text("Nothing logged on this Day.")
                        .font(.subheadline)
                        .foregroundStyle(Poster.secondary)
                }
                // Tap to edit or delete; holding also offers Delete (spec 016: any Food Entry
                // can be edited or deleted).
                ForEach(view.entryIndices.map { rows[$0] }) { row in
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
            }
            Button {
                showsEntrySheet = true
            } label: {
                Label("Log a Food Entry", systemImage: "plus")
            }
            .buttonStyle(BlockButtonStyle(colour: Poster.red))
        }
        .toolbar {
            Button {
                showsTargetsSheet = true
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("Targets")
        }
        .sheet(
            isPresented: $showsTargetsSheet,
            onDismiss: {
                if wantsPaceChange {
                    wantsPaceChange = false
                    changePace()
                }
            }
        ) {
            FoodTargetsSheet(
                targets: store.targets,
                // The same Day, at the Activity Level the sheet's picker shows.
                foodView: { level in
                    let targets = store.targets
                    return foodView(
                        rows,
                        day: view.day,
                        today: today,
                        targets: FoodTargets(
                            calorieTarget: targets.calorieTarget,
                            proteinOverride: targets.proteinOverride,
                            fatOverride: targets.fatOverride,
                            activityLevel: level,
                            adaptsCalorieTarget: targets.adaptsCalorieTarget
                        )
                    )
                },
                easierGoal: easierGoal,
                changePace: { wantsPaceChange = true },
                suggested: { suggestedTargets(calorieTarget: $0) },
                save: { targets, suggestedCalorieTarget in
                    store.setTargets(
                        targets,
                        suggestedCalorieTarget: suggestedCalorieTarget,
                        suggested: { suggestedTargets(calorieTarget: $0) }
                    )
                }
            )
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
            "Food data",
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

    /// One Food Entry: its time and name, calories, and the macros it has.
    private func entryRow(_ entry: FoodEntry) -> some View {
        RuledRow {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name ?? "Food Entry")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Poster.ink)
                    Text(entry.time.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(Poster.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Self.whole(entry.kilocalories)) kcal")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Poster.ink)
                    let macros = [("P", entry.protein), ("F", entry.fat), ("C", entry.carbs)]
                        .compactMap { label, grams in
                            grams.map { "\(label) \(Self.whole($0)) g" }
                        }
                    if !macros.isEmpty {
                        Text(macros.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(Poster.secondary)
                    }
                }
            }
            .contentShape(Rectangle())
        }
    }

    /// The Day's Intake as the headline with its verdict, then its caption lines: against the
    /// Calorie Target ("N over" in amber), Expenditure and where it came from, and the macros;
    /// then a red bar toward the Calorie Target (spec 018, Food).
    private func intakeHeadline(_ view: FoodView) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            PosterHeadline(
                number: Self.whole(view.intake.kilocalories),
                unit: "kcal",
                verdict: view.intakeVerdict,
                size: Poster.bodyHeadlineSize
            )
            // Against the Calorie Target, when there is one (spec 016, Screen).
            if let target = view.calorieTarget, let balance = view.calorieBalance {
                Text("of \(Self.whole(target)) kcal · \(Self.balanceText(balance))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Self.isOver(balance) ? Poster.amber : Poster.ink)
            }
            // Expenditure and where it came from (spec 017, Screen).
            if let expenditure = view.expenditure, let source = view.expenditureSource {
                Text("Expenditure ~\(Self.whole(expenditure)) kcal · \(Self.sourceText(source))")
                    .font(.subheadline)
                    .foregroundStyle(Poster.secondary)
            }
            Text(
                "Protein \(Self.whole(view.intake.protein)) g · Fat \(Self.whole(view.intake.fat)) g · Carbs \(Self.whole(view.intake.carbs)) g"
            )
            .font(.subheadline)
            .foregroundStyle(Poster.secondary)
            if let target = view.calorieTarget, target > 0 {
                PosterBar(fill: view.intake.kilocalories / target).padding(.top, 4)
            }
        }
    }

    /// The Food view for `day` with `targets`, from the stored rows, Weigh-ins and Profile;
    /// `today` is the one `body` read, so the Day shown and its verdict use the same today.
    private func foodView(
        _ rows: [FoodEntryRow],
        day: Day,
        today: Day,
        targets: FoodTargets
    ) -> FoodView {
        FoodView(
            foodEntries: rows.map(\.entry),
            completeDays: store.completeDays,
            foodTargets: targets,
            weighIns: bodyStore.weighIns,
            weightGoal: bodyStore.currentGoal,
            heightCentimetres: profile.heightCentimetres,
            birthYear: profile.birthYear,
            sex: profile.sex,
            day: day,
            today: today,
            timeZone: .current
        )
    }

    /// The suggested Macro Targets at `calorieTarget`, from the core; nil without Trend Weight.
    private func suggestedTargets(calorieTarget: Double) -> MacroTargets? {
        FoodView.suggestedMacroTargets(
            calorieTarget: calorieTarget,
            weighIns: bodyStore.weighIns,
            weightGoal: bodyStore.currentGoal,
            heightCentimetres: profile.heightCentimetres,
            timeZone: .current
        )
    }

    /// Protein, fat and carbs against their Macro Targets, with the carbs warning; or why there
    /// are no targets (spec 016, Macro Targets).
    @ViewBuilder
    private func macroSection(_ view: FoodView) -> some View {
        if let targets = view.macroTargets {
            RuledSection(name: "Macro Targets") {
                macroBar("Protein", eaten: view.intake.protein, target: targets.protein)
                macroBar("Fat", eaten: view.intake.fat, target: targets.fat)
                macroBar("Carbs", eaten: view.intake.carbs, target: targets.carbs)
                switch view.macroWarning {
                case .lowCarbs:
                    Text(
                        "Carbs are under \(Self.whole(MacroTargets.lowCarbsGrams)) g a Day at this Calorie Target."
                    )
                    .font(.caption)
                    .foregroundStyle(Poster.amber)
                case .noCarbsLeft:
                    Text(
                        "Protein and fat use up the whole Calorie Target, so there's none left for carbs."
                    )
                    .font(.caption)
                    .foregroundStyle(Poster.amber)
                case nil:
                    EmptyView()
                }
            }
        } else if view.needsWeighIn {
            RuledSection(name: "Macro Targets") {
                Text("Log a Weigh-in to get your Macro Targets.")
                    .font(.subheadline)
                    .foregroundStyle(Poster.secondary)
            }
        }
    }

    /// One macro's grams eaten against its target, as a bar.
    private func macroBar(_ name: String, eaten: Double, target: Double) -> some View {
        RuledRow {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(name).font(.subheadline.weight(.semibold)).foregroundStyle(Poster.ink)
                    Spacer()
                    Text("\(Self.whole(eaten)) / \(Self.whole(target)) g")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Poster.ink)
                }
                PosterBar(fill: target > 0 ? eaten / target : 0, height: 4)
            }
        }
    }

    /// "from your Profile" or "from your last 21 Days" (spec 017, Screen).
    private static func sourceText(_ source: ExpenditureSource) -> String {
        switch source {
        case .profile: "from your Profile"
        case .loggedData: "from your last \(FoodView.expenditureWindowDays) Days"
        }
    }

    /// "550 left" or "120 over" (spec 016, Screen).
    private static func balanceText(_ balance: CalorieBalance) -> String {
        switch balance {
        case .left(let kilocalories): "\(whole(kilocalories)) left"
        case .over(let kilocalories): "\(whole(kilocalories)) over"
        }
    }

    private static func isOver(_ balance: CalorieBalance) -> Bool {
        if case .over = balance { true } else { false }
    }

    /// A value as a whole number, as kcal and grams are shown (spec 016).
    private static func whole(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }
}
