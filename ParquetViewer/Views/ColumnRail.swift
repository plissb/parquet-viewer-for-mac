import SwiftUI

struct ColumnRail: View {
    @Bindable var session: ParquetSession
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Text("Columns")
                    .font(Typeface.display(16))
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                PanelCloseButton(help: "Hide columns") {
                    onClose()
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 10)

            TextField("Find a column", text: $session.columnQuery)
                .textFieldStyle(.roundedBorder)
                .font(Typeface.ui(12))
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            Divider().overlay(Palette.hairline)

            if session.filteredColumns.isEmpty {
                Text("No matching columns")
                    .font(Typeface.ui(12))
                    .foregroundStyle(Palette.muted)
                    .padding(16)
                Spacer()
            } else {
                List(session.filteredColumns, selection: $session.selectedColumnID) { column in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(column.name)
                                .font(Typeface.mono(12, weight: session.selectedColumnID == column.id ? .bold : .regular))
                                .foregroundStyle(
                                    session.selectedColumnID == column.id
                                        ? Palette.chip(.text)
                                        : Palette.ink
                                )
                                .lineLimit(1)
                            Text(column.duckType)
                                .font(Typeface.mono(10))
                                .foregroundStyle(Palette.muted)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        TypeChip(kind: column.kind)
                    }
                    .padding(.vertical, 4)
                    .tag(column.id)
                    .listRowBackground(
                        (session.selectedColumnID == column.id ? Palette.selected : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    )
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Palette.well)
    }
}
