import SwiftUI

struct FilterBar: View {
    @Bindable var session: ParquetSession
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Filter")
                    .font(Typeface.display(13))
                    .foregroundStyle(Palette.ink)
                Text("WHERE")
                    .font(Typeface.mono(10, weight: .medium))
                    .foregroundStyle(Palette.brass)
                HighlightedSQLEditor(
                    text: $session.filterDraft,
                    fieldNames: session.columns.map(\.name),
                    selectedField: session.selectedColumnID,
                    isSingleLine: true,
                    onSelectField: { session.selectedColumnID = $0 },
                    onSubmit: {
                        Task { await session.applyFilter() }
                    }
                )
                .frame(height: 28)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
                .background(Palette.plank, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Palette.hairline, lineWidth: 1)
                        .allowsHitTesting(false)
                )
                .contentShape(Rectangle())
                .opacity(session.isQueryActive ? 0.55 : 1)
                Button("Apply") {
                    Task { await session.applyFilter() }
                }
                Button("Clear") {
                    Task { await session.clearFilter() }
                }
                .disabled(!session.isFilterActive && session.filterDraft.isEmpty)
                PanelCloseButton(help: "Hide filter") {
                    onClose()
                }
            }
            HStack(spacing: 8) {
                if session.isQueryActive {
                    Text("Filter is paused while a query is active.")
                        .font(Typeface.ui(11))
                        .foregroundStyle(Palette.muted)
                } else if let error = session.filterError {
                    Text(error)
                        .font(Typeface.mono(11))
                        .foregroundStyle(.red)
                        .lineLimit(2)
                } else {
                    Text("DuckDB expression against table data. Example: score > 10 AND active")
                        .font(Typeface.ui(11))
                        .foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Palette.well)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.hairline).frame(height: 1) }
    }
}
