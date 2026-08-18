import AppKit
import SwiftUI

struct DataGridView: NSViewRepresentable {
    var page: DataPage
    var columns: [ColumnNode]
    var selectedColumnID: String?
    var selectedRowIndexes: IndexSet
    var focusedRowIndex: Int?
    var focusedColumnID: String?
    var onSelect: (IndexSet, String?) -> Void
    var onFocusCell: (Int?, String?) -> Void
    var onCopyCell: () -> Void
    var onCopyRows: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false

        let table = GridTableView()
        table.delegate = context.coordinator
        table.dataSource = context.coordinator
        table.allowsColumnReordering = true
        table.allowsColumnResizing = true
        table.allowsEmptySelection = true
        table.allowsMultipleSelection = true
        table.allowsTypeSelect = true
        table.columnAutoresizingStyle = .noColumnAutoresizing
        table.usesAlternatingRowBackgroundColors = true
        table.gridStyleMask = [.solidVerticalGridLineMask]
        table.rowHeight = 26
        table.intercellSpacing = NSSize(width: 8, height: 0)
        table.style = .plain
        table.headerView = NSTableHeaderView()
        table.doubleAction = #selector(Coordinator.copyFocusedCell(_:))
        table.target = context.coordinator
        table.onCellFocus = { [weak coordinator = context.coordinator] row, column in
            coordinator?.onFocusCell(row, column)
        }

        let menu = NSMenu()
        menu.autoenablesItems = false
        let copyCellItem = NSMenuItem(
            title: "Copy Cell",
            action: #selector(Coordinator.copyFocusedCell(_:)),
            keyEquivalent: ""
        )
        copyCellItem.target = context.coordinator
        let copyRowsItem = NSMenuItem(
            title: "Copy Rows",
            action: #selector(Coordinator.copySelectedRows(_:)),
            keyEquivalent: ""
        )
        copyRowsItem.target = context.coordinator
        menu.addItem(copyCellItem)
        menu.addItem(copyRowsItem)
        table.menu = menu

        scroll.documentView = table
        context.coordinator.tableView = table
        context.coordinator.onSelect = onSelect
        context.coordinator.onFocusCell = onFocusCell
        context.coordinator.onCopyCell = onCopyCell
        context.coordinator.onCopyRows = onCopyRows
        applyTheme(to: table)
        return scroll
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let table = scrollView.documentView as? GridTableView else { return }
        let previous = context.coordinator.page
        let previousFocus = (context.coordinator.focusedRowIndex, context.coordinator.focusedColumnID)
        context.coordinator.page = page
        context.coordinator.columns = columns
        context.coordinator.focusedRowIndex = focusedRowIndex
        context.coordinator.focusedColumnID = focusedColumnID
        context.coordinator.onSelect = onSelect
        context.coordinator.onFocusCell = onFocusCell
        context.coordinator.onCopyCell = onCopyCell
        context.coordinator.onCopyRows = onCopyRows
        table.onCellFocus = { [weak coordinator = context.coordinator] row, column in
            coordinator?.onFocusCell(row, column)
        }
        applyTheme(to: table)

        let wanted = ["#"] + page.columns
        let existing = table.tableColumns.map(\.identifier.rawValue)
        if existing != wanted {
            table.tableColumns.forEach { table.removeTableColumn($0) }
            for (index, name) in wanted.enumerated() {
                let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(name))
                if index == 0 {
                    column.title = "#"
                    column.width = 56
                    column.minWidth = 48
                    column.maxWidth = 80
                } else {
                    let kind = columns.first(where: { $0.name == name })?.kind.label ?? ""
                    column.title = kind.isEmpty ? name : "\(name)  \(kind)"
                    column.width = 148
                    column.minWidth = 80
                }
                table.addTableColumn(column)
            }
        }

        let pageChanged = previous.offset != page.offset
            || previous.limit != page.limit
            || previous.columns != page.columns
            || previous.rows != page.rows
        if pageChanged {
            table.reloadData()
        } else if previousFocus != (focusedRowIndex, focusedColumnID) {
            var rows = IndexSet()
            if let previousRow = previousFocus.0 { rows.insert(previousRow) }
            if let focusedRowIndex { rows.insert(focusedRowIndex) }
            if !rows.isEmpty {
                table.reloadData(forRowIndexes: rows, columnIndexes: IndexSet(integersIn: 0..<table.numberOfColumns))
            }
        }

        if table.selectedRowIndexes != selectedRowIndexes {
            context.coordinator.applyingSelection = true
            table.selectRowIndexes(selectedRowIndexes, byExtendingSelection: false)
            context.coordinator.applyingSelection = false
        }

        if let selectedColumnID,
           let index = table.tableColumns.firstIndex(where: { $0.identifier.rawValue == selectedColumnID }) {
            table.scrollColumnToVisible(index)
        }
    }

    private func applyTheme(to table: NSTableView) {
        table.backgroundColor = NSColor(Palette.plank)
        table.gridColor = NSColor(Palette.hairline)
        table.usesAlternatingRowBackgroundColors = true
        if let header = table.headerView {
            header.wantsLayer = true
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource, NSMenuItemValidation {
        var page = DataPage(columns: [], rows: [], offset: 0, limit: 200, totalRows: 0)
        var columns: [ColumnNode] = []
        var focusedRowIndex: Int?
        var focusedColumnID: String?
        var onSelect: (IndexSet, String?) -> Void = { _, _ in }
        var onFocusCell: (Int?, String?) -> Void = { _, _ in }
        var onCopyCell: () -> Void = {}
        var onCopyRows: () -> Void = {}
        var applyingSelection = false
        weak var tableView: NSTableView?

        func numberOfRows(in tableView: NSTableView) -> Int {
            page.rows.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let tableColumn, page.rows.indices.contains(row) else { return nil }
            let identifier = tableColumn.identifier
            let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
                ?? makeCell(identifier: identifier)

            let isRowNumber = identifier.rawValue == "#"
            let raw: String?
            if isRowNumber {
                raw = "\(page.offset + row + 1)"
            } else if let index = page.columns.firstIndex(of: identifier.rawValue) {
                raw = page.rows[row][index]
            } else {
                raw = nil
            }

            let isFocused = row == focusedRowIndex
                && (
                    (isRowNumber && focusedColumnID == nil)
                    || focusedColumnID == identifier.rawValue
                )
            let isNull = !isRowNumber && raw == nil
            cell.textField?.stringValue = isRowNumber ? (raw ?? "") : CellFormatter.display(raw)
            cell.textField?.textColor = isNull || isRowNumber
                ? NSColor(Palette.muted)
                : NSColor(Palette.ink)
            cell.textField?.font = .monospacedSystemFont(ofSize: 11.5, weight: isRowNumber ? .medium : .regular)
            cell.textField?.alignment = isRowNumber ? .right : .left
            cell.toolTip = raw
            cell.wantsLayer = true
            cell.layer?.cornerRadius = 3
            cell.layer?.backgroundColor = isFocused ? NSColor(Palette.selected).cgColor : nil
            return cell
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !applyingSelection, let table = notification.object as? NSTableView else { return }
            var columnID: String?
            let clicked = table.clickedColumn
            if clicked >= 0, table.tableColumns.indices.contains(clicked) {
                let name = table.tableColumns[clicked].identifier.rawValue
                if name != "#" { columnID = name }
            }
            onSelect(table.selectedRowIndexes, columnID)
        }

        func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
            if menuItem.action == #selector(copyFocusedCell(_:)) {
                return focusedRowIndex != nil
            }
            if menuItem.action == #selector(copySelectedRows(_:)) {
                return tableView?.selectedRowIndexes.isEmpty == false || focusedRowIndex != nil
            }
            return true
        }

        @objc func copyFocusedCell(_ sender: Any?) {
            if let table = sender as? NSTableView {
                focusFromClick(on: table)
            } else if let table = tableView {
                focusFromClick(on: table)
            }
            onCopyCell()
        }

        @objc func copySelectedRows(_ sender: Any?) {
            onCopyRows()
        }

        private func focusFromClick(on table: NSTableView) {
            let row = table.clickedRow
            let column = table.clickedColumn
            guard row >= 0 else { return }
            var name: String?
            if column >= 0, table.tableColumns.indices.contains(column) {
                let identifier = table.tableColumns[column].identifier.rawValue
                name = identifier == "#" ? nil : identifier
            }
            onFocusCell(row, name)
        }

        private func makeCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
            let cell = NSTableCellView()
            cell.identifier = identifier
            let field = NSTextField(labelWithString: "")
            field.lineBreakMode = .byTruncatingTail
            field.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(field)
            cell.textField = field
            NSLayoutConstraint.activate([
                field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                field.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
            return cell
        }
    }
}

private final class GridTableView: NSTableView {
    var onCellFocus: ((Int, String?) -> Void)?

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        focusCell(at: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        focusCell(at: event)
        return super.menu(for: event)
    }

    private func focusCell(at event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let row = self.row(at: location)
        let column = self.column(at: location)
        guard row >= 0 else { return }
        var name: String?
        if column >= 0, tableColumns.indices.contains(column) {
            let identifier = tableColumns[column].identifier.rawValue
            name = identifier == "#" ? nil : identifier
        }
        onCellFocus?(row, name)
    }
}
