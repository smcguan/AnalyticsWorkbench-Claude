
"""
File: services/dataset_import.py

Purpose
-------
Provide a single, well-documented import pipeline for Analytics Workbench datasets.

This module accepts user-uploaded dataset files, detects the supported file type,
normalizes the dataset into the project's canonical internal Parquet format, writes
standard metadata, and returns a structured result that can be used by the existing
registration flow.
"""

from __future__ import annotations

import json
import re
import shutil
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import BinaryIO

import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq


# -----------------------------------------------------------------------------
# Data models
# -----------------------------------------------------------------------------

@dataclass
class DatasetColumn:
    name: str
    type: str


@dataclass
class DatasetImportMetadata:
    dataset_id: str
    display_name: str
    registered_name: str
    original_filename: str
    original_type: str
    parquet_path: str
    row_count: int
    column_count: int
    columns: list[DatasetColumn]
    created_at: str


@dataclass
class DatasetImportResult:
    dataset_id: str
    dataset_dir: str
    parquet_path: str
    metadata_path: str
    metadata: DatasetImportMetadata


# -----------------------------------------------------------------------------
# Exceptions
# -----------------------------------------------------------------------------

class DatasetImportError(Exception):
    pass


class UnsupportedDatasetTypeError(DatasetImportError):
    pass


class DatasetValidationError(DatasetImportError):
    pass


class DatasetConversionError(DatasetImportError):
    pass


# -----------------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------------

def detect_file_type(filename: str) -> str:
    suffix = Path(filename).suffix.lower()

    if suffix == ".parquet":
        return "parquet"
    if suffix == ".csv":
        return "csv"
    if suffix == ".xlsx":
        return "xlsx"

    raise UnsupportedDatasetTypeError(
        "Unsupported file type. Supported formats: .parquet, .csv, .xlsx"
    )


def derive_display_name(filename: str) -> str:
    return Path(filename).stem.strip() or "dataset"


def normalize_display_name(display_name: str | None, original_filename: str) -> str:
    """
    Resolve the user-facing dataset name.

    Swagger often sends the literal placeholder value 'string' for optional
    form fields. Treat that as empty input and fall back to the filename.
    """
    if display_name is None:
        return derive_display_name(original_filename)

    cleaned = display_name.strip()

    if not cleaned or cleaned.lower() == "string":
        return derive_display_name(original_filename)

    return cleaned


def make_registered_name(name: str) -> str:
    normalized = name.strip().lower()
    normalized = re.sub(r"[^a-z0-9_\s-]", "", normalized)
    normalized = re.sub(r"[\s-]+", "_", normalized)
    normalized = normalized.strip("_")

    if not normalized:
        normalized = "dataset"

    if normalized[0].isdigit():
        normalized = f"dataset_{normalized}"

    return normalized


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


# -----------------------------------------------------------------------------
# Storage helpers
# -----------------------------------------------------------------------------

def write_uploaded_file(uploaded_file: BinaryIO, destination: Path) -> None:
    try:
        if hasattr(uploaded_file, "seek"):
            uploaded_file.seek(0)

        with destination.open("wb") as output_file:
            shutil.copyfileobj(uploaded_file, output_file)
    except Exception as exc:
        raise DatasetValidationError(f"Failed to save uploaded file: {exc}") from exc

    if not destination.exists() or destination.stat().st_size == 0:
        raise DatasetValidationError("Uploaded file is empty.")


def write_metadata(metadata: DatasetImportMetadata, destination: Path) -> None:
    payload = asdict(metadata)
    payload["columns"] = [asdict(column) for column in metadata.columns]

    with destination.open("w", encoding="utf-8") as output_file:
        json.dump(payload, output_file, indent=2)


# -----------------------------------------------------------------------------
# Conversion helpers
# -----------------------------------------------------------------------------

def dataframe_to_parquet(dataframe: pd.DataFrame, parquet_path: Path, source_label: str) -> None:
    if dataframe is None or dataframe.empty:
        raise DatasetValidationError(f"{source_label} dataset is empty.")

    if len(dataframe.columns) == 0:
        raise DatasetValidationError(f"{source_label} dataset contains no columns.")

    try:
        table = pa.Table.from_pandas(dataframe, preserve_index=False)
        pq.write_table(table, parquet_path)
    except Exception as exc:
        raise DatasetConversionError(
            f"Failed to convert {source_label} dataset to Parquet: {exc}"
        ) from exc


def convert_csv_to_parquet(source_path: Path, parquet_path: Path) -> None:
    try:
        dataframe = pd.read_csv(source_path)
    except Exception as exc:
        raise DatasetValidationError(f"Failed to read CSV file: {exc}") from exc

    dataframe_to_parquet(dataframe, parquet_path, "CSV")


def convert_xlsx_to_parquet(source_path: Path, parquet_path: Path) -> None:
    try:
        dataframe = pd.read_excel(source_path, sheet_name=0, engine="openpyxl")
    except Exception as exc:
        raise DatasetValidationError(f"Failed to read Excel file: {exc}") from exc

    dataframe_to_parquet(dataframe, parquet_path, "Excel")


def normalize_parquet(source_path: Path, parquet_path: Path) -> None:
    try:
        table = pq.read_table(source_path)
        pq.write_table(table, parquet_path)
    except Exception as exc:
        raise DatasetConversionError(f"Failed to normalize Parquet file: {exc}") from exc


def inspect_parquet(parquet_path: Path):
    try:
        table = pq.read_table(parquet_path)
    except Exception as exc:
        raise DatasetValidationError(
            f"Failed to inspect normalized Parquet file: {exc}"
        ) from exc

    columns = [
        DatasetColumn(name=field.name, type=str(field.type))
        for field in table.schema
    ]

    return table.num_rows, columns


# -----------------------------------------------------------------------------
# Main import pipeline
# -----------------------------------------------------------------------------

def import_dataset(
    uploaded_file: BinaryIO,
    original_filename: str,
    display_name: str | None = None,
    registered_root: str | Path = "data/datasets",
) -> DatasetImportResult:

    if not original_filename or not original_filename.strip():
        raise DatasetValidationError("Uploaded file must include a filename.")

    original_type = detect_file_type(original_filename)

    resolved_display_name = normalize_display_name(display_name, original_filename)
    registered_name = make_registered_name(resolved_display_name)

    dataset_id = registered_name
    dataset_dir = Path(registered_root) / registered_name

    if dataset_dir.exists():
        raise DatasetValidationError(
            f"Dataset '{registered_name}' already exists."
        )

    dataset_dir.mkdir(parents=True, exist_ok=False)

    source_upload_path = dataset_dir / f"upload.{original_type}"
    parquet_path = dataset_dir / "source.parquet"
    metadata_path = dataset_dir / "metadata.json"

    write_uploaded_file(uploaded_file, source_upload_path)

    if original_type == "parquet":
        normalize_parquet(source_upload_path, parquet_path)
    elif original_type == "csv":
        convert_csv_to_parquet(source_upload_path, parquet_path)
    elif original_type == "xlsx":
        convert_xlsx_to_parquet(source_upload_path, parquet_path)
    else:
        raise UnsupportedDatasetTypeError(
            f"Unsupported dataset type: {original_type}"
        )

    row_count, columns = inspect_parquet(parquet_path)

    if row_count <= 0:
        raise DatasetValidationError("Imported dataset is empty.")

    metadata = DatasetImportMetadata(
        dataset_id=dataset_id,
        display_name=resolved_display_name,
        registered_name=registered_name,
        original_filename=original_filename,
        original_type=original_type,
        parquet_path=str(parquet_path),
        row_count=row_count,
        column_count=len(columns),
        columns=columns,
        created_at=utc_now_iso(),
    )

    write_metadata(metadata, metadata_path)

    return DatasetImportResult(
        dataset_id=dataset_id,
        dataset_dir=str(dataset_dir),
        parquet_path=str(parquet_path),
        metadata_path=str(metadata_path),
        metadata=metadata,
    )
