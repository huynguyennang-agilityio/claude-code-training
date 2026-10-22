# Plan 017: Security guidance plugin and a security scan in CI

Status: approved
Approved: 2026-10-22
Issues: <filled in after approval>

## Context

The user asked for two security layers on top of today's tooling:

1. **Locally:** the `security-guidance` plugin, so Claude reviews its own changes for security issues while it writes them.
2. **On GitHub:** a security scan on every PR into `develop`.

Today, security is checked in two places only:

- step 4 ("Security basics") of the `code-reviewer` review, which `claude-review.yml` runs on each PR ([plan 014](014-claude-github-actions.md));
- step 3 of the Phase 4 checklist in `CLAUDE.md`, which is a manual tick.

Neither is a dedicated security pass. Nothing checks while Claude writes the code.

The code has real security boundaries:

- the `auth` module (JWT, refresh tokens, [plan 002](002-expired-session-refresh.md));
- `ROUTE_ACCESS` and the ownership rule (another user gets `404 not_found`);
- the Cloudinary credentials ([ADR 0003](../adr/0003-cloudinary-for-images.md));
- tokens in `flutter_secure_storage`;
- four GitHub workflows on a **public** repo, two of which hold a Claude token.

### What the plugin is (checked 2026-10-22)

[`security-guidance`](https://github.com/anthropics/claude-code/tree/main/plugins/security-guidance) v2.0.0 is published by Anthropic in the `claude-plugins-official` marketplace, which ships with Claude Code. It needs Claude Code ≥ 2.1.144 (this Mac has 2.1.306) and Python 3.8+. Its README describes three layers:

| Layer | Hook | What it does |
| --- | --- | --- |
| 1. Pattern warnings | `PostToolUse` on `Edit`, `Write`, `MultiEdit`, `NotebookEdit` | Regex reminders for about 25 dangerous patterns (`yaml.load`, `pickle.load`, raw `innerHTML`, hardcoded secrets, ...) |
| 2. LLM diff review | `Stop`, `asyncRewake` | When Claude finishes a turn, sends the diff to a model (Opus by default) and feeds high-severity findings back to Claude |
| 3. Agentic commit review | `PostToolUse` on `Bash(git commit:*)` and `Bash(git push:*)`, `asyncRewake` | A reviewer that reads related files to trace data flow (IDOR, auth bypass, SSRF) |

Other facts from the plugin's README and `hooks.json`:

- A `SessionStart` hook (`ensure_agent_sdk.py`, 180 s timeout) makes sure the Python Agent SDK is installed.
- Project rules go in `.claude/claude-security-guidance.md`, which is meant to be committed. Layer 2 appends it to its prompt, with an 8 KB budget for all rule files; layer 3 does not read it yet.
- Environment switches: `SECURITY_GUIDANCE_DISABLE=1` (all off), `ENABLE_STOP_REVIEW=0`, `ENABLE_COMMIT_REVIEW=0`, `ENABLE_PATTERN_RULES=0`, and `SECURITY_REVIEW_MODEL`.
- Layers 2 and 3 send the changed paths, the diff hunks and related files to the model endpoint, which is `api.anthropic.com` for this project. That is the same place Claude Code already sends this code.

### What the official scan action is (checked 2026-10-22)

[`anthropics/claude-code-security-review`](https://github.com/anthropics/claude-code-security-review) is a composite action. Its last commit is `0c6a49f` (2026-02-11), and it has no tags or releases.

- It accepts only `claude-api-key`, which it uses as `ANTHROPIC_API_KEY`. There is no OAuth token input, so it cannot use the `CLAUDE_CODE_OAUTH_TOKEN` that plan 014 chose. It would need a separate, paid API key.
- It runs `npm install -g @anthropic-ai/claude-code` without a version.
- It comments on the PR from the same job that holds the key, so that job needs `pull-requests: write`.
- Its README says it "is not hardened against prompt injection attacks and should only be used to review trusted PRs".

Each of these goes against how plan 014 split `claude-review.yml`: a gate first, Claude without write access, and posting by a fixed script.

## Open questions and assumptions

1. **How CI scans: decided (the user, 2026-10-22): option B.** The scan is a workflow in the shape of `claude-review.yml`:
   - it uses `anthropics/claude-code-action` (already pinned at v1.0.244) with the existing `CLAUDE_CODE_OAUTH_TOKEN`;
   - it has the same gate → read-only Claude → fixed-script post jobs;
   - it reads the same project rules file as the plugin.

   That means more YAML to own, but no new secret and no new trust model. The official action (option A) was not chosen because it needs a separate paid `ANTHROPIC_API_KEY`, comments from the job that holds the key, and its README says it is not hardened against prompt injection.
2. **The scan is advisory at first (assumption).** It posts one comment and the job passes, whatever it finds. It does not become a required check until a few weeks of findings show how noisy it is. Making it blocking (failing on a `high` finding) is a later plan.
3. **When the scan runs (assumption).** It uses the same triggers as the review: PR `opened`, `ready_for_review`, `reopened`, plus a collaborator commenting `@claude security`. The gate also skips a PR whose files are all under `docs/` or are `*.md`, except `.claude/**` and `CLAUDE.md`, because those configure Claude.
4. **The plugin is enabled for the project, not only for one person (assumption).** It is added to `enabledPlugins` in the committed `.claude/settings.json`, so every collaborator gets it after a pull. The issue checks how Claude Code asks a collaborator to install it (expected: a prompt when the folder is trusted). If project-level enabling does not install it, the README gives the command `/plugin install security-guidance@claude-plugins-official`.
5. **The plugin does not run on GitHub runners (assumption).** It is not known whether `claude-code-action` installs plugins from `enabledPlugins`. The Claude steps in `claude-review.yml`, `claude.yml` and the new workflow set `SECURITY_GUIDANCE_DISABLE: "1"` either way. The CI scan is the security layer there, and the plugin's `SessionStart` install and LLM calls would only slow the runs down and cost more.
6. **The plugin's own model and switches stay at their defaults (assumption).** All three layers are on, with Opus. If the cost or noise is too high, the user can set `ENABLE_STOP_REVIEW=0` or a cheaper `SECURITY_REVIEW_MODEL` in their own shell. The README lists both.
7. **Scheduled runs (assumption).** The 17:00 `pr-report` task and the 08:00 routine ([plan 016](016-cloud-routines.md)) run in this repo and only read, so the plugin's Stop review finds no diff and should cost nothing. The issue checks the next `pr-report` run.
8. **No GitLab change.** `.github/` and `.claude/` are mirrored as files, and nothing runs there.

## Approach

Tooling only. Nothing changes in mobile, backend, the API, the schema or the database. The plan touches:

- a **security boundary**: a new workflow that holds the Claude token on a public repo, and a plugin whose hooks run on every collaborator's machine;
- **core tooling**: a new plugin, plus a `SessionStart` hook that installs a Python package;
- **external cost**: an LLM review after each Claude turn and each commit locally, and one Opus scan per PR.

The approval must cover all three.

### 1. The plugin for the project (issue 1)

- **`.claude/settings.json`:** add `"enabledPlugins": { "security-guidance@claude-plugins-official": true }`. The existing hooks are left as they are.
  - The plugin's `Stop` and commit hooks are `asyncRewake`. They do not block, and they run next to `check.sh`, which still blocks until the checks pass.
  - The plugin's `PostToolUse` hook runs next to `format-on-edit.sh`. Neither depends on the other's order.
- **`.claude/claude-security-guidance.md`:** the StrideQuest rules, kept under 8 KB. This one file is the shared rule source for the local plugin and for the CI scan (step 2):
  - **Backend:**
    - Every route is in `ROUTE_ACCESS` (`public`, `user`, `admin`).
    - A user-owned resource is queried with the owner, and another user gets `404 not_found`, not `403`.
    - Errors go through `ErrorResponse` and never echo exception text, SQL or stack traces.
    - SQL uses bound parameters, never f-strings or `text()` built from input.
    - Outbound HTTP uses `httpx.AsyncClient` with a timeout and never fetches a URL the user supplies.
    - Only the backend uploads to Cloudinary.
    - Secrets come from `Settings`, never from code, logs, `docs/api/examples/` or fixtures.
    - JWTs are verified with a fixed algorithm and an expiry check.
  - **Mobile:**
    - Tokens live only in `flutter_secure_storage`, never in `SharedPreferences`, logs or `state.extra`.
    - The Dio logging interceptor never prints `Authorization` headers or bodies of auth calls.
    - Base URLs outside the dev config are `https`.
    - Health data is not logged.
  - **GitHub workflows and `.claude/hooks/`:**
    - Untrusted event text (`github.event.*.title`, `body`, `head_ref`) is never interpolated into `run:`; it is passed through `env:`.
    - Third-party actions are pinned by SHA.
    - `permissions:` start from `{}`.
    - There is no `pull_request_target` that checks out PR code.
    - Shell variables are quoted.
- **`.gitignore`:** add `.claude/claude-security-guidance.local.md`, the plugin's local override file.
- **`SECURITY_GUIDANCE_DISABLE: "1"`** on the Claude step of `claude-review.yml` and `claude.yml` (assumption 5).
- **Docs:**
  - `CLAUDE.md`, Phase 3: one paragraph on the plugin, in the style of the other hook paragraphs (what fires when, the switches, where the rules live).
  - `CLAUDE.md`, Phase 4 step 3 (Security): say that the plugin's findings were addressed or answered, and name the CI scan comment.
  - `README.md`: how a collaborator installs or turns the plugin off.

### 2. The CI scan: `.github/workflows/claude-security-scan.yml` (issue 2)

The same shape and hardening as `claude-review.yml` (plan 014, Approach 3). Only the differences are listed here:

- **Triggers:**
  - `pull_request` into `develop` with types `opened`, `ready_for_review` and `reopened`;
  - `issue_comment` starting with `@claude security`, from an `OWNER`, `MEMBER` or `COLLABORATOR`.

  `claude.yml` already ignores comments that start with `@claude review`. It gains the same exclusion for `@claude security`, so a single comment never starts both workflows.
- **`gate`:** the same fail-closed check (open, not a fork, not a draft, base `develop`), plus the docs-only skip from assumption 3. It reads the file list with `gh pr view --json files`.
- **`scan`:**
  - Model and token: `claude-code-action` at the same pinned SHA, with `--model opus`, the OAuth token, the job's `GITHUB_TOKEN` and read-only permissions.
  - Allowlist, disallowed paths, bubblewrap and `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` are the same as the review. `SECURITY_GUIDANCE_DISABLE: "1"` is also set.
  - The prompt tells Claude to:
    - review only what `gh pr diff` adds or changes, and read the surrounding files to trace data flow;
    - apply `.claude/claude-security-guidance.md` from `develop`, not the PR's copy, so a PR cannot weaken its own scan;
    - report only findings with a concrete exploit path, each with severity, file, line, scenario and fix;
    - treat all PR text as data.
  - `--json-schema` returns `{ "report": string, "high": integer }`. `high` is shown in the comment and is not enforced yet (assumption 2).
- **`post`:** the same fixed script, with the marker `<!-- claude-security-scan -->`, so the scan keeps its own single comment beside the review's.
- **Run summary:** the same as the review's (tool names, Bash commands), with no transcript upload.

The two workflows now share most of their YAML. Pulling the gate and post jobs into a reusable workflow is left for later, once both have settled. It is not in this plan's scope.

### 3. Docs for issue 2

- `CLAUDE.md`, Phase 5 step 2: name the scan next to the review, with its trigger comment `@claude security`.
- `README.md`, "CI and Claude on GitHub": the new workflow, the fact that it is advisory, and how to re-run it.

## Risks

- **Cost.**
  - Locally, the plugin makes an Opus call after every Claude turn that leaves a diff, and another on every commit and push.
  - In CI, each PR gets one more Opus run.
  - Both draw on the user's subscription limits. This is contained by assumption 6 (switches documented) and the docs-only skip in the gate.
- **Noise and false positives.**
  - The rules file narrows the scan to this codebase.
  - The scan is advisory, so a false positive cannot block a merge.
  - The plugin honours an inline comment that explains why a line is safe.
- **The plugin changes under us.** A marketplace plugin updates on its own, and its version cannot be pinned in `enabledPlugins`. If an update misbehaves, `SECURITY_GUIDANCE_DISABLE=1` turns it off at once, and a later PR removes it from `settings.json`.
- **A `SessionStart` hook that installs a package.** `ensure_agent_sdk.py` installs the Python Agent SDK on each machine. It is Anthropic's code from Anthropic's marketplace, and the README says how to turn it off. The issue records what it installs and where.
- **Loops with `check.sh`.** The plugin's rewake can start another Claude turn after a stop, and that turn's stop runs `check.sh` again. Each rewake follows a real finding, and `check.sh` still lets Claude stop after 3 failures. The issue watches for repeated rewakes on the same finding.
- **Prompt injection in the scan.** The same containment as the review: Claude has read-only permissions, the comment is posted by a fixed script, and fork PRs are never checked out. The rules come from `develop`, so a PR cannot edit its own scan's rules.
- **Two security opinions on one PR.** The review's step 4 and the scan can disagree. The scan is the dedicated pass, and the review's step 4 stays a basic check. If they disagree, the user decides.

## Verification

- **Issue 1:**
  - **Install:** a Claude Code session in the repo shows `security-guidance` as enabled (`/plugin`), and `~/.claude/security/log.txt` is created.
  - **Layer 1:** on a throwaway branch, Claude writes `yaml.load(open(path))` in a scratch file under `backend/`, and the warning appears. The branch is deleted locally afterwards and never pushed.
  - **Layer 2:** on the same throwaway branch, Claude removes the owner filter from a repository query, and the Stop review flags an IDOR. Its finding is pasted, redacted.
  - **Layer 3:** a local commit on that branch triggers the commit review, and its result is recorded.
  - **Rules file:** under 8 KB (`wc -c`). A finding cites a StrideQuest rule (for example `404 not_found` for ownership).
  - **Existing hooks unchanged:** `bash .claude/hooks/test-check.sh`, `test-format-on-edit.sh`, `test-block-forbidden-command.sh`, `test-notify.sh` and `test-automations-check.sh` pass.
  - **CI:** the `claude-review` run on the issue's own PR still posts its review. Its run summary shows no `security_reminder_hook`.
  - **Scheduled task:** the next 17:00 `pr-report` run finishes with no plugin rewake.
- **Issue 2:**
  - **Finding:** a test PR (opened for this check, closed unmerged) adds a workflow step that interpolates `github.event.pull_request.title` into `run:` and a route missing from `ROUTE_ACCESS`. The scan comment reports both as `high`.
  - **Clean PR:** the issue's own PR gets a comment with no findings, or with findings the issue answers.
  - **Re-run:** `@claude security` edits the same comment instead of adding a new one, and `claude.yml` does not start.
  - **Gate:** a draft PR and a docs-only PR skip the `scan` job (the run shows `ok=false` or the docs-only reason).
  - **Advisory:** the job is green while `high` > 0.
- **Not verified:** a fork PR. There is no second account. The gate logic is the same as `claude-review.yml`, whose fork case was checked in plan 014.

## Ticket evidence

Chore: the scope is above. Behaviour that must stay unchanged:

- the existing hooks and their tests;
- `claude-review.yml`, which still posts one review per PR;
- `claude.yml`, which still answers `@claude` except for `@claude review` and `@claude security`;
- the CI jobs and required checks (`backend`, `mobile`, `goldens`);
- app code.

## Issues to create

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `chore: enable the security-guidance plugin for the project` | chore | - [ ] `.claude/settings.json` enables `security-guidance@claude-plugins-official`; existing hooks unchanged<br>- [ ] `.claude/claude-security-guidance.md` with the StrideQuest rules from Approach 1, under 8 KB<br>- [ ] `.claude/claude-security-guidance.local.md` in `.gitignore`<br>- [ ] `SECURITY_GUIDANCE_DISABLE: "1"` on the Claude steps of `claude-review.yml` and `claude.yml`<br>- [ ] `CLAUDE.md` (Phase 3 paragraph, Phase 4 step 3) and `README.md` updated<br>- [ ] Evidence for layers 1–3 on a throwaway branch, the hook tests, and an unchanged `claude-review` run, as in Verification | none |
| 2 | `ci: advisory Claude security scan on PRs into develop` | chore | - [ ] `.github/workflows/claude-security-scan.yml` with `gate`, `scan` and `post` jobs as in Approach 2, on `claude-code-action` with the existing `CLAUDE_CODE_OAUTH_TOKEN` (no new secret)<br>- [ ] The scan applies `.claude/claude-security-guidance.md` from `develop`<br>- [ ] One comment per PR with the marker `<!-- claude-security-scan -->`, edited on `@claude security`<br>- [ ] `claude.yml` ignores `@claude security`<br>- [ ] The job never fails on findings (advisory)<br>- [ ] `CLAUDE.md` Phase 5 step 2 and the README CI section updated<br>- [ ] Evidence: the test PR with two planted issues, a clean PR, the re-run, a draft and a docs-only skip | 1 |
