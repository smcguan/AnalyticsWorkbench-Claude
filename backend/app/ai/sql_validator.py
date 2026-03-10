from __future__ import annotations

import re


_BLOCKED_KEYWORDS = [
    "insert",
    "update",
    "delete",
    "drop",
    "alter",
    "create",
    "copy",
    "attach",
    "detach",
    "call",
]


def validate_generated_sql(sql: str) -> tuple[bool, str]:
    s = (sql or "").strip()
    if not s:
        return False, "Generated SQL is empty."

    lowered = s.lower()

    if ";" in s.rstrip(";"):
        return False, "Multiple SQL statements are not allowed."

    if not (lowered.startswith("select") or lowered.startswith("with")):
        return False, "Only SELECT and WITH queries are allowed."

    for token in _BLOCKED_KEYWORDS:
        if re.search(rf"\b{token}\b", lowered):
            return False, f"Blocked SQL keyword detected: {token}"

    return True, ""