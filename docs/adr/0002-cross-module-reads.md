# ADR 0002: Reading another module's rows for a response

- **Status:** Accepted
- **Date:** 2026-10-16
- **Issue:** #37

## Context

[ADR 0001](0001-architecture.md) says backend modules call each other only through services. The models already have ORM relationships that cross modules (`Run.challenge`, `Challenge.medals`, `Challenge.runs`). [`docs/architecture.md`](../architecture.md) accepts them because they map foreign keys, and says not to use them to reach into another module instead of calling its service.

That left one case open. The existing `ChallengeRead` schema nests `MedalRead`, and `QuestRead` nests a list of `ChallengeRead`. To build those responses, a challenges repository can either eager-load the medal through `Challenge.medals`, or the challenges service can get the medal from `medals.service`. No module has a repository or service yet, so the first one would set the pattern either way.

Two constraints shape the choice:

- An async session can't lazy-load. Every relationship a response schema reads must be eager-loaded, or serialization raises `MissingGreenlet`.
- Today a medal is a stored row with an image URL. The medals module has no logic that runs when a medal is read.

## Decision

A repository may eager-load another module's rows through an existing relationship (`selectinload`) only to nest them, read-only, in a response schema. These go through the owning module's service instead:

- filtering or sorting by another module's columns;
- writing another module's rows;
- business rules on another module's data;
- data the owning module transforms or restricts on read (for example signed URLs or hidden rows).

Adding a new cross-module relationship needs the user's approval.

The ORM cascade on `Challenge.medals` (`all, delete-orphan`) is not a write path: medals are created and changed only through `medals.service`, so don't assign or clear `challenge.medal`. Deleting a challenge may still remove its medal through that cascade, because the `medals.challenge_id` foreign key already has `ON DELETE CASCADE`.

For example, `selectinload(Challenge.medals)` in the challenges repository is allowed so `ChallengeRead` can nest `MedalRead`. Awarding a medal when a run completes a challenge goes through `medals.service`, as in the module diagram in `docs/architecture.md`.

## Alternatives considered

- **Eager-load through relationships with no limits.** It has the same query count and the least code. But nothing would stop a repository from filtering, writing or applying rules on another module's data, which is exactly what "only through services" is meant to prevent.
- **Always go through the other module's service and assemble the response.** It keeps each module's data behind its own service, and service unit tests mock the other service directly. But `ChallengeRead` can't be built from the ORM object with `from_attributes`, so each response is assembled by hand, two levels deep for `QuestRead`. Avoiding N+1 also depends on every caller using a batch method (medals for a list of challenge IDs) instead of one call per challenge.

| | Eager-load with limits (chosen) | Eager-load, no limits | Through the service |
| --- | --- | --- | --- |
| Queries for one quest with its challenges and medals | 3, fixed | 3, fixed | 3 with a batch method; N+1 without |
| Module coupling | Repository knows the related model's relationship; rules and writes stay with the owner | Repository can use any of the other module's data | Only through the service |
| Testability | Service unit tests mock the repository; a missing `selectinload` shows only in integration tests | Same | Service unit tests mock both the repository and the other service |
| `ChallengeRead` / `QuestRead` | Unchanged, built with `from_attributes` | Unchanged | Built by hand from both results |

## Consequences

- Repositories that nest another module's rows need an integration test that serializes the response, so a missing `selectinload` is caught.
- If the medals module gains read-time logic (signed URLs, a CDN prefix, hidden medals), the responses that nest medals must switch to `medals.service` in the same change.
- [`docs/architecture.md`](../architecture.md) and the `fastapi-module` skill state the rule.
