import SerenixCore
import SwiftUI

/// The Body tab (spec 015): draws the Body view, and logs Weigh-ins.
struct BodyScreen: View {
    @ObservedObject var store: BodyStore
    @ObservedObject var profile: ProfileStore
    @State private var showsWeighInSheet = false
    @State private var showsGoalSheet = false
    /// The Goal Weight just reached, while its celebration shows (spec 015, Reached).
    @State private var reachedWeight: Double?

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
                        if let state = card.holdState {
                            holdCard(card, state: state)
                        } else {
                            goalCards(card, weeklyRate: view.weeklyRate)
                            milestonesCard(card)
                        }
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
            // A goal Trend Weight has reached ends, kept as Reached, and a celebration offers a
            // hold goal at that weight (spec 015, Reached).
            .task(id: view.goalCard?.reached) {
                guard let card = view.goalCard, card.reached else { return }
                // Celebrate only once the end is saved; a failed save shows its own alert.
                if store.endGoal(.reached) { reachedWeight = card.goal.goalWeight }
            }
            .alert(
                "Goal reached!",
                isPresented: Binding(
                    get: { reachedWeight != nil },
                    set: { if !$0 { reachedWeight = nil } }
                )
            ) {
                if let weight = reachedWeight {
                    Button("Hold at \(profile.units.text(weight, locale: .current))") {
                        store.setGoal(
                            WeightGoal.hold(at: weight, on: Day(containing: Date(), in: .current))
                        )
                    }
                }
                // A mistyped Weigh-in can end a goal; Undo reopens it as it was (spec 015).
                Button("Undo") {
                    store.reopenReachedGoal(on: Day(containing: Date(), in: .current))
                }
                Button("Not now", role: .cancel) {}
            } message: {
                Text("Your Trend Weight reached your Goal Weight.")
            }
            .sheet(isPresented: $showsGoalSheet) {
                WeightGoalSheet(
                    view: view,
                    units: profile.units,
                    save: { store.setGoal($0) },
                    remove: view.goalCard == nil ? nil : { store.removeGoal() }
                )
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
    /// The Rate and Goal cards (spec 015, Screen).
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
                    Button(easeLabel(ease)) {
                        store.setGoal(
                            card.goal.eased(by: ease, on: Day(containing: Date(), in: .current))
                        )
                    }
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
                    // The planned Day beside the projected one (spec 015, Projected date).
                    if let planned = card.plannedDay {
                        Text("Planned \(Self.shown(planned))").font(.caption)
                    }
                    if let projected = card.projectedDay {
                        Text("Projected \(Self.shown(projected))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .themeCard()
            }
            .buttonStyle(.plain)
        }
    }

    /// A hold goal's card: where Trend Weight sits against the band (spec 015, Hold).
    private func holdCard(_ card: GoalCard, state: HoldState) -> some View {
        let units = profile.units
        let band = card.goal.holdBand ?? 1
        let (text, colour): (String, Color) =
            switch state {
            case .inBand: ("In band", .green)
            case .aboveBand: ("Above band", .orange)
            case .belowBand: ("Below band", .orange)
            }
        return Button {
            showsGoalSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text("HOLD").font(.caption).foregroundStyle(.secondary)
                Text(
                    "\(units.text(card.goal.goalWeight, locale: .current)) ± "
                        + (units == .kilograms ? units : .pounds).text(band, locale: .current)
                )
                .font(.headline)
                CapsuleTag(text: text, colour: colour)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .themeCard()
        }
        .buttonStyle(.plain)
    }

    /// The Milestones card: each Milestone, passed ones ticked, and how far along the goal is
    /// (spec 015, Progress).
    private func milestonesCard(_ card: GoalCard) -> some View {
        let units = profile.units
        return VStack(alignment: .leading, spacing: 8) {
            Text("MILESTONES").font(.caption).foregroundStyle(.secondary)
            if !card.milestones.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(card.milestones, id: \.kilograms) { milestone in
                            Text(
                                (milestone.passed ? "✓ " : "")
                                    + units.text(milestone.kilograms, locale: .current)
                            )
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                milestone.passed ? Theme.accent : Theme.accentSoft,
                                in: Capsule()
                            )
                            .foregroundStyle(milestone.passed ? .white : Theme.accent)
                        }
                    }
                }
            }
            ProgressView(value: card.progress.percent, total: 100).tint(Theme.accent)
            Text(
                "\(Int(card.progress.percent.rounded()))% of the way · "
                    + "\(units.text(abs(card.progress.changeSinceStart), locale: .current)) "
                    + "\(card.direction == .lose ? "lost" : "gained") · "
                    + "\(units.text(card.progress.toGo, locale: .current)) to go"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .themeCard()
    }

    /// The Ease the goal offer's words (spec 015).
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
        day.midday(in: .current).formatted(date: .abbreviated, time: .omitted)
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
/// editable date and time (spec 015). Fields are text, parsed on every keystroke, because a
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

/// The pace badge in its colour (spec 015, Pace badge).
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
        CapsuleTag(text: text, colour: colour)
    }
}

/// A short status in its colour on a tinted capsule: the pace badge, a Pace band, a hold state.
struct CapsuleTag: View {
    let text: String
    let colour: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(colour.opacity(0.18), in: Capsule())
            .foregroundStyle(colour)
    }
}
