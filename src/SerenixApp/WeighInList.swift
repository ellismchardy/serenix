import SerenixCore
import SwiftUI

/// Every Weigh-in, newest first, each editable and deletable (spec 015, Weigh-ins). It reads the
/// store itself, so it's never a stale copy, and edits or deletes by row, so a Weigh-in with the
/// same time and weight as another is never touched by mistake.
struct WeighInList: View {
    @ObservedObject var store: BodyStore
    let units: WeightUnits
    @State private var editing: WeighInRow?

    var body: some View {
        let rows = store.rows
        List {
            ForEach(rows) { row in
                Button {
                    editing = row
                } label: {
                    HStack {
                        Text(row.weighIn.time.formatted(date: .abbreviated, time: .shortened))
                        Spacer()
                        Text(units.text(row.weighIn.kilograms, locale: .current))
                            .monospacedDigit()
                    }
                }
                .foregroundStyle(.primary)
            }
            .onDelete { offsets in
                for index in offsets { store.delete(rows[index].id) }
            }
        }
        .navigationTitle("Weigh-ins")
        .sheet(item: $editing) { row in
            WeighInSheet(units: units, editing: row.weighIn, lastWeight: row.weighIn.kilograms) {
                store.replace(row.id, with: $0)
            }
        }
    }
}
