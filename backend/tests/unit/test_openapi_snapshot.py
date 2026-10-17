"""`docs/api/openapi.json` matches the schema the app serves.

A schema change then appears as a diff of that file in the merge request, which
is where a breaking change gets noticed. Regenerate it with
`python -m app.scripts.export_openapi` from `backend/`.
"""

import json

from app.scripts.export_openapi import OPENAPI_PATH, REGENERATE_COMMAND, live_schema


def test_openapi_snapshot_is_up_to_date() -> None:
    assert OPENAPI_PATH.exists(), f"Missing {OPENAPI_PATH}. Create it with: {REGENERATE_COMMAND}"

    committed = json.loads(OPENAPI_PATH.read_text(encoding="utf-8"))

    assert committed == live_schema(), (
        f"docs/api/openapi.json is out of date. Regenerate it with: {REGENERATE_COMMAND}"
    )
