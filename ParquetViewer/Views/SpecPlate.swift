import SwiftUI

struct SpecPlate: View {
    let overview: FileOverview
    let column: ColumnNode?
    let stats: ColumnStats?
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Palette.hairline).frame(height: 1)
            HStack(alignment: .top, spacing: 0) {
                fileBlock
                    .frame(maxWidth: .infinity, alignment: .leading)
                Rectangle().fill(Palette.hairline).frame(width: 1)
                columnBlock
                    .frame(maxWidth: .infinity, alignment: .leading)
                PanelCloseButton(help: "Hide file details") {
                    onClose()
                }
                .padding(.top, 2)
                .padding(.leading, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Palette.well)
        .frame(minHeight: 140)
    }

    private var fileBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("File")
                .font(Typeface.display(15))
                .foregroundStyle(Palette.ink)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 6) {
                spec("Rows", CountFormat.string(overview.rowCount))
                spec("Columns", "\(overview.columnCount)")
                spec("Row groups", "\(overview.rowGroupCount)")
                spec("Size", ByteFormat.string(overview.fileSize))
                spec("Version", "v\(overview.formatVersion)")
                spec("Codec", overview.compressionCodecs.joined(separator: ", ").nilIfEmpty ?? "—")
            }
            if let created = overview.createdBy, !created.isEmpty {
                spec("Created by", created)
            }
            if let firstKV = interestingKV {
                spec(firstKV.key, CellFormatter.truncated(firstKV.value, limit: 80))
            }
        }
    }

    private var columnBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Column")
                    .font(Typeface.display(15))
                    .foregroundStyle(Palette.ink)
                if let column {
                    TypeChip(kind: column.kind)
                    Text(column.name)
                        .font(Typeface.mono(12, weight: .medium))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                }
            }

            if let column {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 6) {
                    spec("Duck type", column.duckType)
                    spec("Parquet", column.parquetType ?? "—")
                    spec("Logical", column.logicalType ?? "—")
                    spec("Repetition", column.repetition ?? "—")
                    spec("Nulls", stats?.nullCount.map { CountFormat.string($0) } ?? "—")
                    spec("Distinct", stats?.distinctCount.map { CountFormat.string($0) } ?? "—")
                    spec("Min", stats?.min ?? "—")
                    spec("Max", stats?.max ?? "—")
                    spec("Compressed", stats.map { ByteFormat.string($0.compressedBytes) } ?? "—")
                    spec("Encodings", stats?.encodings.joined(separator: ", ").nilIfEmpty ?? "—")
                }
            } else {
                Text("Select a column to see its plate.")
                    .font(Typeface.ui(12))
                    .foregroundStyle(Palette.muted)
            }
        }
        .padding(.leading, 16)
    }

    private func spec(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label.uppercased())
                .font(Typeface.mono(9, weight: .medium))
                .tracking(0.7)
                .foregroundStyle(Palette.brass)
                .frame(width: 88, alignment: .leading)
            Text(value)
                .font(Typeface.mono(11))
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .help(value)
        }
    }

    private var interestingKV: (key: String, value: String)? {
        let preferred = ["pandas", "ARROW:schema", "created_by", "org.apache.spark.legacyDateTime"]
        for key in preferred {
            if let match = overview.kv.first(where: { $0.key.localizedCaseInsensitiveContains(key) }) {
                return match
            }
        }
        return overview.kv.first
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
