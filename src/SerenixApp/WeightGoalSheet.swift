import SerenixCore
import SwiftUI

/// Sets a Weight Goal (spec 015, Weight Goal): Start Weight and start date (today's Trend Weight
/// and today by default), Goal Weight, and a Pace chosen either from the rate options, each
/// showing its share of Trend Weight and its band, or as a date to reach Goal Weight by, no
/// earlier than a 1%-a-week Pace allows. Aggressive and Too fast Paces warn but still save.
struct WeightGoalSheet: View {
    let view: BodyView
    let units: WeightUnits
    let save: (WeightGoal) -> Void
    /// Ends the current goal, kept as removed; nil for a new goal.
    let remove: (() -> Void)?
    @State private var startText: String
    @State private var startDate: Date
    @State private var goalText = ""
    @State private var rate: Double?
    @State private var byDate = false
    @State private var milestoneStep: MilestoneStep = .medium
    /// Hold weight instead of losing or gaining.
    @State private var holds = false
    @State private var holdBand = 1.0
    @State private var targetDate = Date()
    @Environment(\.dismiss) private var dismiss

    init(
        view: BodyView,
        units: WeightUnits,
        save: @escaping (WeightGoal) -> Void,
        remove: (() -> Void)? = nil
    ) {
        self.view = view
        self.units = units
        self.save = save
        self.remove = remove
        // An existing goal keeps its own start; a new one starts at today's Trend Weight.
        let existing = view.goalCard?.goal
        let startWeight = existing?.startWeight ?? view.newGoalStart?.weight
        _startText = State(initialValue: startWeight.map { Self.text($0, in: units) } ?? "")
        _startDate = State(
            initialValue: existing.map { $0.startDay.midday(in: .current) } ?? Date()
        )
        if let goal = existing {
            _goalText = State(initialValue: Self.text(goal.goalWeight, in: units))
            _milestoneStep = State(initialValue: goal.milestoneStep ?? .medium)
            if let band = goal.holdBand {
                _holds = State(initialValue: true)
                _holdBand = State(initialValue: band)
            }
            switch goal.pace {
            case .rate(let kilogramsPerWeek):
                _rate = State(initialValue: kilogramsPerWeek)
            case .date(let day):
                _byDate = State(initialValue: true)
                _targetDate = State(initialValue: day.midday(in: .current))
            case nil:
                break
            }
        }
    }

    private var startWeight: Double? { Self.kilograms(startText, in: units) }
    private var goalWeight: Double? { Self.kilograms(goalText, in: units) }

    private var direction: GoalDirection? {
        guard let startWeight, let goalWeight else { return nil }
        return WeightGoal.direction(startWeight: startWeight, goalWeight: goalWeight)
    }

    /// The goal as typed, once every field reads.
    private var draft: WeightGoal? {
        if holds {
            guard let goalWeight else { return nil }
            // A hold edits an existing hold from its own start; any other hold starts today.
            let start =
                view.goalCard?.goal.holdBand != nil
                ? view.goalCard?.goal.startDay : nil
            return WeightGoal.hold(
                at: goalWeight,
                band: holdBand,
                on: start ?? Day(containing: Date(), in: .current)
            )
        }
        guard let startWeight, let goalWeight else { return nil }
        let pace: GoalPace
        if byDate {
            pace = .date(Day(containing: targetDate, in: .current))
        } else if let rate {
            pace = .rate(kilogramsPerWeek: rate)
        } else {
            return nil
        }
        return WeightGoal(
            startWeight: startWeight,
            startDay: Day(containing: startDate, in: .current),
            goalWeight: goalWeight,
            pace: pace,
            milestoneStep: milestoneStep
        )
    }

    /// The earliest date allowed and the quick picks, for the Goal Weight typed.
    private var dates: GoalDates? { goalWeight.flatMap { view.goalDates(goalWeight: $0) } }

    private var refusal: GoalRefusal? { draft.flatMap { view.goalRefusal($0) } }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Goal", selection: $holds) {
                    Text("Lose or gain").tag(false)
                    Text("Hold").tag(true)
                }
                .pickerStyle(.segmented)
                // A hold has no separate start: it holds the weight below from today.
                if !holds {
                    Section("Start") {
                        TextField("Start Weight (\(Self.symbol(units)))", text: $startText)
                            .keyboardType(.decimalPad)
                        DatePicker(
                            "Start date",
                            selection: $startDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                    }
                }
                if holds {
                    Section("Hold band") {
                        Picker("Either side", selection: $holdBand) {
                            ForEach(WeightGoal.holdBandOptions, id: \.self) { band in
                                Text(
                                    (units == .kilograms ? units : .pounds)
                                        .text(band, locale: .current)
                                )
                                .tag(band)
                            }
                        }
                    }
                }
                Section(holds ? "Weight to hold" : "Goal") {
                    TextField("Goal Weight (\(Self.symbol(units)))", text: $goalText)
                        .keyboardType(.decimalPad)
                }
                if let refusal {
                    Text(refusal.message).foregroundStyle(.red)
                }
                if !holds, let direction {
                    Section("Pace") {
                        Picker("Pace", selection: $byDate) {
                            Text("By rate").tag(false)
                            Text("By date").tag(true)
                        }
                        .pickerStyle(.segmented)
                        if byDate, let dates {
                            DatePicker(
                                "Reach it by",
                                selection: $targetDate,
                                in: dates.earliest.midday(in: .current)...,
                                displayedComponents: .date
                            )
                            HStack {
                                Button("0.5% a week") {
                                    targetDate = dates.halfPercent.midday(in: .current)
                                }
                                Button("0.75% a week") {
                                    targetDate = dates.threeQuarterPercent.midday(in: .current)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    if !byDate {
                        rateSection(direction)
                    }
                    Section("Milestone every") {
                        Picker("Milestone every", selection: $milestoneStep) {
                            ForEach(MilestoneStep.allCases, id: \.self) { step in
                                Text(Self.stepLabel(step, units: units))
                                    .tag(step)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .onChange(of: direction) { rate = nil }
            // Date mode opens on the 0.5%-a-week date, never on today, which is too early.
            .onChange(of: byDate) {
                if byDate, let dates { targetDate = dates.halfPercent.midday(in: .current) }
            }
            .navigationTitle("Weight Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                if let remove {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Remove goal", role: .destructive) {
                            remove()
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

    /// The rate options for `direction`, each with its share of Trend Weight and its band.
    private func rateSection(_ direction: GoalDirection) -> some View {
        Section("Rate") {
            ForEach(view.rateOptions(for: direction), id: \.kilogramsPerWeek) {
                option in
                Button {
                    rate = option.kilogramsPerWeek
                } label: {
                    HStack {
                        Text(units.paceText(option.kilogramsPerWeek, locale: .current))
                        Spacer()
                        Text(
                            "\(option.percentOfTrendWeight.formatted(.number.precision(.fractionLength(2))))%"
                        )
                        .foregroundStyle(.secondary)
                        BandLabel(band: option.band)
                        if rate == option.kilogramsPerWeek {
                            Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
        }
    }

    /// kg or lb, to one decimal; st and lb goals are typed in total lb here.
    private static func text(_ kilograms: Double, in units: WeightUnits) -> String {
        let shown = units == .kilograms ? kilograms : WeightUnits.pounds.fields(kilograms).rest
        return shown.formatted(.number.precision(.fractionLength(1)).grouping(.never))
    }

    private static func kilograms(_ text: String, in units: WeightUnits) -> Double? {
        guard let value = try? Double(text, format: .number) else { return nil }
        let fields = WeightFields(stones: nil, rest: value)
        return units == .kilograms ? fields.rest : WeightUnits.pounds.kilograms(fields)
    }

    /// A Milestone step as a whole number: "2 kg", or "5 lb" in lb and st units.
    private static func stepLabel(_ step: MilestoneStep, units: WeightUnits) -> String {
        let inKilograms = units == .kilograms
        let size = step.size(in: units) / (inKilograms ? 1 : WeightUnits.kilogramsPerPound)
        return "\(Int(size.rounded())) \(inKilograms ? "kg" : "lb")"
    }

    private static func symbol(_ units: WeightUnits) -> String {
        units == .kilograms ? "kg" : "lb"
    }
}

/// A Pace band's name in its colour (spec 015, Pace bands).
struct BandLabel: View {
    let band: PaceBand

    var body: some View {
        let (text, colour): (String, Color) =
            switch band {
            case .sustainable: ("Sustainable", .green)
            case .aggressive: ("Aggressive", .orange)
            case .tooFast: ("Too fast", .red)
            }
        CapsuleTag(text: text, colour: colour)
    }
}
