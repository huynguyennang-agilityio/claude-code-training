# Plan 006: Move the workflow to GitHub and keep GitLab as a manual mirror

Status: approved
Approved: 2026-10-19
Issues: #2 (to be closed as not planned), #3

## Context

The repository moves from GitLab (`gitlab.asoft-python.com/huy.nguyennang/claude-code-training`) to GitHub (`github.com/huynguyennang-agilityio/claude-code-training`). From now on GitHub is the primary host: issues, pull requests, reviews and merges happen there. GitLab stays as a read-only copy.

Existing GitLab issues and merge requests are not migrated. They stay on GitLab as history.

### Revision (2026-10-19)

The first approved version of this plan mirrored GitHub to GitLab automatically with a GitHub Actions workflow (#2). The first run on GitHub failed:

```text
fatal: unable to access 'https://gitlab.asoft-python.com/huy.nguyennang/claude-code-training.git/':
Failed to connect to gitlab.asoft-python.com port 443 after 134822 ms: Couldn't connect to server
```

GitLab can only be reached through the company VPN, so GitHub-hosted runners can't reach it. The other automatic options don't work either:

- GitLab pull mirroring: the instance is GitLab CE 19.3.5 (`"enterprise": false`), and pull mirroring is a Premium feature.
- A GitLab CI job that pulls from GitHub: the project has no runners. Its last pipeline (`54369`) failed with `stuck_pending_no_matching_runners`.

So this revision drops the automatic mirror. You mirror by hand, from a machine on the VPN, with the commands below. #2 is closed as not planned, and the mirror instructions move into #3.

### State on 2026-10-19

Done by hand (the former "Manual steps"):

- `gh` is installed and signed in.
- `develop` and `main` are on GitHub. `develop` is the default branch.
- The `Protect develop and main` ruleset blocks deletion and force-push, and requires a pull request. "Automatically delete head branches" is off.
- The labels `chore`, `docs`, `frontend` and `backend` exist.
- Locally, `origin` is GitHub and `gitlab` is GitLab.
- GitLab issues and merge requests are turned off, and the GitLab project description says it is a read-only mirror.

Left over from the automatic mirror, for you to clean up (all are deletions, so Claude doesn't do them):

- The GitLab project access token `github-mirror` and the GitHub secret `GITLAB_MIRROR_TOKEN`.
- The branch `chore/2-gitlab-mirror` on GitHub. It holds the workflow, and the workflow runs and fails on every push to that branch. It is not on `develop`.

About 15 tracked files still name GitLab, `glab`, "merge request" or "MR". #3 updates them.

## Open questions and assumptions

1. **Manual mirroring, from a machine on the VPN (decided by you on 2026-10-19).** Mirroring is done by hand after merges to `develop` or `main`, and after tags are pushed. Only Claude's reminder (see Approach) prompts it, so GitLab can fall behind GitHub. Accepted.
2. **Only `develop`, `main` and tags are mirrored (assumed).** Feature branches live on GitHub only. They are short-lived and deleted after merge, so copying them would only leave stale branches on GitLab. Say if you want feature branches mirrored too.
3. **The mirror uses your existing SSH access to GitLab.** No token is needed, and nothing is stored on GitHub.
4. **The mirror only fast-forwards.** No `--force`, no deletion. If GitLab has diverged, the push is rejected, and you sort it out by hand.
5. **Issue numbers restart at #1 on GitHub,** and GitHub shares one counter between issues and pull requests. Old references (`#49`, `Closes #3`, branch names such as `chore/3-dev-setup`) mean GitLab issues. Plans 001 to 005 and the ADRs are left as they are, as history. New docs use GitHub numbers.
6. **Claude never pushes to the `gitlab` remote.** Mirroring is your step. A push to GitLab is a push to a second host and needs the VPN anyway.

## Approach

No mobile, backend, API, schema or database change. No change to `docs/api/`. No GitHub Actions workflow is added.

**Issue #3, the workflow docs and templates:**

- `.gitlab/merge_request_templates/Default.md` moves to `.github/pull_request_template.md` (`git mv`), with "MR" changed to "PR".
- `CLAUDE.md`:
  - GitLab becomes GitHub, `glab` becomes `gh`, and MR becomes PR (`gh pr create --base develop`, `gh pr merge`, `gh issue create`).
  - The section "Git and GitLab permissions" is renamed, and "Reviewing merge requests" becomes "Reviewing pull requests".
  - New rules: GitLab is a read-only mirror that you update by hand, and Claude never pushes to the `gitlab` remote. After a merge to `develop` or `main`, Claude reminds you to mirror.
  - Phase 6 still says "no pipeline".
- `README.md`: the contributing section says GitHub and PR, and a new "GitLab mirror" section holds the manual commands:

  ```bash
  git fetch origin --prune
  git push gitlab origin/develop:refs/heads/develop origin/main:refs/heads/main --tags
  ```

  The section also says what a `rejected` push means and how to check that both hosts match (`git ls-remote origin` against `git ls-remote gitlab` for `develop` and `main`).
- `docs/workflow.md`: the diagrams say GitHub and PR (`PR #14` instead of `MR !14`), the links point to the renamed CLAUDE.md anchors, and a short note covers the manual mirror.
- `docs/plans/README.md` and `docs/diagrams/phase-flow.{html,svg}`: MR becomes PR.
- `.claude/agents/planner.md` uses `gh` instead of `glab`, and `.claude/agents/fastapi-backend.md` and `.claude/agents/flutter-dev.md` say "GitHub issue" and "pull request".
- Comment wording in `backend/app/scripts/export_openapi.py`, `backend/tests/unit/test_openapi_snapshot.py`, `mobile/test/helpers/golden_screen.dart` and `docs/api/auth.md`: "merge request" becomes "pull request". These are text-only changes.
- Unchanged: plans 001 to 005 and `docs/adr/` (history).

**Issue #2** is closed as not planned, with a comment that links this revision and the failed run.

This touches core tooling: the code host and the review flow. It no longer adds a stored credential or any Actions cost. The approval must cover these.

## Risks

- **GitLab falls behind GitHub, because mirroring is manual.** Accepted. CLAUDE.md has Claude remind you after each merge to `develop` or `main`, and README shows how to compare the two hosts.
- **Someone pushes to GitLab, so the copies diverge.** The manual push is rejected and overwrites nothing. Fix: bring the GitLab commit to GitHub through a PR, or discard it, then mirror again.
- **The manual command creates a stray branch.** Contained by naming `develop` and `main` explicitly instead of `refs/remotes/origin/*`. The wildcard would also copy `origin/HEAD` as a branch called `HEAD`.
- **Old `#N` references get confused with new GitHub issues.** Accepted (open question 5). New links use full URLs where the meaning is unclear.
- **A missed GitLab mention in the docs.** Contained by the `git grep` check in Verification.

## Verification

- #3:
  - `git grep -niE 'gitlab|glab|merge request|\bMRs?\b'` finds only the allowed places: plans 001 to 005, `docs/adr/`, and the mirror sections.
  - Markdown links to the renamed CLAUDE.md anchors resolve.
  - A test PR on GitHub shows the new template.
  - `flutter analyze`, `ruff check .` and `mypy` still pass on the files whose comments changed.
  - The README mirror commands, run by you on the VPN after #3 is merged, leave `develop` and `main` with the same SHA on both hosts. Claude can't run this (no VPN in its session, and it never pushes to `gitlab`), so the PR records `Not verified: needs the VPN, run by the user`, unless you run it and paste the `git ls-remote` output.

## Ticket evidence

#3 is a chore. The scope is in Approach. What must stay unchanged: no app behaviour changes, and the same phases and permission rules apply, on GitHub instead of GitLab. No images needed.

## Issues to create

Already created from the first approved version. After this revision is approved:

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| #2 | `chore: mirror GitHub to GitLab with a GitHub Actions workflow` | chore | Closed as not planned, with a comment that links this revision | none |
| #3 | `docs: move the workflow from GitLab to GitHub` (description updated to this revision) | docs | - [ ] The PR template is at `.github/pull_request_template.md`, and `.gitlab/` is gone<br>- [ ] CLAUDE.md, README, `docs/workflow.md`, `docs/plans/README.md`, the diagrams and the three agents describe GitHub, `gh` and PRs<br>- [ ] CLAUDE.md says GitLab is a read-only mirror that you update by hand, that Claude never pushes to `gitlab`, and that Claude reminds you to mirror after a merge to `develop` or `main`<br>- [ ] README has the manual mirror commands, what a `rejected` push means, and how to compare the two hosts<br>- [ ] `git grep` finds GitLab, MR or merge-request wording only in plans 001 to 005, ADRs and the mirror sections<br>- [ ] Lint and type checks pass on the files whose comments changed | none |
