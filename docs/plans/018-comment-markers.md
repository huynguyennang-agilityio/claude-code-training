# Plan 018: One comment per Claude workflow, without overwrites

Status: approved
Approved: 2026-10-23
Issues: #83

## Context

`claude-review.yml` ([plan 014](014-claude-github-actions.md)) and `claude-security-scan.yml` ([plan 017](017-security-guidance-and-scan.md)) each keep one comment per PR. Each workflow's `post` job finds its comment by a hidden marker, edits that comment, or creates one if none exists. Both workflows post as the same user, `github-actions[bot]`.

The two workflows find their comment in different ways:

| Workflow | How it finds its comment | Marker text in the model's output |
| --- | --- | --- |
| `claude-review.yml` (line 188) | first bot comment whose body **contains** `<!-- claude-review -->` | left as it is |
| `claude-security-scan.yml` (line 216, since #80) | first bot comment whose body **ends with** `<!-- claude-security-scan -->` | its own marker is removed |

The review of #80 found the gap that remains. Suppose a security scan report quotes the review's post step, so its text contains `<!-- claude-review -->`. If the scan posts first, the review's `post` job then matches the scan comment and replaces it with the review. The scan comment is lost, and the next scan creates a second one.

Reviews and scans quote this text whenever a PR touches either workflow, as #80 and #81 did.

A second, smaller problem: the model's text is posted as Markdown, and GitHub hides HTML comments. A report can therefore carry text that readers never see but a later lookup does match. That text can be an echoed marker, or something a prompt-injected run chose to hide.

## Open questions and assumptions

1. **How to neutralise `<!--` (assumption).** In the model's text, `<!--` becomes `< !--`. GitHub does not treat `< !--` as an HTML comment, so it is shown as written. It also reads the same in prose and in code spans or blocks.
   - The obvious alternative is `&lt;!--`. Inside a code span or block, GitHub shows that as the literal text `&lt;!--`, which is harder to read in a review that quotes a workflow.
   - The user can pick the other form when reviewing this plan.
2. **Only the model's text is changed.** The marker that each `post` script adds at the end stays a real HTML comment.
3. **Existing comments keep working.** Every comment the workflows have posted so far ends with its own marker, so the anchored lookup still finds and edits it. Nothing needs migrating.
4. **Scope.** Only the two `post` steps change. The gate, the Claude jobs, permissions and triggers stay as they are. `claude.yml` posts as `claude[bot]` with its own comments and is not touched.

## Approach

CI tooling only. Nothing changes in the app, the API, the schema or the data. No new permissions, secrets or costs.

### `claude-review.yml`, `post` job

- When the script reads the review, it replaces every `<!--` with `< !--`: `jq -r '.review // empty | gsub("<!--"; "< !--")'`.
- The lookup matches only a comment whose body ends with the marker: `test("<!-- claude-review -->\\s*$")` in place of `contains(...)`.
- A comment above the step says why: both workflows post as the same user, and only the trailing marker identifies a comment.

### `claude-security-scan.yml`, `post` job

- The `gsub` that removes only `<!-- claude-security-scan -->` is replaced by the same `gsub("<!--"; "< !--")`. That covers both markers and any future one.
- The anchored lookup stays as it is.

### Why both parts

- **Anchoring** decides which comment belongs to a workflow. On its own it is already enough to stop the overwrite, because the script always adds text after the model's text.
- **Escaping** stops the model from posting hidden HTML comments of any kind. It also keeps the trailing marker as the only HTML comment in the body.

### Docs

None needed. `README.md` and `CLAUDE.md` describe "one comment, edited on later runs", which stays true. The comments in each workflow explain the lookup.

## Risks

- **A comment made before this change that does not end with its marker would be orphaned, and a new comment created.** All comments posted so far end with the marker (assumption 3), so this does not happen today.
- **`< !--` looks slightly odd in quoted code.** The text stays readable, and the change is limited to bot comments.
- **A workflow change can only be fully tested after merge.** For `issue_comment` triggers, both workflows run from `develop`. A PR into `develop` does run both on `opened`, from the PR head, which covers the first post.

## Verification

- `actionlint .github/workflows/*.yml` reports no errors.
- **Lookup, jq run on sample comment lists:**
  - a review comment that quotes `<!-- claude-security-scan -->` inline;
  - a scan comment that quotes `<!-- claude-review -->` inline;
  - each workflow's own comment;
  - a comment by another user.

  Each workflow's filter returns only its own comment.
- **Escaping, jq run on a report** with both markers and `<!-- hidden -->`: every `<!--` comes out as `< !--`.
- **Post script, dry run with a fake `gh`, as in #80:**
  - it creates the comment when none exists;
  - it edits the comment it finds;
  - it fails, posting nothing, on an empty result.
- **Live, on this issue's own PR,** which changes both workflows, so both run on `opened`:
  - the PR ends up with exactly one review comment and one scan comment;
  - each ends with its own marker;
  - neither replaced the other.
- **After merge:** on an open PR, comment `@claude review`, then `@claude security`. Each edits its own comment, and the comment count does not change.

## Ticket evidence

Chore. Scope: the two `post` steps above. Behaviour that must stay the same:
- one review comment and one scan comment per PR, edited on later runs;
- comments posted before this change are still found and edited;
- gates, permissions and triggers are unchanged.

## Issues to create

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `ci: keep one comment per Claude workflow (anchored markers, no HTML comments from the model)` | chore | - [ ] `claude-review.yml` finds its comment only by a trailing `<!-- claude-review -->`<br>- [ ] Both `post` steps turn every `<!--` in the model's text into `< !--`<br>- [ ] `actionlint` clean; jq tests for both lookups and the escaping; post scripts dry-run with a fake `gh`<br>- [ ] The issue's PR ends with exactly one review and one scan comment, each with its own trailing marker<br>- [ ] After merge, `@claude review` and `@claude security` on a PR each edit their own comment (or `Not verified: <reason>`) | none |
