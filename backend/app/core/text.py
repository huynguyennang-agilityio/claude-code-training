"""Patterns for text fields that go into PostgreSQL.

PostgreSQL can't store NUL in text, so a NUL would fail inside the driver and answer 500.
Patterns on the schema reject it with a 422 and show up in the OpenAPI document.
"""

# A name or title: one line, no control characters.
SINGLE_LINE_PATTERN = r"^[^\x00-\x1f\x7f]*$"
# Markdown or another long text: line breaks and tabs are fine, NUL is not.
NO_NUL_PATTERN = r"^[^\x00]*$"
