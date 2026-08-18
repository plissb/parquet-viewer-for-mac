#!/usr/bin/env python3
"""Generate committed parquet fixtures for tests."""

from pathlib import Path

import duckdb

OUT = Path(__file__).resolve().parent
OUT.mkdir(parents=True, exist_ok=True)
con = duckdb.connect()

con.execute(
    f"""
    COPY (
        SELECT
            i AS id,
            CASE WHEN i % 7 = 0 THEN NULL ELSE 'user_' || i END AS name,
            i * 1.5 AS score,
            i % 2 = 0 AS active,
            DATE '2024-01-01' + INTERVAL (i) DAY AS day,
            TIMESTAMP '2024-01-01 12:00:00' + INTERVAL (i) HOUR AS seen_at
        FROM range(500) t(i)
    ) TO '{OUT / "flat.parquet"}' (FORMAT PARQUET, COMPRESSION SNAPPY)
    """
)

con.execute(
    f"""
    COPY (
        SELECT
            i AS id,
            {{'city': 'City ' || (i % 10), 'zip': 10000 + i}} AS address,
            list_value(i, i + 1, i + 2) AS scores
        FROM range(50) t(i)
    ) TO '{OUT / "nested.parquet"}' (FORMAT PARQUET, COMPRESSION SNAPPY)
    """
)

con.execute(
    f"""
    COPY (
        SELECT * FROM (SELECT 1 AS id, 'x' AS name) WHERE 1 = 0
    ) TO '{OUT / "empty.parquet"}' (FORMAT PARQUET, COMPRESSION SNAPPY)
    """
)

wide_cols = ", ".join(f"i + {n} AS c{n:02d}" for n in range(80))
con.execute(
    f"""
    COPY (
        SELECT i AS id, {wide_cols}
        FROM range(2000) t(i)
    ) TO '{OUT / "wide.parquet"}' (FORMAT PARQUET, COMPRESSION SNAPPY)
    """
)

obrien = OUT / "O'Brien.parquet"
obrien.write_bytes((OUT / "flat.parquet").read_bytes())

print("wrote", *sorted(p.name for p in OUT.glob("*.parquet")), sep="\n  ")
