import SwiftUI

struct QueryEditor: View {
    @Bindable var session: ParquetSession
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Query")
                    .font(Typeface.display(13))
                    .foregroundStyle(Palette.ink)
                Text("data")
                    .font(Typeface.mono(10, weight: .medium))
                    .foregroundStyle(Palette.brass)
                    .help("The open file is a DuckDB view named data")
                Spacer()
                Button("Run") {
                    Task { await session.runQuery() }
                }
                .keyboardShortcut(.return, modifiers: .command)
                Button("Reset") {
                    Task { await session.clearQuery() }
                }
                PanelCloseButton(help: "Hide query") {
                    onClose()
                }
            }

            HighlightedSQLEditor(
                text: $session.queryDraft,
                fieldNames: session.columns.map(\.name),
                selectedField: session.selectedColumnID,
                onSelectField: { session.selectedColumnID = $0 }
            )
            .frame(minHeight: 88, idealHeight: 110, maxHeight: 180)
            .padding(4)
            .background(Palette.plank, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Palette.hairline, lineWidth: 1)
                    .allowsHitTesting(false)
            )

            HStack(alignment: .top, spacing: 8) {
                if let error = session.queryError {
                    Text(error)
                        .font(Typeface.mono(11))
                        .foregroundStyle(.red)
                        .lineLimit(3)
                } else if session.isQueryActive {
                    Text("Showing query result. Reset to return to the full file.")
                        .font(Typeface.ui(11))
                        .foregroundStyle(Palette.brass)
                } else {
                    Text("SQL against the open file. The table name is data. ⌘↩ to run.")
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
