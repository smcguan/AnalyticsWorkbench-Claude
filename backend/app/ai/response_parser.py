from __future__ import annotations

import json
from typing import Any


def _strip_code_fences(text: str) -> str:
    s = (text or "").strip()

    if s.startswith("```"):
        lines = s.splitlines()
        if lines and lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].strip() == "```":
            lines = lines[:-1]
        s = "\n".join(lines).strip()

    return s


def _extract_json_object(text: str) -> str:
    s = _strip_code_fences(text)

    start = s.find("{")
    end = s.rfind("}")

    if start == -1 or end == -1 or end < start:
        raise ValueError("No JSON object found in model response.")

    return s[start:end + 1]


def parse_generate_sql_response(raw_text: str) -> dict[str, Any]:
    try:
        json_text = _extract_json_object(raw_text)
        data = json.loads(json_text)
    except Exception as e:
        return {
            "status": "error",
            "sql": "",
            "message": f"AI returned an invalid response format: {e}",
            "warnings": [],
        }

    status = str(data.get("status", "error")).strip().lower()
    if status not in {"ok", "error"}:
        status = "error"

    sql = str(data.get("sql", "") or "").strip()
    message = str(data.get("message", "") or "").strip()
    warnings = data.get("warnings", [])

    if not isinstance(warnings, list):
        warnings = [str(warnings)]

    warnings = [str(w).strip() for w in warnings if str(w).strip()]

    if status == "ok" and not sql:
        status = "error"
        message = message or "AI reported success but did not return SQL."

    if not message:
        message = "SQL generated successfully." if status == "ok" else "SQL generation failed."

    return {
        "status": status,
        "sql": sql,
        "message": message,
        "warnings": warnings,
    }