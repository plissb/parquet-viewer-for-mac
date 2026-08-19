import Foundation
import Observation

enum SessionPhase: Equatable {
    case loading
    case ready
    case failed(String)
}

@MainActor
@Observable
final class ParquetSession {
    let url: URL
    private let engine = ParquetEngine()

    var phase: SessionPhase = .loading
    var overview: FileOverview?
    var columns: [ColumnNode] = []
    var stats: [String: ColumnStats] = [:]
    var page: DataPage?
    var pageSize = 200
    var pageOffset = 0
    var columnQuery = ""
    var selectedColumnID: String?
    var selectedRowIndexes = IndexSet()
    var focusedRowIndex: Int?
    var focusedColumnID: String?
    var filterDraft = ""
    var appliedFilter: String?
    var filterError: String?
    var queryDraft = "SELECT *\nFROM data\n"
    var appliedQuery: String?
    var queryError: String?
    var revealTick = 0

    init(url: URL) {
        self.url = url
    }

    var filteredColumns: [ColumnNode] {
        let query = columnQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return columns }
        return columns.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var selectedColumn: ColumnNode? {
        displayColumns.first { $0.id == selectedColumnID } ?? columns.first { $0.id == selectedColumnID }
    }

    var isQueryActive: Bool { appliedQuery != nil }
    var isFilterActive: Bool { appliedFilter != nil }

    var currentSource: ResultSource {
        if let appliedQuery {
            return .sql(appliedQuery)
        }
        return .table(whereClause: appliedFilter)
    }

    var displayColumns: [ColumnNode] {
        guard let page else { return columns }
        return page.columns.enumerated().map { index, name in
            if let existing = columns.first(where: { $0.name == name }) {
                return existing
            }
            let type = page.columnTypes.indices.contains(index) ? page.columnTypes[index] : "VARCHAR"
            return ColumnNode(id: name, name: name, duckType: type)
        }
    }

    var selectedStats: ColumnStats? {
        guard let selectedColumn else { return nil }
        return stats[selectedColumn.name] ?? stats[selectedColumn.id]
    }

    var canCopyCell: Bool {
        guard let page, let row = focusedRowIndex, page.rows.indices.contains(row) else {
            return false
        }
        if focusedColumnID == nil { return true }
        return focusedColumnID.map { page.columns.contains($0) } ?? false
    }

    var canGoPrevious: Bool { pageOffset > 0 }
    var canGoNext: Bool {
        guard let page else { return false }
        return pageOffset + page.rows.count < Int(clamping: page.totalRows)
    }

    func load() async {
        phase = .loading
        do {
            try await engine.open(url: url)
            let pageSize = self.pageSize
            async let overview = engine.fileOverview()
            async let schema = engine.schema()
            async let stats = engine.columnStats()
            async let page = engine.page(offset: 0, limit: pageSize)
            self.overview = try await overview
            self.columns = try await schema
            self.stats = try await stats
            self.page = try await page
            self.pageOffset = 0
            if selectedColumnID == nil {
                selectedColumnID = columns.first?.id
            }
            phase = .ready
            revealTick += 1
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func goToPage(offset: Int) async {
        do {
            try await reloadPage(offset: offset)
        } catch {
            if isQueryActive {
                queryError = error.localizedDescription
            } else {
                filterError = error.localizedDescription
            }
        }
    }

    func applyFilter() async {
        let text = filterDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        appliedQuery = nil
        queryError = nil
        appliedFilter = text.isEmpty ? nil : text
        do {
            try await reloadPage(offset: 0)
            filterError = nil
        } catch {
            appliedFilter = nil
            filterError = error.localizedDescription
        }
    }

    func clearFilter() async {
        filterDraft = ""
        appliedFilter = nil
        filterError = nil
        await goToPage(offset: 0)
    }

    func runQuery() async {
        let text = SQLQuotes.stripTrailingSemicolons(queryDraft)
        guard !text.isEmpty else {
            queryError = "Query is empty."
            return
        }
        appliedFilter = nil
        filterError = nil
        appliedQuery = text
        do {
            try await reloadPage(offset: 0)
            queryError = nil
        } catch {
            appliedQuery = nil
            queryError = error.localizedDescription
        }
    }

    func clearQuery() async {
        queryDraft = "SELECT *\nFROM data\n"
        appliedQuery = nil
        queryError = nil
        await goToPage(offset: 0)
    }

    func changePageSize(_ size: Int) async {
        pageSize = size
        await goToPage(offset: 0)
    }

    func nextPage() async {
        guard canGoNext else { return }
        await goToPage(offset: pageOffset + pageSize)
    }

    func previousPage() async {
        guard canGoPrevious else { return }
        await goToPage(offset: max(0, pageOffset - pageSize))
    }

    func copySelection() {
        guard let page else { return }
        let rows = selectedRows(from: page)
        if rows.isEmpty {
            Pasteboard.write(CellFormatter.tsv(columns: page.columns, rows: page.rows))
            return
        }
        Pasteboard.write(CellFormatter.tsv(columns: page.columns, rows: rows))
    }

    func copyCell() {
        guard let page, let row = focusedRowIndex, page.rows.indices.contains(row) else { return }
        if let column = focusedColumnID {
            Pasteboard.write(CellFormatter.copyValue(page.cell(row: row, column: column)))
            return
        }
        Pasteboard.write("\(page.offset + row + 1)")
    }

    func focusCell(row: Int?, column: String?) {
        focusedRowIndex = row
        if let column {
            focusedColumnID = column
            selectedColumnID = column
        } else if row == nil {
            focusedColumnID = nil
        }
    }

    func selectedRows(from page: DataPage) -> [[String?]] {
        selectedRowIndexes.sorted().compactMap { index in
            page.rows.indices.contains(index) ? page.rows[index] : nil
        }
    }

    func copyPage() {
        guard let page else { return }
        Pasteboard.write(CellFormatter.tsv(columns: page.columns, rows: page.rows))
    }

    func close() async {
        await engine.close()
    }

    private func reloadPage(offset: Int) async throws {
        let bounded = max(0, offset)
        page = try await engine.page(offset: bounded, limit: pageSize, source: currentSource)
        pageOffset = bounded
        selectedRowIndexes = []
        focusedRowIndex = nil
        focusedColumnID = nil
    }
}
