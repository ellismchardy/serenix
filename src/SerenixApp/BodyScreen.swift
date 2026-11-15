import SerenixCore
import SwiftUI

/// The Body tab: a Weight | Food switch (spec 016) over the weight screen, which draws the Body
/// view and logs Weigh-ins (spec 015), and the Food view.
struct BodyScreen: View {
    @ObservedObject var store: BodyStore
    @ObservedObject var foodStore: FoodStore
    @ObservedObject var profile: ProfileStore
    @State private var section = BodySection.weight
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
                // The masthead, then the Weight | Food switch as a two-cell segmented bar (spec
                // 018, Body).
                VStack(spacing: 16) {
                    Masthead(
                        title: "Serenix · Body",
                        detail: Poster.dayText(Date())
                    )
                    SegmentedBar(
                        options: [
                            (value: .weight, label: "Weight"), (value: .food, label: "Food"),
                        ],
                        selection: $section,
                        label: "Show"
                    )
                }
                .padding(.horizontal)
                if section == .food {
                    FoodScreen(
                        store: foodStore,
                        bodyStore: store,
                        profile: profile,
                        easierGoal: easierGoal(view),
                        changePace: { showsGoalSheet = true }
                    )
                    .padding()
                } else {
                    weightScreen(view)
                }
            }
            .background(Poster.paper.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if section == .weight {
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

    /// The weight screen (spec 015, drawn in the Poster look of spec 018): the Trend Weight
    /// headline with its verdict, the chart, and the goal sections.
    private func weightScreen(_ view: BodyView) -> some View {
        let units = profile.units
        return VStack(alignment: .leading, spacing: 24) {
            PosterHeadline(
                number: view.trendWeight.map { units.text($0, locale: .current) } ?? "—",
                verdict: view.weightVerdict,
                caption: view.lastWeighIn.map {
                    "Trend Weight · last Weigh-in \(units.text($0.kilograms, locale: .current))"
                } ?? "Log your first Weigh-in",
                size: Poster.bodyHeadlineSize
            )
            WeightChartCard(view: view, units: units)
            if let card = view.goalCard {
                if let state = card.holdState {
                    holdSection(card, state: state)
                } else {
                    rateAndGoal(card, weeklyRate: view.weeklyRate, easierGoal: easierGoal(view))
                    milestonesSection(card)
                }
            } else if view.trendWeight != nil {
                setGoalSection
            }
            if !view.weighIns.isEmpty {
                NavigationLink {
                    WeighInList(store: store, units: units)
                } label: {
                    RuledRow {
                        HStack {
                            Text("All Weigh-ins").font(.subheadline.weight(.semibold))
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote.weight(.bold))
                        }
                        .foregroundStyle(Poster.ink)
                        .contentShape(Rectangle())
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    /// Rate and Goal as two columns in one ruled section (spec 015, Screen; spec 018, Body), with
    /// the Ease the goal offer when there is one.
    private func rateAndGoal(
        _ card: GoalCard,
        weeklyRate: Double?,
        easierGoal: FoodScreen.EasierGoal?
    ) -> some View {
        let units = profile.units
        return RuledSection(name: "Rate · Goal") {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(weeklyRate.map { units.rateText($0, locale: .current) } ?? "—")
                        .font(Poster.headlineFont(size: 28))
                        .foregroundStyle(Poster.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("WEEKLY RATE").font(Poster.labelFont).foregroundStyle(Poster.secondary)
                    switch card.status {
                    case .settlingIn(let day):
                        Text("Settling in, day \(day) of \(PaceStatus.settlingDays)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Poster.secondary)
                    case .badge(let badge):
                        PaceBadgeLabel(badge: badge)
                    case nil:
                        EmptyView()
                    }
                    if let easierGoal {
                        Button(easierGoal.label, action: easierGoal.apply)
                            .buttonStyle(BlockButtonStyle(outlined: true))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    showsGoalSheet = true
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(units.text(card.goal.goalWeight, locale: .current))
                            .font(Poster.headlineFont(size: 28))
                            .foregroundStyle(Poster.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text("GOAL").font(Poster.labelFont).foregroundStyle(Poster.secondary)
                        if let pace = card.paceKilogramsPerWeek {
                            Text("Pace \(units.paceText(pace, locale: .current))")
                                .font(.caption)
                                .foregroundStyle(Poster.ink)
                        }
                        if let band = card.paceBand { BandLabel(band: band) }
                        // The planned Day beside the projected one (spec 015, Projected date).
                        if let planned = card.plannedDay {
                            Text("Planned \(Self.shown(planned))")
                                .font(.caption)
                                .foregroundStyle(Poster.ink)
                        }
                        if let projected = card.projectedDay {
                            Text("Projected \(Self.shown(projected))")
                                .font(.caption)
                                .foregroundStyle(Poster.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// A hold goal's section: Goal Weight ± band, and where Trend Weight sits against the band as
    /// a solid tag (spec 015, Hold; spec 018, Body).
    private func holdSection(_ card: GoalCard, state: HoldState) -> some View {
        let units = profile.units
        let band = card.goal.holdBand ?? 1
        let (text, colour): (String, Color) =
            switch state {
            case .inBand: ("In band", Poster.green)
            case .aboveBand: ("Above band", Poster.amber)
            case .belowBand: ("Below band", Poster.amber)
            }
        return Button {
            showsGoalSheet = true
        } label: {
            RuledSection(name: "Hold") {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(
                        "\(units.text(card.goal.goalWeight, locale: .current)) ± "
                            + (units == .kilograms ? units : .pounds).text(band, locale: .current)
                    )
                    .font(Poster.headlineFont(size: 28))
                    .foregroundStyle(Poster.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    Spacer(minLength: 8)
                    PosterTag(text: text, colour: colour)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// The Milestones section: each Milestone one cell of a segmented progress bar, passed cells
    /// solid red with a ✓, and how far along the goal is as its note (spec 015, Progress; spec
    /// 018, Body).
    private func milestonesSection(_ card: GoalCard) -> some View {
        let units = profile.units
        let note =
            "\(Int(card.progress.percent.rounded()))% of the way · "
            + "\(units.text(abs(card.progress.changeSinceStart), locale: .current)) "
            + "\(card.direction == .lose ? "lost" : "gained") · "
            + "\(units.text(card.progress.toGo, locale: .current)) to go"
        return RuledSection(name: "Milestones", note: note) {
            if !card.milestones.isEmpty {
                // Equal cells across the width when they fit; otherwise they scroll, so a long
                // goal's Milestones stay readable.
                ViewThatFits(in: .horizontal) {
                    milestoneCells(card, width: nil)
                    ScrollView(.horizontal, showsIndicators: false) {
                        milestoneCells(card, width: milestoneCellWidth)
                    }
                }
            }
        }
    }

    /// The Milestones as cells, each `width` wide, or sharing the width equally when nil.
    private func milestoneCells(_ card: GoalCard, width: CGFloat?) -> some View {
        HStack(spacing: 3) {
            ForEach(card.milestones, id: \.kilograms) { milestone in
                Text(
                    (milestone.passed ? "✓ " : "")
                        + profile.units.text(milestone.kilograms, locale: .current)
                )
                .font(.caption2.weight(.bold))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 6)
                .frame(minWidth: width, maxWidth: width ?? .infinity)
                .padding(.vertical, 8)
                .background(milestone.passed ? Poster.red : Color.clear)
                .foregroundStyle(milestone.passed ? Color.white : Poster.ink)
                .overlay(Rectangle().stroke(Poster.ink, lineWidth: Poster.rowRule))
            }
        }
    }

    /// Spec 015's easier goal, when the Rate card offers one, as a label and an action: what the
    /// Food view's floor message offers (spec 017).
    private func easierGoal(_ view: BodyView) -> FoodScreen.EasierGoal? {
        guard let card = view.goalCard, let ease = card.ease else { return nil }
        return FoodScreen.EasierGoal(label: easeLabel(ease)) {
            store.setGoal(card.goal.eased(by: ease, on: Day(containing: Date(), in: .current)))
        }
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

    /// In place of the goal sections when there is no Weight Goal.
    private var setGoalSection: some View {
        RuledSection(name: "No Weight Goal yet") {
            Button("Set a goal") { showsGoalSheet = true }
                .buttonStyle(BlockButtonStyle())
        }
    }
}

/// A Milestone cell's width when the cells scroll, points.
private let milestoneCellWidth: CGFloat = 72

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
                Section {
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
                        Text(refusal.message(in: units)).foregroundStyle(Poster.red)
                    }
                }
                .posterRows()
                SheetActions(
                    saveDisabled: weight == nil || refusal != nil,
                    save: {
                        if let weight { save(WeighIn(time: time, kilograms: weight)) }
                        dismiss()
                    }
                )
            }
            .posterForm()
            .navigationTitle(isEditing ? "Edit Weigh-in" : "Log Weigh-in")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

/// The pace badge as a solid tag in its colour (spec 015, Pace badge; spec 018).
struct PaceBadgeLabel: View {
    let badge: PaceBadge

    var body: some View {
        let (text, colour): (String, Color) =
            switch badge {
            case .onPace: ("On pace", Poster.green)
            case .behind: ("A bit behind", Poster.amber)
            case .offPace: ("Off pace", Poster.red)
            case .tooFast: ("Too fast", Poster.amber)
            }
        PosterTag(text: text, colour: colour)
    }
}

/// Which half of the Body tab shows (spec 016, Screen).
private enum BodySection {
    case weight
    case food
}
