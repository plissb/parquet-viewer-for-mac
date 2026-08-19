import SwiftUI

struct InspectorView: View {
    let url: URL
    @State private var session: ParquetSession
    @State private var appeared = false
    @AppStorage("showsColumnRail") private var showsColumnRail = true
    @AppStorage("showsSpecPlate") private var showsSpecPlate = true
    @AppStorage("showsFilterBar") private var showsFilterBar = false
    @AppStorage("showsQueryEditor") private var showsQueryEditor = false

    init(url: URL) {
        self.url = url
        _session = State(initialValue: ParquetSession(url: url))
    }

    var body: some View {
        Group {
            switch session.phase {
            case .loading:
                loading
            case .failed(let message):
                failure(message)
            case .ready:
                ready
            }
        }
        .background(Palette.canvas)
        .task(id: url) {
            session = ParquetSession(url: url)
            appeared = false
            await session.load()
            withAnimation(.easeOut(duration: 0.22)) {
                appeared = true
            }
        }
        .onDisappear {
            Task { await session.close() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .copyCellRequested)) { _ in
            session.copyCell()
        }
        .onReceive(NotificationCenter.default.publisher(for: .copyRowsRequested)) { _ in
            session.copySelection()
        }
    }

    private var loading: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Reading \(url.lastPathComponent)")
                .font(Typeface.display(20))
                .foregroundStyle(Palette.ink)
            Text("Footer, schema, then the first plank of rows.")
                .font(Typeface.ui(13))
                .foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: 14) {
            Text("Could not open this file")
                .font(Typeface.display(24))
                .foregroundStyle(Palette.ink)
            Text(message)
                .font(Typeface.mono(12))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
            Button("Try another…") {
                Workspace.shared.presentOpenPanel()
            }
            .buttonStyle(.bordered)
            .tint(Palette.brass)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private var ready: some View {
        VSplitView {
            HSplitView {
                if showsColumnRail {
                    ColumnRail(session: session) {
                        withAnimation(.easeOut(duration: 0.16)) {
                            showsColumnRail = false
                        }
                    }
                    .frame(minWidth: 220, idealWidth: 248, maxWidth: 340)
                    .opacity(appeared ? 1 : 0)
                    .offset(x: appeared ? 0 : -8)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }

                VStack(spacing: 0) {
                    if showsQueryEditor {
                        QueryEditor(session: session) {
                            withAnimation(.easeOut(duration: 0.16)) {
                                showsQueryEditor = false
                            }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if showsFilterBar {
                        FilterBar(session: session) {
                            withAnimation(.easeOut(duration: 0.16)) {
                                showsFilterBar = false
                            }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if let page = session.page {
                        DataGridView(
                            page: page,
                            columns: session.displayColumns,
                            selectedColumnID: session.selectedColumnID,
                            selectedRowIndexes: session.selectedRowIndexes,
                            focusedRowIndex: session.focusedRowIndex,
                            focusedColumnID: session.focusedColumnID,
                            onSelect: { rows, column in
                                session.selectedRowIndexes = rows
                                if let column {
                                    session.selectedColumnID = column
                                }
                            },
                            onFocusCell: { row, column in
                                session.focusCell(row: row, column: column)
                            },
                            onCopyCell: {
                                session.copyCell()
                            },
                            onCopyRows: {
                                session.copySelection()
                            }
                        )
                        .background(Palette.plank)
                    }
                    PaginationBar(session: session)
                }
                .opacity(appeared ? 1 : 0)
            }

            if showsSpecPlate, let overview = session.overview {
                SpecPlate(
                    overview: overview,
                    column: session.selectedColumn,
                    stats: session.selectedStats
                ) {
                    withAnimation(.easeOut(duration: 0.16)) {
                        showsSpecPlate = false
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(url.lastPathComponent)
                        .font(Typeface.ui(13, weight: .medium))
                    if let overview = session.overview {
                        Text(toolbarSummary(overview))
                            .font(Typeface.mono(10))
                            .foregroundStyle(Palette.muted)
                    }
                }
            }
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        showsColumnRail.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.leading")
                }
                .help(showsColumnRail ? "Hide columns" : "Show columns")
                .accessibilityLabel(showsColumnRail ? "Hide columns" : "Show columns")

                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        showsSpecPlate.toggle()
                    }
                } label: {
                    Image(systemName: "rectangle.bottomhalf.inset.filled")
                }
                .help(showsSpecPlate ? "Hide file details" : "Show file details")
                .accessibilityLabel(showsSpecPlate ? "Hide file details" : "Show file details")

                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        showsFilterBar.toggle()
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .help(showsFilterBar ? "Hide filter" : "Show filter")
                .accessibilityLabel(showsFilterBar ? "Hide filter" : "Show filter")

                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        showsQueryEditor.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                }
                .help(showsQueryEditor ? "Hide query" : "Show query")
                .accessibilityLabel(showsQueryEditor ? "Hide query" : "Show query")

                Button("Copy Cell") {
                    session.copyCell()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(!session.canCopyCell)
                .help("Copy the clicked cell")

                Button("Copy Rows") {
                    session.copySelection()
                }
                .keyboardShortcut("c", modifiers: .command)
                .disabled(TextEditing.isActive)
                .help("Copy the selected rows, or the page, as TSV")
            }
        }
    }

    private func toolbarSummary(_ overview: FileOverview) -> String {
        let rows = CountFormat.string(overview.rowCount)
        let cols = "\(overview.columnCount) cols"
        let size = ByteFormat.string(overview.fileSize)
        let codec = overview.compressionCodecs.first ?? "plain"
        return "\(rows) rows · \(cols) · \(size) · \(codec)"
    }
}
