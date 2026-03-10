from __future__ import annotations

import json
from typing import Any


def build_generate_sql_prompt(context: dict[str, Any], question: str) -> str:
    compact_context = {
        "dataset_name": context.get("dataset_name"),
        "table_name": "dataset",
        "columns": context.get("columns", []),
        "sample_rows": context.get("sample_rows", []),
    }

    return f"""
You are generating DuckDB SQL for a local analytics application.

Rules:
1. Return valid JSON only.
2. Do not use markdown.
3. Do not use code fences.
4. Do not include commentary outside JSON.
5. SQL must be DuckDB-compatible.
6. Use only this table name: dataset
7. Use only columns listed in the schema context.
8. Do not invent columns.
9. Only generate read-only SQL.
10. Allowed SQL starts with SELECT or WITH.
11. If the question cannot be answered from the dataset schema/context, return an error JSON response.
12. Keep SQL as simple and direct as possible.

Required JSON response shape:
{{
  "status": "ok" or "error",
  "sql": "SQL string or empty string",
  "message": "short human-readable message",
  "warnings": ["optional warning strings"]
}}

Dataset context:
{json.dumps(compact_context, ensure_ascii=False, default=str)}

User question:
{question}
""".strip()