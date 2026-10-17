"""Write the live OpenAPI schema to `docs/api/openapi.json`.

Run from `backend/` after an endpoint or schema changes:

    python -m app.scripts.export_openapi

`tests/unit/test_openapi_snapshot.py` fails while the file and the app differ, so
every API change shows up as a diff of that file in the merge request.
"""

import json
from pathlib import Path

from app.main import create_app

OPENAPI_PATH = Path(__file__).resolve().parents[3] / "docs" / "api" / "openapi.json"
REGENERATE_COMMAND = "python -m app.scripts.export_openapi"


def live_schema() -> dict[str, object]:
    schema: dict[str, object] = json.loads(json.dumps(create_app().openapi()))
    return schema


def render(schema: dict[str, object]) -> str:
    return json.dumps(schema, indent=2, sort_keys=True) + "\n"


def main() -> None:
    OPENAPI_PATH.write_text(render(live_schema()), encoding="utf-8")
    print(f"Wrote {OPENAPI_PATH}")  # noqa: T201


if __name__ == "__main__":
    main()
