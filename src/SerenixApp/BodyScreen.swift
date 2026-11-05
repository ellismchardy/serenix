import SerenixCore
import SwiftUI

/// The Body tab (spec 014): draws the Body view, and logs Weigh-ins.
struct BodyScreen: View {
    @ObservedObject var store: BodyStore
    @State private var showsWeighInSheet = false

    var body: some View {
        let view = BodyView(weighIns: store.weighIns, now: Date(), timeZone: .current)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if let trendWeight = view.trendWeight {
                        Text(oneDecimal(trendWeight))
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                        if let last = view.lastWeighIn {
                            Text("kg Trend Weight · last Weigh-in \(oneDecimal(last.kilograms)) kg")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Log your first Weigh-in")
                            .font(.title3.weight(.semibold))
                    }
                    if !view.weighIns.isEmpty {
                        NavigationLink("All Weigh-ins") {
                            WeighInList(store: store)
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
                    showsWeighInSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Log a Weigh-in")
            }
            .sheet(isPresented: $showsWeighInSheet) {
                WeighInSheet(lastWeight: view.lastWeighIn?.kilograms) { store.add($0) }
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
}

/// A weight to one decimal, with the phone's own decimal separator.
private func oneDecimal(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(1)))
}

/// Logs one Weigh-in, or edits one: the last weight filled in, and an editable date and time
/// (spec 014). The field is text, parsed on every keystroke, because a number field only updates
/// when it commits and the decimal pad has no Return key. A refused Weigh-in isn't saved; the
/// sheet shows why.
struct WeighInSheet: View {
    let lastWeight: Double?
    let save: (WeighIn) -> Void
    private let isEditing: Bool
    @State private var text = ""
    @State private var time: Date
    @Environment(\.dismiss) private var dismiss

    /// `editing` fills in that Weigh-in at its full precision, so saving it untouched never
    /// rounds a stored value.
    init(editing: WeighIn? = nil, lastWeight: Double?, save: @escaping (WeighIn) -> Void) {
        self.lastWeight = lastWeight
        self.save = save
        isEditing = editing != nil
        _time = State(initialValue: editing?.time ?? Date())
        _text = State(initialValue: editing.map { $0.kilograms.formatted(.number) } ?? "")
    }

    private var weight: Double? {
        try? Double(text, format: .number)
    }

    private var refusal: WeighInRefusal? {
        weight.flatMap { WeighIn(time: time, kilograms: $0).refusal(now: Date()) }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Weight (kg)", text: $text)
                    .keyboardType(.decimalPad)
                DatePicker("Taken", selection: $time, in: ...Date())
                if let refusal {
                    Text(refusal.message).foregroundStyle(.red)
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
            .onAppear {
                if text.isEmpty, let lastWeight { text = oneDecimal(lastWeight) }
            }
        }
    }
}
