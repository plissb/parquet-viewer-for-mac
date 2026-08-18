# Parquet Viewer

A native macOS inspector for Apache Parquet files. Open a file, read the schema and footer, and page through rows without loading the whole table into memory.

## Requirements

- macOS 15+
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Build

```bash
xcodegen generate
xcodebuild -scheme ParquetViewer -destination 'platform=macOS' test
```

Or open `ParquetViewer.xcodeproj` and run the **Parquet Viewer** scheme.

The first compile downloads and builds [DuckDB Swift](https://github.com/duckdb/duckdb-swift). That takes a few minutes.

## Use

- Drop a `.parquet` file on the empty window, or **File → Open** (`⌘O`)
- Search columns in the left rail
- Page through rows with the bar under the grid, or `⌥←` / `⌥→`
- `⌘C` copies the selected cell, row, or the current page as TSV

Reading stays on disk. The first open loads the footer, schema, column stats, and the first 200 rows.

## Fixtures

```bash
python3 Fixtures/generate.py
```

Creates `flat`, `nested`, `empty`, `wide`, and `O'Brien` sample files used by the tests.
