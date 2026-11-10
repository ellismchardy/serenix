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
    /// The Day picked; nil is today, whatever today is when the view draws, so it rolls over at
    /// midnight as the Today and Sleep tabs do.
    @State private var pickedDay: Day?
    @State private var showsEntrySheet = false
    @State private var showsTargetsSheet = false
    /// The row being edited, while its sheet shows.
    @State private var editing: FoodEntryRow?

    var body: some View {
        let today = Day(containing: Date(), in: .current)
        // One snapshot of the stored rows: the view gets their entries, and its entry positions
        // index back into this same array, so the two can't fall out of step.
        let rows = store.rows
        let view = FoodView(
            foodEntries: rows.map(\.entry),
            completeDays: store.completeDays,
            foodTargets: store.targets,
            weighIns: bodyStore.weighIns,
            weightGoal: bodyStore.currentGoal,
            heightCentimetres: profile.heightCentimetres,
            birthYear: profile.birthYear,
            sex: profile.sex,
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
                // Against the Calorie Target, when there is one (spec 016, Screen).
                if let target = view.calorieTarget, let balance = view.calorieBalance {
                    Text("of \(Self.whole(target)) kcal · \(Self.balanceText(balance))")
                        .font(.headline)
                        .foregroundStyle(Self.isOver(balance) ? Color.orange : Color.secondary)
                }
                // Expenditure and where it came from (spec 017, Screen).
                if let expenditure = view.expenditure, let source = view.expenditureSource {
                    Text(
                        "Expenditure ~\(Self.whole(expenditure)) kcal · \(Self.sourceText(source))"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                Text(
                    "Protein \(Self.whole(view.intake.protein)) g · Fat \(Self.whole(view.intake.fat)) g · Carbs \(Self.whole(view.intake.carbs)) g"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .themeCard()
            macroCard(view)
            if view.entries.isEmpty {
                Text("Nothing logged on this Day.").foregroundStyle(.secondary)
            }
            // Only a Day with a Food Entry can be marked complete (spec 016).
            if view.canBeMarkedComplete {
                Toggle(
                    "Day complete",
                    isOn: Binding(
                        get: { view.isComplete },
                        set: { store.setComplete($0, on: view.day) }
                    )
                )
                .padding()
                .themeCard()
            }
            // Tap to edit or delete; holding also offers Delete (spec 016: any Food Entry can be
            // edited or deleted).
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
            Button {
                showsEntrySheet = true
            } label: {
                Label("Log a Food Entry", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
        .toolbar {
            Button {
                showsTargetsSheet = true
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("Targets")
        }
        .sheet(isPresented: $showsTargetsSheet) {
            FoodTargetsSheet(
                targets: store.targets,
                missingForExpenditure: view.missingForExpenditure,
                windowFigure: view.windowFigure,
                suggested: { suggestedTargets(calorieTarget: $0) },
                save: { targets in
                    store.setTargets(
                        targets,
                        suggested: targets.calorieTarget.flatMap {
                            suggestedTargets(calorieTarget: $0)
                        }
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
    private func macroCard(_ view: FoodView) -> some View {
        if let targets = view.macroTargets {
            VStack(alignment: .leading, spacing: 10) {
                macroBar("Protein", eaten: view.intake.protein, target: targets.protein)
                macroBar("Fat", eaten: view.intake.fat, target: targets.fat)
                macroBar("Carbs", eaten: view.intake.carbs, target: targets.carbs)
                switch view.macroWarning {
                case .lowCarbs:
                    Text(
                        "Carbs are under \(Self.whole(MacroTargets.lowCarbsGrams)) g a Day at this Calorie Target."
                    )
                    .font(.caption)
                    .foregroundStyle(Color.orange)
                case .noCarbsLeft:
                    Text(
                        "Protein and fat use up the whole Calorie Target, so there's none left for carbs."
                    )
                    .font(.caption)
                    .foregroundStyle(Color.orange)
                case nil:
                    EmptyView()
                }
            }
            .padding()
            .themeCard()
        } else if view.needsWeighIn {
            Text("Log a Weigh-in to get your Macro Targets.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    /// One macro's grams eaten against its target, as a bar.
    private func macroBar(_ name: String, eaten: Double, target: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Self.whole(eaten)) / \(Self.whole(target)) g")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(eaten, target), total: max(target, 1))
                .tint(Theme.accent)
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
