from __future__ import annotations

from typing import Any

import duckdb
from fastapi import HTTPException


def _sql_escape_path(p: str) -> str:
    return p.replace("'", "''")


def build_context(
    dataset_name: str,
    dataset_source_path_fn,
    max_sample_rows: int = 5,
) -> dict[str, Any]:
    """
    Build a compact schema-aware context for the AI SQL generator.
    """

    try:
        src, _is_glob = dataset_source_path_fn(dataset_name)
    except FileNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    except Exception:
        raise HTTPException(status_code=404, detail=f"Dataset not found: {dataset_name}")

    esc = _sql_escape_path(src)

    con = duckdb.connect()

    try:
        schema_cur = con.execute(
            f"DESCRIBE SELECT * FROM read_parquet('{esc}')"
        )

        schema_rows = schema_cur.fetchall()

        columns: list[dict[str, str]] = []

        for row in schema_rows:
            columns.append(
                {
                    "name": str(row[0]),
                    "type": str(row[1]),
                }
            )

        sample_cur = con.execute(
            f"SELECT * FROM read_parquet('{esc}') LIMIT {int(max_sample_rows)}"
        )

        sample_cols = [d[0] for d in sample_cur.description]

        sample_rows_raw = sample_cur.fetchall()

        sample_rows = [
            {k: v for k, v in zip(sample_cols, row)}
            for row in sample_rows_raw
        ]

        return {
            "dataset_name": dataset_name,
            "table_name": "dataset",
            "source_path": src,
            "columns": columns,
            "sample_rows": sample_rows,
        }

    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail=f"Failed to inspect dataset '{dataset_name}': {e}",
        )

    finally:
        con.close()