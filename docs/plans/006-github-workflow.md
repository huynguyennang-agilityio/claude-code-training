# Plan 006: Move the workflow to GitHub and mirror it to GitLab

Status: draft
Approved: <the user fills in the date>
Issues: <filled in after approval, for example #1, #2>

## Context

The repository moves from GitLab (`gitlab.asoft-python.com/huy.nguyennang/claude-code-training`) to GitHub (`github.com/huynguyennang-agilityio/claude-code-training`). From now on GitHub is the primary host: issues, pull requests, reviews and merges happen there. GitLab stays as a read-only copy that receives every change from GitHub automatically.

Existing GitLab issues and merge requests are not migrated. They stay on GitLab as history.

State on 2026-10-19:

- `develop` is pushed to GitHub (`bfe6d9a`, same as GitLab) and is GitHub's default branch. `main` (`a5508dd`) is still only on GitLab. GitHub has no tags, and neither does GitLab.
- GitLab has 62 branches; GitHub has 1. The old feature branches stay on GitLab only.
- `gitlab.asoft-python.com` is reachable from the internet, so GitHub-hosted runners can push to it.
- About 15 tracked files still name GitLab, `glab`, "merge request" or "MR": `CLAUDE.md`, `README.md`, `docs/workflow.md`, `docs/plans/README.md`, `.gitlab/merge_request_templates/Default.md`, the three agents in `.claude/agents/`, and some comments in code and docs.
- `gh` is not installed on this machine yet.

## Open questions and assumptions

1. **How GitLab gets the changes? (needs your decision.)**
   - **A. A GitHub Actions workflow pushes to GitLab on every push to GitHub (assumed, recommended).** It runs on GitHub's side, so it also catches merges done in the GitHub web UI, and it works on any GitLab tier.
   - **B. GitLab pull mirroring.** Rejected: it is a GitLab Premium feature, and it is unclear whether this self-hosted instance has it.
   - **C. A second push URL on the local `origin`, so `git push` goes to both.** Rejected: merges made on GitHub never reach GitLab until someone pulls and pushes them again by hand.
2. **The mirror only adds and fast-forwards. It never force-pushes or deletes (assumed).** Deleting a branch on GitHub leaves it on GitLab. A prune would remove the 61 old branches that exist only on GitLab, and a force-push would hide the case where someone pushed to GitLab directly. If GitLab has diverged, the job fails and shows it. Say if you want an exact mirror instead (force plus prune).
3. **Authentication: a GitLab project access token** with the `Maintainer` role and the `write_repository` scope only, stored as the GitHub Actions secret `GITLAB_MIRROR_TOKEN`. `Maintainer` is needed because `develop` and `main` are protected on GitLab. You create the token and the secret; Claude never sees the token. Assumed.
4. **Issue numbers restart at #1 on GitHub,** and GitHub shares one counter between issues and pull requests. Old references (`#49`, `Closes #3`, branch names such as `chore/3-dev-setup`) mean GitLab issues. Plans 001 to 005 and the ADRs are left as they are, as history. New docs use GitHub numbers. Assumed.
5. **GitLab becomes read-only by convention.** Nobody pushes there or opens merge requests there. You turn off issues and merge requests in the GitLab project settings and add "Mirror of <GitHub URL>" to its description. Assumed.
6. **Remote names:** locally, `origin` becomes GitHub and the GitLab remote is renamed `gitlab`. CLAUDE.md says that Claude pushes only to `origin`. Assumed.

## Approach

No mobile, backend, API, schema or database change. No change to `docs/api/`.

**Issue 1, the mirror (`.github/workflows/mirror-to-gitlab.yml`):**

- Triggers: `push` to any branch or tag, plus `workflow_dispatch` for a full resync by hand.
- `permissions: contents: read`, and `concurrency` with one group and `cancel-in-progress: false`, so pushes are mirrored in order.
- `actions/checkout` pinned to a full release tag, with `fetch-depth: 0`. Then `git push` to `https://gitlab.asoft-python.com/huy.nguyennang/claude-code-training.git` with the refspecs `refs/remotes/origin/*:refs/heads/*` (without `HEAD`) and `refs/tags/*:refs/tags/*`. No `--force`, no `--prune`.
- The token is passed through `http.extraHeader` from the secret. It never appears in the command line or the URL, so it cannot leak into the log. GitHub masks it as well.
- A short section in `README.md` describes the mirror: GitHub is primary, GitLab is a read-only copy, how to resync, and what a failed run means.

**Issue 2, the workflow docs and templates:**

- `.gitlab/merge_request_templates/Default.md` moves to `.github/pull_request_template.md` (`git mv`), with "MR" changed to "PR".
- `CLAUDE.md`: GitLab becomes GitHub, `glab` becomes `gh`, MR becomes PR (`gh pr create --base develop`, `gh pr merge`, `gh issue create`). The section "Git and GitLab permissions" is renamed, and "Reviewing merge requests" becomes "Reviewing pull requests". Phase 6 says the mirror is the only workflow and that it is not CI, so "no pipeline" still holds. Two new rules: never push to the `gitlab` remote, and turn off "Automatically delete head branches" on GitHub.
- `docs/workflow.md`: the diagrams say GitHub and PR (`PR #14` instead of `MR !14`), the links point to the renamed CLAUDE.md anchors, and a short note covers the mirror.
- `docs/plans/README.md`, `README.md` (contributing section) and `docs/diagrams/phase-flow.{html,svg}`: MR becomes PR.
- `.claude/agents/planner.md` uses `gh` instead of `glab`, and `.claude/agents/fastapi-backend.md` and `.claude/agents/flutter-dev.md` say "GitHub issue" and "pull request".
- Comment wording in `backend/app/scripts/export_openapi.py`, `backend/tests/unit/test_openapi_snapshot.py`, `mobile/test/helpers/golden_screen.dart` and `docs/api/auth.md`: "merge request" becomes "pull request". These are text-only changes.
- Unchanged: plans 001 to 005 and `docs/adr/` (history).

**Manual steps for you (not code, done before or alongside issue 1):**

1. `brew install gh` and `gh auth login`.
2. Push `main` to GitHub, and protect `develop` and `main` there: changes only through a PR, no force-push, no deletion.
3. In GitHub settings, turn off "Automatically delete head branches", and create the labels the plans use (`frontend`, `backend`, `docs`, `chore`).
4. Create the GitLab project access token and the GitHub secret `GITLAB_MIRROR_TOKEN` (open question 3).
5. Rename the remotes (open question 6).
6. Turn off GitLab issues and merge requests, and update the project description (open question 5).

This touches: core tooling (the code host and the review flow) and a security boundary (a write token for GitLab stored on GitHub). It adds a small external cost: GitHub Actions minutes, a few seconds per push. The approval must cover these.

## Risks

- **The token leaks or has too much access.** Contained by: a project access token (not a personal one), the `write_repository` scope only, a GitHub secret passed through a header, `contents: read` for the workflow, and an expiry date on the token. If it leaks, revoke it in GitLab.
- **Someone pushes to GitLab, so the copies diverge.** The next mirror run fails without overwriting anything. Fix: push the GitLab commit to GitHub through a PR, or discard it, then rerun the workflow by hand.
- **The token expires and the mirror stops without anyone noticing.** GitHub emails you when a workflow run fails. The README names the expiry as the first thing to check.
- **Old `#N` references get confused with new GitHub issues.** Accepted (open question 4). New links use full URLs where the meaning is unclear.
- **A missed GitLab mention in the docs.** Contained by the `git grep` check in Verification.

## Verification

- Issue 1:
  - Push a test branch to GitHub, then `git ls-remote` on both remotes shows the same SHA.
  - Push a tag, then check the same way.
  - Merge a PR in the GitHub UI, then check that `develop` matches on both remotes.
  - Run `workflow_dispatch`, then check that the run is green with nothing to push.
  - Read the run log and confirm that no token value appears in it.
  - Delete the test branch and tag on both remotes afterwards (you do this; Claude never deletes branches).
  - Not verified here: the divergence failure case, unless you allow a throwaway commit on a GitLab-only test branch.
- Issue 2:
  - `git grep -niE 'gitlab|glab|merge request|\bMRs?\b'` finds only the allowed places: plans 001 to 005, `docs/adr/`, and the mirror sections.
  - Markdown links to the renamed CLAUDE.md anchors resolve.
  - A test PR on GitHub shows the new template.
  - `flutter analyze`, `ruff check .` and `mypy` still pass on the files whose comments changed.

## Ticket evidence

Both are chores. The scope is in Approach. What must stay unchanged: no app behaviour changes, and the same phases and permission rules apply, on GitHub instead of GitLab. No images needed.

## Issues to create

Created on GitHub with `gh issue create`, once this plan is approved on `develop`.

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `chore: mirror GitHub to GitLab with a GitHub Actions workflow` | chore | - [ ] Every push of a branch or tag to GitHub appears on GitLab with the same SHA<br>- [ ] A merge done in the GitHub UI reaches GitLab `develop`<br>- [ ] The workflow never force-pushes or deletes, and fails when GitLab has diverged<br>- [ ] The token comes only from the `GITLAB_MIRROR_TOKEN` secret and never appears in a run log<br>- [ ] `workflow_dispatch` resyncs everything<br>- [ ] README describes the mirror, how to resync and what a failure means | none (the manual steps above must be done first) |
| 2 | `docs: move the workflow from GitLab to GitHub` | docs | - [ ] The PR template is at `.github/pull_request_template.md`, and `.gitlab/` is gone<br>- [ ] CLAUDE.md, README, `docs/workflow.md`, `docs/plans/README.md`, the diagrams and the three agents describe GitHub, `gh` and PRs<br>- [ ] CLAUDE.md says GitLab is a read-only mirror that nobody pushes to<br>- [ ] `git grep` finds GitLab, MR or merge-request wording only in plans 001 to 005, ADRs and the mirror sections<br>- [ ] Lint and type checks pass on the files whose comments changed | 1 |
