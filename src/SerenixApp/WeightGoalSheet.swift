import SerenixCore
import SwiftUI

/// Sets a Weight Goal (spec 014, Weight Goal): Start Weight and start date (today's Trend Weight
/// and today by default), Goal Weight, and a Pace chosen from the rate options, each showing its
/// share of Trend Weight and its band. Aggressive and Too fast Paces warn but still save.
struct WeightGoalSheet: View {
    let view: BodyView
    let units: WeightUnits
    let save: (WeightGoal) -> Void
    @State private var startText: String
    @State private var startDate: Date
    @State private var goalText = ""
    @State private var rate: Double?
    @Environment(\.dismiss) private var dismiss

    init(view: BodyView, units: WeightUnits, save: @escaping (WeightGoal) -> Void) {
        self.view = view
        self.units = units
        self.save = save
        // An existing goal keeps its own start; a new one starts at today's Trend Weight.
        let existing = view.goalCard?.goal
        let startWeight = existing?.startWeight ?? view.newGoalStart?.weight
        _startText = State(initialValue: startWeight.map { Self.text($0, in: units) } ?? "")
        _startDate = State(
            initialValue: existing.map { Self.midday($0.startDay) } ?? Date()
        )
        if let goal = existing {
            _goalText = State(initialValue: Self.text(goal.goalWeight, in: units))
            if case .rate(let kilogramsPerWeek) = goal.pace {
                _rate = State(initialValue: kilogramsPerWeek)
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
        guard let startWeight, let goalWeight, let rate else { return nil }
        return WeightGoal(
            startWeight: startWeight,
            startDay: Day(containing: startDate, in: .current),
            goalWeight: goalWeight,
            pace: .rate(kilogramsPerWeek: rate)
        )
    }

    private var refusal: GoalRefusal? { draft?.refusal(units: units) }

    var body: some View {
        NavigationStack {
            Form {
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
                Section("Goal") {
                    TextField("Goal Weight (\(Self.symbol(units)))", text: $goalText)
                        .keyboardType(.decimalPad)
                }
                if let refusal {
                    Text(refusal.message).foregroundStyle(.red)
                }
                if let direction {
                    Section("Pace") {
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
            }
            .onChange(of: direction) { rate = nil }
            .navigationTitle("Weight Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
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

    /// Midday on `day` in the phone's time zone, on the Gregorian calendar a Day uses.
    private static func midday(_ day: Day) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(
            from: DateComponents(year: day.year, month: day.month, day: day.dayOfMonth, hour: 12)
        ) ?? Date()
    }

    private static func symbol(_ units: WeightUnits) -> String {
        units == .kilograms ? "kg" : "lb"
    }
}

/// A Pace band's name in its colour (spec 014, Pace bands).
struct BandLabel: View {
    let band: PaceBand

    var body: some View {
        let (text, colour): (String, Color) =
            switch band {
            case .sustainable: ("Sustainable", .green)
            case .aggressive: ("Aggressive", .orange)
            case .tooFast: ("Too fast", .red)
            }
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(colour.opacity(0.18), in: Capsule())
            .foregroundStyle(colour)
    }
}
