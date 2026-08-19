import SwiftUI

struct PaginationBar: View {
    @Bindable var session: ParquetSession

    var body: some View {
        HStack(spacing: 12) {
            Button {
                Task { await session.previousPage() }
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!session.canGoPrevious)
            .help("Previous page (⌥←)")
            .keyboardShortcut(.leftArrow, modifiers: .option)

            Text(rangeLabel)
                .font(Typeface.mono(11))
                .foregroundStyle(Palette.ink)
                .monospacedDigit()

            if session.isQueryActive {
                Text("QUERY")
                    .font(Typeface.mono(9, weight: .medium))
                    .tracking(0.6)
                    .foregroundStyle(Palette.brass)
            } else if session.isFilterActive {
                Text("FILTER")
                    .font(Typeface.mono(9, weight: .medium))
                    .tracking(0.6)
                    .foregroundStyle(Palette.brass)
            }

            if session.selectedRowIndexes.count > 0 {
                Text(selectionLabel)
                    .font(Typeface.mono(11))
                    .foregroundStyle(Palette.brass)
                    .monospacedDigit()
            }

            Button {
                Task { await session.nextPage() }
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!session.canGoNext)
            .help("Next page (⌥→)")
            .keyboardShortcut(.rightArrow, modifiers: .option)

            Spacer()

            Picker("Rows", selection: pageSizeBinding) {
                Text("50").tag(50)
                Text("200").tag(200)
                Text("500").tag(500)
            }
            .labelsHidden()
            .frame(width: 72)
            .help("Rows per page")

            Button("Copy page") {
                session.copyPage()
            }
            .help("Copy the current page as TSV")
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Palette.well)
        .overlay(alignment: .top) { Rectangle().fill(Palette.hairline).frame(height: 1) }
    }

    private var rangeLabel: String {
        guard let page = session.page else { return "—" }
        if page.rows.isEmpty {
            return "0 of \(CountFormat.string(page.totalRows))"
        }
        let start = page.offset + 1
        let end = page.endRow
        return "\(CountFormat.string(Int64(start)))–\(CountFormat.string(Int64(end))) of \(CountFormat.string(page.totalRows))"
    }

    private var selectionLabel: String {
        let count = session.selectedRowIndexes.count
        return count == 1 ? "1 selected" : "\(count) selected"
    }

    private var pageSizeBinding: Binding<Int> {
        Binding(
            get: { session.pageSize },
            set: { size in
                Task { await session.changePageSize(size) }
            }
        )
    }
}
