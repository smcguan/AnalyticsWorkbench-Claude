from typing import List, Literal
from pydantic import BaseModel


class GenerateSQLRequest(BaseModel):
    dataset: str
    question: str


class GenerateSQLResponse(BaseModel):
    status: Literal["ok", "error"]
    dataset: str
    question: str
    sql: str = ""
    message: str
    warnings: List[str] = []