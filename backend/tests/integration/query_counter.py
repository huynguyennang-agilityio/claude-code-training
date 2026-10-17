"""Count the SQL statements a block of code sends, to catch N+1 queries.

    with query_counter.measure() as queries:
        ...
    assert len(queries) <= 3, queries.text()

Transaction control (`SAVEPOINT`, `RELEASE`, `BEGIN`, `COMMIT`, `ROLLBACK`) is not counted,
so the savepoints the `session` fixture uses don't change the numbers. The identity map
hides queries, so call `session.expunge_all()` before measuring a read.
"""

from collections.abc import Iterator
from contextlib import contextmanager
from typing import Any

from sqlalchemy import event
from sqlalchemy.engine import Engine

_TRANSACTION_CONTROL = ("SAVEPOINT", "RELEASE", "BEGIN", "COMMIT", "ROLLBACK")


class Statements(list[str]):
    """The statements sent so far, with a printable form for assertion messages."""

    def text(self) -> str:
        return "\n".join(f"{number}. {sql}" for number, sql in enumerate(self, 1))


class QueryCounter:
    def __init__(self, engine: Engine) -> None:
        self._engine = engine

    @contextmanager
    def measure(self) -> Iterator[Statements]:
        statements = Statements()

        def record(_conn: Any, _cursor: Any, statement: str, *_args: Any) -> None:
            if not statement.lstrip().upper().startswith(_TRANSACTION_CONTROL):
                statements.append(" ".join(statement.split()))

        event.listen(self._engine, "before_cursor_execute", record)
        try:
            yield statements
        finally:
            event.remove(self._engine, "before_cursor_execute", record)
