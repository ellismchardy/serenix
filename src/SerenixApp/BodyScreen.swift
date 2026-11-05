import SerenixCore
import SwiftUI

/// The Body tab (spec 014): draws the Body view, and logs Weigh-ins.
struct BodyScreen: View {
    @ObservedObject var store: BodyStore
    @ObservedObject var profile: ProfileStore
    @State private var showsWeighInSheet = false
    @State private var showsGoalSheet = false

    var body: some View {
        let view = BodyView(
            weighIns: store.weighIns,
            units: profile.units,
            goal: store.currentGoal,
            now: Date(),
            timeZone: .current
        )
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if let trendWeight = view.trendWeight {
                        Text(profile.units.text(trendWeight, locale: .current))
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                        if let last = view.lastWeighIn {
                            Text(
                                "Trend Weight · last Weigh-in \(profile.units.text(last.kilograms, locale: .current))"
                            )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Log your first Weigh-in")
                            .font(.title3.weight(.semibold))
                    }
                    WeightChartCard(view: view, units: profile.units)
                    if let card = view.goalCard {
                        goalCards(card, weeklyRate: view.weeklyRate)
                    } else if view.trendWeight != nil {
                        setGoalCard
                    }
                    if !view.weighIns.isEmpty {
                        NavigationLink("All Weigh-ins") {
                            WeighInList(store: store, units: profile.units)
                        }
                        .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Body")
            .toolbar {
                Button {
                    showsGoalSheet = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Weight Goal")
                .disabled(view.trendWeight == nil)
                Button {
                    showsWeighInSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Log a Weigh-in")
            }
            .sheet(isPresented: $showsGoalSheet) {
                WeightGoalSheet(view: view, units: profile.units) { store.setGoal($0) }
            }
            .sheet(isPresented: $showsWeighInSheet) {
                WeighInSheet(units: profile.units, lastWeight: view.lastWeighIn?.kilograms) {
                    store.add($0)
                }
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
    }
    /// The Rate and Goal cards (spec 014, Screen).
    private func goalCards(_ card: GoalCard, weeklyRate: Double?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("RATE").font(.caption).foregroundStyle(.secondary)
                Text(weeklyRate.map { profile.units.rateText($0, locale: .current) } ?? "—")
                    .font(.headline)
                Text("Weekly Rate").font(.caption).foregroundStyle(.secondary)
                switch card.status {
                case .settlingIn(let day):
                    Text("Settling in, day \(day) of \(PaceStatus.settlingDays)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                case .badge(let badge):
                    PaceBadgeLabel(badge: badge)
                case nil:
                    EmptyView()
                }
                if let ease = card.ease {
                    Button(easeLabel(ease)) { store.setGoal(card.goal.eased(by: ease)) }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                        .tint(Theme.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .themeCard()
            Button {
                showsGoalSheet = true
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("GOAL").font(.caption).foregroundStyle(.secondary)
                    Text(profile.units.text(card.goal.goalWeight, locale: .current))
                        .font(.headline)
                    if let pace = card.paceKilogramsPerWeek {
                        Text(
                            "Pace \(profile.units.paceText(pace, locale: .current))"
                        )
                        .font(.caption)
                    }
                    if let band = card.paceBand { BandLabel(band: band) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .themeCard()
            }
            .buttonStyle(.plain)
        }
    }

    /// The Ease the goal offer's words (spec 014).
    private func easeLabel(_ ease: GoalEase) -> String {
        switch ease {
        case .rate(let kilogramsPerWeek):
            "Ease to \(profile.units.paceText(kilogramsPerWeek, locale: .current))"
        case .date(let day):
            "Move the date to \(Self.shown(day))"
        }
    }

    /// `day` as the phone shows a date, e.g. "14 Jan 2027", on the Gregorian calendar a Day uses.
    private static func shown(_ day: Day) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let date = calendar.date(
            from: DateComponents(year: day.year, month: day.month, day: day.dayOfMonth, hour: 12)
        )
        return date?.formatted(date: .abbreviated, time: .omitted) ?? ""
    }

    /// In place of the goal cards when there is no Weight Goal.
    private var setGoalCard: some View {
        VStack(spacing: 10) {
            Text("No Weight Goal yet").font(.headline)
            Button("Set a goal") { showsGoalSheet = true }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .themeCard()
    }
}

/// Logs one Weigh-in, or edits one, in the Profile's units: the last weight filled in, and an
/// editable date and time (spec 014). Fields are text, parsed on every keystroke, because a
/// number field only updates when it commits and the decimal pad has no Return key. The weight
/// is stored in kg. A refused Weigh-in isn't saved; the sheet shows why.
struct WeighInSheet: View {
    let units: WeightUnits
    let save: (WeighIn) -> Void
    private let isEditing: Bool
    /// kg, lb, or (for st and lb) the pounds part.
    @State private var text = ""
    /// The stones part, in st and lb only.
    @State private var stonesText = ""
    @State private var time: Date
    @Environment(\.dismiss) private var dismiss

    /// `editing` fills in that Weigh-in (at full precision in kg), otherwise `lastWeight` to one
    /// decimal.
    init(
        units: WeightUnits,
        editing: WeighIn? = nil,
        lastWeight: Double?,
        save: @escaping (WeighIn) -> Void
    ) {
        self.units = units
        self.save = save
        isEditing = editing != nil
        _time = State(initialValue: editing?.time ?? Date())
        if let editing, units == .kilograms {
            // Every digit, so saving it untouched never rounds a stored value.
            _text = State(initialValue: editing.kilograms.formatted(.number.grouping(.never)))
        } else if let kilograms = editing?.kilograms ?? lastWeight {
            let fields = units.fields(kilograms)
            _stonesText = State(initialValue: fields.stones.map(String.init) ?? "")
            _text = State(
                initialValue: fields.rest.formatted(
                    .number.precision(.fractionLength(1)).grouping(.never)
                )
            )
        }
    }

    /// The weight typed in, in kg; nil until it reads as a number.
    private var weight: Double? {
        guard let rest = try? Double(text, format: .number) else { return nil }
        var stones: Int?
        if units == .stonesAndPounds {
            guard let typed = Int(stonesText) else { return nil }
            stones = typed
        }
        return units.kilograms(WeightFields(stones: stones, rest: rest))
    }

    private var refusal: WeighInRefusal? {
        weight.flatMap { WeighIn(time: time, kilograms: $0).refusal(now: Date()) }
    }

    var body: some View {
        NavigationStack {
            Form {
                switch units {
                case .kilograms:
                    TextField("Weight (kg)", text: $text).keyboardType(.decimalPad)
                case .pounds:
                    TextField("Weight (lb)", text: $text).keyboardType(.decimalPad)
                case .stonesAndPounds:
                    HStack {
                        TextField("st", text: $stonesText).keyboardType(.numberPad)
                        Text("st")
                        TextField("lb", text: $text).keyboardType(.decimalPad)
                        Text("lb")
                    }
                }
                DatePicker("Taken", selection: $time, in: ...Date())
                if let refusal {
                    Text(refusal.message(in: units)).foregroundStyle(.red)
                }
            }
            .navigationTitle(isEditing ? "Edit Weigh-in" : "Log Weigh-in")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let weight { save(WeighIn(time: time, kilograms: weight)) }
                        dismiss()
                    }
                    .disabled(weight == nil || refusal != nil)
                }
            }
        }
    }
}

/// The pace badge in its colour (spec 014, Pace badge).
struct PaceBadgeLabel: View {
    let badge: PaceBadge

    var body: some View {
        let (text, colour): (String, Color) =
            switch badge {
            case .onPace: ("On pace", .green)
            case .behind: ("A bit behind", .orange)
            case .offPace: ("Off pace", .red)
            case .tooFast: ("Too fast", .orange)
            }
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(colour.opacity(0.18), in: Capsule())
            .foregroundStyle(colour)
    }
}
