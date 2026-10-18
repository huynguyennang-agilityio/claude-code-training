"""The JSON examples in `docs/api/*.md` and the files in `docs/api/examples/` agree.

Each ```json block in a contract doc has an `<!-- example: <file> -->` marker
above it. Backend and app tests compare their code with the example files, so a
block that drifts from its file, or a file no doc uses, fails here.
"""

import json
from pathlib import Path

import pytest

from app.core.errors import ErrorResponse
from tests.api_docs import (
    JSON_BLOCK,
    MARKED_BLOCK,
    doc_files,
    example_files,
    load_example,
)


def marked_blocks() -> list[tuple[Path, str, str]]:
    return [
        (doc, match["name"], match["body"])
        for doc in doc_files()
        for match in MARKED_BLOCK.finditer(doc.read_text(encoding="utf-8"))
    ]


def test_contract_docs_exist() -> None:
    assert [doc.name for doc in doc_files()] == ["auth.md", "challenges.md", "runs.md"]
    assert example_files()


@pytest.mark.parametrize("doc", doc_files(), ids=lambda doc: doc.name)
def test_every_json_block_has_an_example_marker(doc: Path) -> None:
    text = doc.read_text(encoding="utf-8")

    assert len(JSON_BLOCK.findall(text)) == len(MARKED_BLOCK.findall(text)), (
        f"Put `<!-- example: <file>.json -->` on the line above each ```json block in {doc.name}."
    )


@pytest.mark.parametrize(
    ("doc", "name", "body"), marked_blocks(), ids=lambda value: str(value)[-40:]
)
def test_block_equals_its_example_file(doc: Path, name: str, body: str) -> None:
    assert json.loads(body) == load_example(name), (
        f"{doc.name}: the block marked {name} differs from docs/api/examples/{name}. "
        "Change the file and the block together."
    )


def test_every_example_file_is_used_by_a_doc() -> None:
    used = {name for _, name, _ in marked_blocks()}

    assert sorted(set(example_files()) - used) == [], "Reference these from a contract doc."


def test_every_marker_names_an_existing_file() -> None:
    used = {name for _, name, _ in marked_blocks()}

    assert sorted(used - set(example_files())) == []


@pytest.mark.parametrize("name", [name for name in example_files() if "/error_" in name])
def test_error_examples_are_valid_error_responses(name: str) -> None:
    ErrorResponse.model_validate(load_example(name))
