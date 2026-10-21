# Plan 013: Set a model for each subagent, and ignore `.ua/`

Status: approved
Approved: 2026-10-21
Issues: #33, #34

## Context

Two small tooling changes, asked for together.

**1. Subagent models.** The four subagents in `.claude/agents/` all say `model: inherit`, so each one runs on whatever model the current session uses:

| Agent | Tools | Model today |
| --- | --- | --- |
| `code-reviewer` | read only | `inherit` |
| `planner` | writes docs, pushes docs branches | `inherit` |
| `fastapi-backend` | edits files | `inherit` |
| `flutter-dev` | edits files | `inherit` |

The problem is `code-reviewer`. It is the gate before a merge and it runs on every PR automatically (`CLAUDE.md`, Phase 5). If the session model is switched to a cheaper one, as `/model claude-sonnet-5-5` did partway through the hook work, the reviewers get weaker with no sign of it. The same holds for `planner`: a weak plan spreads into every issue and PR that follows.

The reviews of the three hook PRs (#24, #30, #31) each used about 30 to 34 thousand subagent tokens and found real defects (a symlink that escaped the project, quoted values hiding a git command), which is the work that needs a strong model.

**2. `.ua/`.** The Understand-Anything plugin writes its knowledge graphs to `.ua/` in the repo root. They are generated, and today they show up as untracked files. A local, uncommitted line in `.gitignore` already does this and has been in the working tree through the last three PRs.

## Open questions and assumptions

1. **Aliases, not full model IDs (assumption).** The frontmatter will say `model: opus` or `model: sonnet`, which follow the newest Opus or Sonnet (Opus 5.5 and Sonnet 5.5 today). The alternative is a pinned ID such as `claude-opus-5-5`, which never changes by itself but has to be edited by hand at every upgrade. Say if you prefer pinned IDs.
2. **The choice per agent (the user decides).** The proposal is in the table under Approach. `haiku` is not proposed for any of the four: each one needs reasoning and rule following.
3. **Hard backend or mobile tasks can override the model per call (assumption).** The `Agent` tool takes a `model` argument, so a deadlock fix or a migration that could lose data can run `fastapi-backend` on `opus` without changing the default.
4. **The built-in agents (`Explore`, `Plan`, `general-purpose`, ...) are not touched.** They are not configured in this repo.
5. **Model names are not written into `CLAUDE.md` rules (assumption).** One sentence points to the frontmatter as the place where models are set, so the list cannot go stale in two files.
6. **`.ua/` only (assumption).** The change adds exactly that entry, as the local line does. It does not ignore anything else.

## Approach

Tooling only. No mobile, backend, API, schema or database change.

**Issue 1: models.** Change only the `model:` line in each file:

| File | From | To | Why |
| --- | --- | --- | --- |
| `.claude/agents/code-reviewer.md` | `inherit` | `opus` | Merge gate, runs on every PR, needs to probe for bypasses and edge cases. Pinned so a cheaper session model cannot weaken it. |
| `.claude/agents/planner.md` | `inherit` | `opus` | A plan sets the scope of every later issue and PR. The issue creation it also does is mechanical but cheap. |
| `.claude/agents/fastapi-backend.md` | `inherit` | `sonnet` | Implements against fixed architecture rules, with tests, `ruff`, `mypy` and the hooks checking the result. |
| `.claude/agents/flutter-dev.md` | `inherit` | `sonnet` | Same, with `flutter analyze`, the tests and the theme token guard checking the result. |

- `CLAUDE.md`: one sentence in Phase 5 (next to the line that runs `code-reviewer`) saying that each subagent's model is set in the `model:` line of `.claude/agents/<name>.md`, and that a hard task can override it for one call.
- Nothing else in the agent files changes (name, description, tools and the body stay as they are).

This touches **external cost**: `code-reviewer` and `planner` move to a more expensive model whatever the session uses, and `fastapi-backend` and `flutter-dev` move to a cheaper one when the session is on `opus`. The approval must cover this. There is no data, security or production effect.

**Issue 2: `.gitignore`.** Add to the end of `.gitignore`:

```text
# Understand-Anything knowledge graphs
.ua/
```

## Risks

- **Higher cost for reviews and plans.** Each review is a short, read-only run (about 30 thousand subagent tokens in the three hook PRs). Contained by the proposal keeping the two implementation agents on `sonnet`, and by being easy to undo: set the line back to `inherit`.
- **A `sonnet` implementer is weaker on a hard task.** Contained by the per-call override (assumption 3) and by the tests and hooks that check its output.
- **An alias moves to a new model.** `opus` and `sonnet` follow the newest version, so behaviour can change at an upgrade. Accepted (assumption 1).
- **A wrong value in the frontmatter** could stop an agent from starting. Contained by checking that each agent starts and reports the expected model (see Verification).
- **`.ua/` hides something worth committing.** Unlikely: the directory only holds generated graphs. The entry is one line and easy to remove.

## Verification

Issue 1:

- `git diff` shows exactly four changed lines, one `model:` line per agent file, plus the `CLAUDE.md` sentence.
- Start each of the four agents with the prompt "Reply with the model ID you are running as, and nothing else", and compare with the table. This is what the model reports about itself, so it is evidence and not proof; the frontmatter is the setting.
- Run `code-reviewer` on a real PR once and confirm the review comes back in the usual format (five headings and a verdict).
- Not checked: how much the change costs over a month, because there is no usage history to compare against.

Issue 2:

- `git check-ignore -v .ua/graph.json` names the new line, and `git status --short` shows no `.ua/` entry after creating the directory with a file in it.
- `git diff` shows only the two added lines in `.gitignore`.

## Ticket evidence

Chore for both issues: the scope is above. Behaviour that must stay unchanged: the agents' names, descriptions, tools and instructions, and every file the repo already tracks. No images needed. Verification evidence is the commands above and their output.

## Issues to create

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `chore: set a model for each subagent` | chore | - [ ] `code-reviewer` and `planner` say `model: opus`; `fastapi-backend` and `flutter-dev` say `model: sonnet`<br>- [ ] The diff changes only those four `model:` lines in `.claude/agents/` and adds one sentence to `CLAUDE.md`<br>- [ ] Each agent starts and reports the expected model<br>- [ ] `code-reviewer` returns a normal review of a real PR<br>- [ ] Evidence: the diff, the four replies and the review | none |
| 2 | `chore: ignore the Understand-Anything .ua/ directory` | chore | - [ ] `.gitignore` ignores `.ua/` with a comment line above it<br>- [ ] `git check-ignore -v .ua/graph.json` matches the new line, and `git status` does not list `.ua/`<br>- [ ] The diff changes only `.gitignore`<br>- [ ] Evidence: the two commands and their output | none |
