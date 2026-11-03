# Plan 029: Post the Claude review and security scan through an artifact, with an explicit secret check

Status: approved
Approved: 2026-10-28, by the user in chat: "/approve-plan 029"
Issues: #170, #171
Draft: https://claude.ai/artifact/ApatViKrUt9zdoM2o6Ci6q, version 1793175421-180d

Based on: `docs/plans/014-claude-github-actions.md`, `docs/plans/018-comment-markers.md`, `docs/plans/028-parallel-run-tasks.md`, PR [#168](https://github.com/huynguyennang-agilityio/claude-code-training/pull/168), the [Run 2026-10-28](https://claude.ai/artifact/TSNxhWcHKLhp6V5MU5tQLD) report.

## Prerequisites

None. This plan needs no new secret, key or setting. The two new actions (`actions/upload-artifact`, `actions/download-artifact`) are pinned by SHA like the actions already in use.

## Context

During the `/run-tasks #164 #165 #166` run of 2026-10-28, the `claude-review` workflow could not post a review for PR #168 (issue #165) in all 3 runs: run `40650390474` (when the PR was opened, and its re-run) and run `40650898419` (the `@claude review` comment). Each time the `review` job succeeded (`"subtype": "success"`), but the runner reported `Skip output 'result' since it may contain secret`. So the `post` job received an empty string, printed "The review is empty; nothing posted." and failed. #165 had no review from `github-actions[bot]`, so it did not meet the merge conditions, and #166 had to stop with it.

Cause: the review is passed from the `review` job to the `post` job through `jobs.review.outputs.result`. GitHub drops a job output entirely when it contains a string equal to a masked value. A comment in the workflow says this behaviour is used on purpose as a safety net: a review that contains a secret is not posted, because this repo is public. Still, this net has two drawbacks:

- **It gives no reason:** the log masks the value, so there is no way to know which string in the review was taken for a secret. The diff of PR #168 has a fake password in a test fixture and a URL with `****`, but no real secret.
- **A false block has no way out:** re-running gives the same empty result, and the PR is stuck.

`claude-security-scan.yml` passes its result the same way (`jobs.scan.outputs.result`), so it can get stuck the same way too.

### Decided by the user

- Plan a fix to the `claude-review` workflow: move the review from a job output to an artifact, then re-run #165 and #166 (message of 2026-10-28).

## Open questions and assumptions

1. **Keep the safety net, but make it explicit:** with an artifact, the runner's filter step no longer applies. So the `review` job checks the result itself *before* uploading, with a fixed script (assumption 2). If it finds a sign of a secret, the job fails, **uploads nothing and posts nothing**, and the log names the *rule* that matched (never the value). This is as safe as before, but the reason is known.
2. **The check script** `.github/scripts/check-no-secrets.sh <file> <ENV_NAME>...` fails when the file contains:
   - the value of any environment variable whose name is passed in, raw or base64. Variables whose value is shorter than 8 characters are skipped, to avoid false matches;
   - a string shaped like a token: a GitHub token (`gh[pousr]_` + 36 or more characters, `github_pat_`), an Anthropic key (`sk-ant-`), or a JWT (`eyJ…` with three parts separated by dots, like the Actions runtime tokens).

   The `review` job passes `CLAUDE_CODE_OAUTH_TOKEN` and `github.token`, the only two secrets of this job.
3. **Artifact:** named `claude-review-result` (scan: `claude-security-scan-result`), holding exactly one JSON file, the `structured_output`, with `retention-days: 1`. The repo is public, so anyone can download the artifact. Its content is the same as the comment about to be posted publicly, and it has passed the check of assumption 2.
4. **From step to file:** `structured_output` goes into an environment variable of the step (not filtered, since it stays in the same job), then is written to a file with `printf '%s' "$RESULT"`. `${{ }}` is never interpolated into a script.
5. **The `post` job** downloads the artifact and then runs exactly the existing logic: rewrite `<!--` to `< !--`, edit the comment with the marker or create a new one. The job gets no extra permission: downloading an artifact in the same run needs no `actions: read`. If there is no artifact (the `review` job did not upload), the `post` job is skipped because its `needs` failed, so nothing is posted.
6. **Scope:** change both `claude-review.yml` and `claude-security-scan.yml`. The two workflows share one script. No change to the prompt, permissions, gate or model.
7. **Re-run #165 and #166** after the two issues of this plan merge: `/run-tasks <issue 1> <issue 2> #165 #166` in one run. #165 (PR #168) needs `develop` merged in (the `backend/PROGRESS.md` line will conflict with #164; keep both lines), then a `@claude review` comment; the workflow for `issue_comment` runs from `develop`, so it uses the fixed version right away. #166 uses the draft `run-tasks` skill written in the previous run. To let Claude do this in sequence in that same run, nothing more is needed.
8. **No further guessing at the root cause:** this plan does not try to find which string in #168's review was taken for a secret. After the fix, the re-review of #168 will tell: either the script names a matched rule (then it is a real secret and is not posted), or the review is posted (then the earlier block was a false one).

## Approach

Only two GitHub Actions workflows change, and one script with its test is added. No backend or mobile code changes, and no Claude configuration changes.

### New flow

```text
gate ──▶ review (read-only, has secrets)
            ├─ claude-code-action → structured_output
            ├─ write to result.json
            ├─ check-no-secrets.sh result.json CLAUDE_CODE_OAUTH_TOKEN GH_JOB_TOKEN
            │     match → print the rule name, exit 1, no upload
            └─ upload-artifact result.json (retention 1 day)
       ──▶ post (pull-requests: write, no Claude secret)
            ├─ download-artifact
            └─ jq → edit / create the comment with the marker (as today)
```

### Task 1: `claude-review` and the check script

- Add `.github/scripts/check-no-secrets.sh` as in assumption 2, running with `set -euo pipefail`, printing only the name of the matched rule or variable. Add `.github/scripts/test-check-no-secrets.sh` to test each rule, the base64 form, the 8-character floor, a clean file, and that the value is never printed.
- `.github/workflows/claude-review.yml`:
  - drop `outputs: result` from the `review` job;
  - add, after the `claude` step, a step that writes `result.json`, runs the script and uploads the artifact (`actions/upload-artifact` pinned by SHA);
  - the `post` job downloads the artifact (`actions/download-artifact` pinned by SHA) and reads the file instead of `needs.review.outputs.result`;
  - update the comment at the top of the file and the comment in the `post` job to match.
- `README.md` (the CI and Claude on GitHub section) and `docs/plans/README.md`: change only if they mention passing through a job output.

### Task 2: `claude-security-scan`

- `.github/workflows/claude-security-scan.yml`: as in Task 1, with the `claude-security-scan-result` artifact, keeping the reading of `.report` and `.high` unchanged.

### Changes the approval must cover (Phase 2)

- **Security boundary:** replace the runner's implicit filter with an explicit check, before anything leaves the job that holds secrets. The repo is public, so if the check misses a secret, that secret is posted publicly and stays in the artifact for one day. Approving this plan means accepting the check of assumption 2.
- No job's permissions change, no secret is added, no change to API, schema, real data or production. The Claude cost does not change.

## Risks

- **The check misses a secret** that the runner used to block (for example another encoding). Mitigation: check both the raw and base64 values of the job's two secrets, plus the known token shapes (including the runtime token JWT). Claude in the job still cannot read environment variables (`CLAUDE_CODE_SUBPROCESS_ENV_SCRUB`, the blocked paths), and the prompt still forbids putting secrets in the review.
- **False block** when the review quotes a string that looks like a token (for example a sample JWT in a test). Unlike today, the log names the rule, so the reason is known at once. How to handle it: the user reviews the PR, or the sample string is changed.
- **The artifact is public for one day.** Its content is the same as the comment about to be posted publicly, so nothing more is exposed.
- **Two runs on the same PR** have artifacts with the same name. Artifacts belong to each run, and `post` downloads only its own run's artifact; the existing concurrency group stays as it is.
- **Workflows are hard to test locally.** Mitigation: `actionlint` locally, the script's tests, and each task's own PR: on a `pull_request` event, the workflow runs from the PR's merge commit, so Task 1's PR reviews itself with the new flow.

## Verification

- `bash .github/scripts/test-check-no-secrets.sh` passes; `shellcheck .github/scripts/*.sh` is clean; `actionlint .github/workflows/claude-review.yml .github/workflows/claude-security-scan.yml` is clean.
- Task 1: Task 1's PR has a `## Claude review · <head>` comment posted by `github-actions[bot]` through the new flow. The `review` job's log shows the check step reporting no match, and the `claude-review-result` artifact exists.
- Task 2: Task 2's PR has a `## Claude security scan · <head>` comment through the new flow. Task 2 touches a workflow, so the scan is not skipped as on a docs-only PR; if it is skipped, write `Not verified` with the reason.
- After merging: comment `@claude review` on PR #168 and write the result (review posted, or the name of the matched rule) into the run's report.

## Ticket evidence

This is a CI bug. The gate needs: steps to reproduce, expected result, actual result, and logs.

- **Reproduce:** open PR #168, or comment `@claude review` on it.
- **Expected:** the comment `## Claude review · 6d29c80` is posted.
- **Actual:** the `review` job succeeds, the runner prints `Skip output 'result' since it may contain secret`, the `post` job prints "The review is empty; nothing posted." and fails.
- **Logs:** run `40650390474` (2 attempts) and `40650898419`.

## Task breakdown

Order: task 1 then task 2, because task 2 uses task 1's script. Then re-run #165 and then #166 (assumption 7).

### Task 1: `[infra] ci: post the Claude review through an artifact with a secret check`

**Requirements**

- The review goes from the `review` job to the `post` job through an artifact, not a job output.
- Before uploading, a fixed script blocks a result that contains a secret of the job or a token-shaped string, and prints only the name of the matched rule.
- Permissions, gate, prompt and the comment-posting logic stay unchanged.

**Steps**

1. Write `.github/scripts/check-no-secrets.sh` and `.github/scripts/test-check-no-secrets.sh`.
2. Change `.github/workflows/claude-review.yml` as in Approach, Task 1.
3. Change `README.md` and `docs/plans/README.md` if they mention the job output.
4. Run Task 1's verification commands.

**Checklist**

- [ ] `.github/scripts/check-no-secrets.sh <file> <ENV_NAME>...` fails when the file holds a named variable's value (raw or base64, values of 8 characters or more), a GitHub token (`gh[pousr]_`, `github_pat_`), an Anthropic key (`sk-ant-`) or a JWT, and prints only the rule or variable name
- [ ] `.github/scripts/test-check-no-secrets.sh` covers each rule, the base64 form, the 8-character floor, a clean file and that no value is printed, and passes
- [ ] `.github/workflows/claude-review.yml`: the `review` job has no `outputs`; it writes `structured_output` to a file through an environment variable, runs the check with `CLAUDE_CODE_OAUTH_TOKEN` and `github.token`, and uploads the `claude-review-result` artifact (pinned by SHA, `retention-days: 1`) only when the check passes
- [ ] The `post` job downloads the artifact (pinned by SHA), keeps its permissions, the `<!--` rewrite and the marker logic, and posts nothing when there is no artifact
- [ ] `actionlint` and `shellcheck` are clean
- [ ] This PR's own `claude-review` run posts `## Claude review · <head>` through the artifact

### Task 2: `[infra] ci: post the security scan through an artifact with a secret check`

**Requirements**

- `claude-security-scan` passes its result through an artifact, with the same secret check as Task 1.
- The reading of `.report` and `.high`, and everything else in the workflow, stays unchanged.

**Steps**

1. Change `.github/workflows/claude-security-scan.yml` as in Approach, Task 2.
2. Run `actionlint` and check the scan on the task's PR.

**Checklist**

- [ ] `.github/workflows/claude-security-scan.yml`: the `scan` job has no `outputs`; it writes `structured_output` to a file through an environment variable, runs `.github/scripts/check-no-secrets.sh` with `CLAUDE_CODE_OAUTH_TOKEN` and `github.token`, and uploads the `claude-security-scan-result` artifact (pinned by SHA, `retention-days: 1`) only when the check passes
- [ ] The `post` job downloads the artifact and keeps its permissions, the `.report` and `.high` reading, the `<!--` rewrite and the marker logic
- [ ] `actionlint` is clean
- [ ] This PR's own scan posts `## Claude security scan · <head>` through the artifact, or the PR says `Not verified` with the reason

## Issues to create

The acceptance criteria are each task's checklist above, word for word.

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `[infra] ci: post the Claude review through an artifact with a secret check` | chore, area:infra | - [ ] `.github/scripts/check-no-secrets.sh <file> <ENV_NAME>...` fails when the file holds a named variable's value (raw or base64, values of 8 characters or more), a GitHub token (`gh[pousr]_`, `github_pat_`), an Anthropic key (`sk-ant-`) or a JWT, and prints only the rule or variable name<br>- [ ] `.github/scripts/test-check-no-secrets.sh` covers each rule, the base64 form, the 8-character floor, a clean file and that no value is printed, and passes<br>- [ ] `.github/workflows/claude-review.yml`: the `review` job has no `outputs`; it writes `structured_output` to a file through an environment variable, runs the check with `CLAUDE_CODE_OAUTH_TOKEN` and `github.token`, and uploads the `claude-review-result` artifact (pinned by SHA, `retention-days: 1`) only when the check passes<br>- [ ] The `post` job downloads the artifact (pinned by SHA), keeps its permissions, the `<!--` rewrite and the marker logic, and posts nothing when there is no artifact<br>- [ ] `actionlint` and `shellcheck` are clean<br>- [ ] This PR's own `claude-review` run posts `## Claude review · <head>` through the artifact | none |
| 2 | `[infra] ci: post the security scan through an artifact with a secret check` | chore, area:infra | - [ ] `.github/workflows/claude-security-scan.yml`: the `scan` job has no `outputs`; it writes `structured_output` to a file through an environment variable, runs `.github/scripts/check-no-secrets.sh` with `CLAUDE_CODE_OAUTH_TOKEN` and `github.token`, and uploads the `claude-security-scan-result` artifact (pinned by SHA, `retention-days: 1`) only when the check passes<br>- [ ] The `post` job downloads the artifact and keeps its permissions, the `.report` and `.high` reading, the `<!--` rewrite and the marker logic<br>- [ ] `actionlint` is clean<br>- [ ] This PR's own scan posts `## Claude security scan · <head>` through the artifact, or the PR says `Not verified` with the reason | #170 |
