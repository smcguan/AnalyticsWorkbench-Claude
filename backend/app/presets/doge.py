PRESETS = [
    {
        "id": "hcpcs_summary",
        "name": "HCPCS Summary (Paid, Claims, Beneficiaries)",
        "params": {},
        "sql": """
            SELECT
                HCPCS_CODE,
                SUM(TOTAL_PAID) AS total_paid,
                SUM(TOTAL_CLAIMS) AS total_claims,
                SUM(TOTAL_UNIQUE_BENEFICIARIES) AS total_unique_beneficiaries
            FROM dataset
            GROUP BY HCPCS_CODE
            ORDER BY total_paid DESC
            LIMIT 500
        """,
    },
    {
        "id": "hcpcs_over_threshold",
        "name": "HCPCS Over Threshold",
        "params": {
            "threshold": {
                "type": "number",
                "label": "Minimum Total Paid",
                "default": 100000000,
                "required": False,
            }
        },
        "sql": """
            SELECT
                HCPCS_CODE,
                SUM(TOTAL_PAID) AS total_paid,
                SUM(TOTAL_CLAIMS) AS total_claims,
                SUM(TOTAL_UNIQUE_BENEFICIARIES) AS total_unique_beneficiaries
            FROM dataset
            GROUP BY HCPCS_CODE
            HAVING SUM(TOTAL_PAID) >= {threshold}
            ORDER BY total_paid DESC
        """,
    },
    {
        "id": "column_count",
        "name": "Column Count",
        "params": {},
        "sql": """
            SELECT COUNT(*) AS column_count
            FROM (DESCRIBE SELECT * FROM dataset) t
        """,
    },
]