# Plan 021: Block forbidden gh commands with the PreToolUse hook

Status: approved
Approved: 2026-10-23, by the user in chat: "/approve-plan 021"
Issues: #107, #108

## Context

[Plan 010](010-block-forbidden-command.md) (issue #22) added `.claude/hooks/block-forbidden-command.sh`, a `PreToolUse` hook on the `Bash` tool that refuses the git commands [`CLAUDE.md`](../../CLAUDE.md#git-and-github-permissions) marks Never: pushing to `develop`/`main`, force-pushing, deleting branches and pushing to `gitlab`. It only looks at `git push` and `git branch`.

[Plan 019](019-area-autopilot.md) then added `/run-tasks` (issue #91, PR #105, merged 2026-10-23), which lets Claude commit, push and merge PRs for the issues the user names, and stops at "ready to merge" when the issue or the PR has the `human-merge` label. Two rules that matter for that run are written only in [`.claude/skills/run-tasks/SKILL.md`](../../.claude/skills/run-tasks/SKILL.md):

- merge with `gh pr merge <n> --merge`, **never with `--delete-branch`** (CLAUDE.md: Claude never deletes branches);
- **never remove `human-merge`** from an issue or a PR; only the user does.

Both reviews of PR #105 recommended enforcing them in the hook, in their own issue. Today nothing stops `gh pr merge 5 --merge -d`, `gh pr edit 5 --remove-label human-merge`, or the same through `gh api`. A run that removes `human-merge` turns off the one gate that keeps a risky PR for the user.

This plan extends the existing hook to refuse those `gh` commands. It changes no rule: every command it blocks is already forbidden by `CLAUDE.md` or the skill.

## Open questions and assumptions

1. **`human-merge` on both issues (recommendation, the user decides).** The issues change the guard that protects `human-merge` itself, so a `/run-tasks` run should not be able to merge them on its own. The README asks for the label on changes to authorization; this is authorization of Claude's own actions. Say if you want them without it.
2. **Exact label name, case-insensitive (assumption).** Only `human-merge` is protected (GitHub label names are case-insensitive, so `Human-Merge` counts). `--remove-label bug` and other labels stay allowed.
3. **`gh api` is covered in a second issue (recommendation).** Issue 2 blocks the REST and GraphQL calls that delete a branch or remove, replace, rename or delete the `human-merge` label. It is separate so you can drop it and keep `gh api` as a known gap instead; the hook header and this plan would then list it. It over-blocks a little on purpose (see Approach), since `/run-tasks` never needs those calls.
4. **Also covered, because they delete branches or remove the label by another route (assumption):** `gh pr close --delete-branch`/`-d`, `gh label delete human-merge`, renaming the label with `gh label edit human-merge --name`, and turning on `gh repo edit --delete-branch-on-merge` (GitHub would then delete the head branch on every merge; the setting is `false` today). Say if any of these is out of scope.
5. **Unchanged from plan 010:** best effort, not a security boundary; fails open without `jq` or `perl`; guards Claude's Bash tool only, not the user's terminal. The hook never runs `gh` itself (no network, no token), it only reads the command text.

## Approach

Tooling only. No mobile, backend, API, schema or database change. It touches a security boundary of the development process (what Claude may run), not of the product; the approval covers that.

### Files

- `.claude/hooks/block-forbidden-command.sh`: `analyze_fragment` already skips `VAR=x`, `sudo`, `command`, `env`, `time`, `exec`, `nohup` and takes the basename of the command word. It now dispatches `gh` (any path, for example `/opt/homebrew/bin/gh`) to a new `check_gh`, next to `git`. The header comment lists the new blocked forms and the new known gaps.
- `.claude/hooks/test-block-forbidden-command.sh`: new `--- gh ---` and `--- gh api ---` sections with the blocked and allowed cases below. The hook needs no `gh` install or network for them.
- `CLAUDE.md`: the sentence about the `PreToolUse` hook says it refuses the Never rows "as git commands and their `gh` forms (`gh pr merge --delete-branch`, removing `human-merge`)". The permission table is unchanged.
- `.claude/skills/run-tasks/SKILL.md`: one clause on the Never bullet that the hook also refuses these. No step changes.

### How `check_gh` reads a command (issue 1)

The command text reaches `analyze_fragment` already split into simple commands, with quotes removed and spaces inside quotes turned into `\x01` (pass 1), so a quoted value stays one token. `check_gh`:

1. **Finds the subcommand** as the first two non-flag words after `gh` (`pr merge`, `pr close`, `pr edit`, `issue edit`, `label delete`, `label edit`, `repo edit`). It skips the value of every flag that takes one, wherever it appears: `-R`/`--repo` (also `gh -R o/r pr merge` and `gh pr -R o/r merge`), and per subcommand the value flags in `gh <cmd> --help` (`-t`, `-b`, `-F`, `-A`, `--match-head-commit` for `pr merge`; `--title`, `--body`, `--add-label`, `--milestone`, ... for `edit`). `--flag=value` is one token.
2. **`gh pr merge` and `gh pr close`:** blocked on `--delete-branch`, `--delete-branch=<value>` unless the value is false (`false`, `0`, `f`, any case), and a short-flag cluster that contains `d` before any value-taking letter (`-d`, `-sd`, `-dm`; in `-td` the `d` is the subject, so it is allowed, as `gh` reads it).
3. **`gh pr edit` and `gh issue edit`:** the values of `--remove-label X` and `--remove-label=X` are split on commas, trimmed of spaces and `\x01`, and compared case-insensitively with `human-merge`. Several numbers (`gh issue edit 1 2 --remove-label ...`) and repeated flags are all checked. `--add-label human-merge` stays allowed: `/run-tasks` adds it.
4. **`gh label delete human-merge`** and **`gh label edit human-merge` with `-n`/`--name`** are blocked (deleting or renaming the label drops it from every issue and PR). Editing only its color or description is allowed.
5. **`gh repo edit --delete-branch-on-merge`** (not `=false`) is blocked.

The block message names the rule, as today: for example "deleting a branch (gh pr merge --delete-branch)" or "removing the human-merge label", followed by "ask the user to run it themselves".

### `gh api` (issue 2)

`check_gh_api` reads the method (`-X`, `--method`, `-XDELETE`, `--method=delete`, any case; default `GET`, or `POST` when a field flag `-f`/`-F`/`--field`/`--raw-field` or `--input` is present), the endpoint (the first non-flag word after `api`, skipping the values of `-X`, `-H`, `-f`, `-F`, `-q`, `-t`, `-p`, `--input`, `--hostname`, `--cache` and their long forms; a leading `/` or `https://api.github.com/` is dropped) and the field names. It blocks:

| Call | Why |
| --- | --- |
| `DELETE` on `repos/<o>/<r>/git/refs/heads/<branch>` | deletes a branch |
| any method but `GET` on `repos/<o>/<r>/git/refs/heads/develop` or `.../main` | moves `develop`/`main` (a push by another name) |
| `DELETE` on `repos/<o>/<r>/issues/<n>/labels/human-merge` | removes the label |
| `DELETE` on `repos/<o>/<r>/issues/<n>/labels` | removes every label |
| `PUT` on `repos/<o>/<r>/issues/<n>/labels` | replaces every label |
| `PATCH` on `repos/<o>/<r>/issues/<n>` or `.../pulls/<n>` with a field named `labels` or `labels[]` | replaces every label |
| `DELETE` or `PATCH` on `repos/<o>/<r>/labels/human-merge` | deletes or renames the label |
| `PATCH` on `repos/<o>/<r>` with `delete_branch_on_merge` set to anything but false | turns on branch deletion at merge |
| `graphql` whose fragment text contains `deleteRef`, `updateRefs`, `removeLabelsFromLabelable`, `clearLabelsFromLabelable`, `deleteLabel` or `updateLabel` | the same through GraphQL |

The `PUT`/`PATCH`/`DELETE`-all-labels and GraphQL rules also block calls that would keep `human-merge` (for example a `PUT` that lists it): the hook cannot tell which labels an issue has, and `/run-tasks` uses `gh pr edit --add-label` instead. Reads (`gh api .../pulls/<n>/files --paginate`, `.../issues/<n>/comments`), adding labels with `POST`, and deleting other things (a comment) stay allowed.

### Edge cases and how the tests cover them

| Edge case | Handling | Test cases |
| --- | --- | --- |
| Quoted arguments | Pass 1 removes quotes; a quoted value stays one token, so `--remove-label "bug, human-merge"` is split on the comma, and a PR body or commit subject that mentions `gh pr merge --delete-branch` stays inside one argument | blocked: `gh pr edit 5 --remove-label "human-merge"`, `--remove-label 'bug, human-merge'`; allowed: `gh pr create --body "never gh pr merge -d"`, `gh pr merge 5 --merge -t "drop -d flag"`, `git commit -m "block gh pr edit --remove-label human-merge"` |
| `--repo` / `-R` anywhere | Its value is skipped, never read as the subcommand or the PR number | blocked: `gh pr merge 5 --repo o/r -d`, `gh -R o/r pr merge 5 -d` and `gh pr -R o/r merge 5 -d` (`gh` 2.102 accepts both), `gh issue edit 5 -R o/r --remove-label human-merge` |
| `--flag=value` | Read as flag plus value | blocked: `--remove-label=human-merge`, `--delete-branch=true`, `--method=DELETE`; allowed: `--delete-branch=false`, `gh repo edit --delete-branch-on-merge=false` |
| Short-flag clusters | `d` before a value-taking letter blocks | blocked: `gh pr merge 5 -sd`, `-dm`; allowed: `gh pr merge 5 -m -t -d` (the subject is `-d`) |
| Label case and lists | Case-insensitive, comma lists, repeated flags | blocked: `--remove-label Human-Merge`, `--remove-label bug --remove-label human-merge`; allowed: `--remove-label bug`, `--remove-label human-merge-later` |
| `bash -c`, `sh -c`, `eval` | Pass 2 already scans quoted strings when the command has one of them, for `gh` as for `git` | blocked: `bash -c "gh pr merge 5 --merge -d"`, `sh -c 'gh pr edit 5 --remove-label human-merge'`, `eval "gh api -X DELETE repos/o/r/git/refs/heads/x"` |
| Chains, subshells, prefixes | Existing splitting on `;`, `&&`, `\|\|`, `\|`, `( )`, backticks and newlines; `env`, `sudo`, `VAR=x`, full path | blocked: `gh pr checks 5 && gh pr merge 5 --merge -d`, `(gh pr close 5 -d)`, `GH_REPO=o/r gh pr merge 5 -d`, `/opt/homebrew/bin/gh pr merge 5 -d` |
| Heredoc bodies | A `<<'EOF'` body is dropped before scanning, as today | allowed: `gh pr create --body "$(cat <<'EOF' ... gh pr merge --delete-branch ... EOF)"` |
| `gh api` method and path order | Method may come before or after the path; path with or without leading `/` or full URL | blocked: `gh api repos/o/r/git/refs/heads/x -X DELETE`, `gh api -XDELETE /repos/o/r/issues/5/labels/human-merge`, `gh api --method put repos/o/r/issues/5/labels -f 'labels[]=bug'`; allowed: `gh api -X POST repos/o/r/issues/5/labels -f 'labels[]=human-merge'`, `gh api repos/o/r/pulls/5/files --paginate` |
| GraphQL | Mutation name anywhere in the fragment | blocked: `gh api graphql -f query='mutation { deleteRef(input: {refId: "x"}) { clientMutationId } }'`; allowed: `gh api graphql -f query='query { viewer { login } }'` |

The existing git cases stay and must still pass, so the change cannot loosen the git rules.

### Known gaps (written in the hook header)

- A `gh` alias (`gh alias set`) or extension, a command built through a variable or a script file, as for git.
- `gh api --input <file>` and `-F query=@file.graphql`: the body is in a file the hook does not read.
- `curl` or another HTTP client calling `api.github.com` with a token.
- GraphQL label removal by label ID only: the hook blocks the mutation name, not a resolved label.
- Merging through the GitHub web UI or with the repository's "Automatically delete head branches" setting already on: outside Claude's Bash tool.

## Risks

- **A false positive blocks a legitimate `gh` command**, for example a merge subject that contains `-d`. Contained by value-flag skipping, the allowed cases, and the message telling Claude to ask the user. `/run-tasks` uses only `gh pr merge <n> --merge`, `gh pr edit --add-label`, reads through `gh api`, and comments.
- **A false negative** through the gaps above. Accepted: the skill text and `CLAUDE.md` remain the rule.
- **A bug in the new code blocks every Bash call** or loosens the git rules. Contained by the full test table (old and new cases), and by exiting 0 on input the hook cannot parse.
- **The hook is shared configuration** read from the PR's base branch on GitHub, so a PR cannot weaken the hook its own runs use; locally it applies as soon as the branch is checked out. Contained by review and, per question 1, by `human-merge` on both issues.

## Verification

- `bash .claude/hooks/test-block-forbidden-command.sh`: every old and new case passes.
- `shellcheck` on both scripts when it is installed; otherwise `Not verified: shellcheck is not installed`.
- A live check in a Claude Code session: ask Claude to run `gh pr merge 99999 --merge -d` and `gh pr edit 99999 --remove-label human-merge` (a PR number that does not exist, so nothing happens if the hook fails); both are refused with the hook's message, and `gh pr view <open PR> --json labels` still runs.
- Not checked: Windows, as in plan 010; the `gh` forms listed as gaps.

## Ticket evidence

Chore: the scope is above. Behaviour that must stay unchanged: every git case of plan 010, and the `gh` commands `/run-tasks` uses (`gh pr merge <n> --merge`, `gh pr edit <n> --add-label human-merge`, `gh pr checks`, `gh api` reads, `gh issue view`). No images needed. Verification evidence is the test script output and the live refusal.

## Issues to create

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| #107 | `[infra] chore: block gh branch deletion and human-merge removal in the PreToolUse hook` | chore, area:infra, human-merge | - [ ] `block-forbidden-command.sh` refuses, with exit 2 and a message naming the rule: `gh pr merge` and `gh pr close` with `--delete-branch`/`-d` (also in a short-flag cluster or `=true`); `gh pr edit` and `gh issue edit` with `--remove-label` naming `human-merge` (any case, in a comma list or repeated); `gh label delete human-merge`; `gh label edit human-merge --name`; `gh repo edit --delete-branch-on-merge`<br>- [ ] It allows `gh pr merge <n> --merge`, `--delete-branch=false`, `--add-label human-merge`, `--remove-label <other>`, and text that only mentions those commands (PR bodies, commit messages, heredocs)<br>- [ ] `-R`/`--repo`, quoted values, `bash -c`/`sh -c`/`eval`, chains and command prefixes are handled as in the plan's edge-case table, each with a test<br>- [ ] Every existing git case still passes; `test-block-forbidden-command.sh` passes<br>- [ ] The hook header, `CLAUDE.md` and the `run-tasks` skill's Never bullet name the `gh` forms; the header lists the known gaps<br>- [ ] Evidence: test output, `shellcheck` or `Not verified`, and a live refusal in a session | none |
| #108 | `[infra] chore: block gh api branch deletion and human-merge removal in the PreToolUse hook` | chore, area:infra, human-merge | - [ ] The hook refuses every `gh api` call in the plan's `gh api` table, with the method given as `-X`, `--method`, `-XDELETE` or `--method=delete`, before or after the path, and the path with or without a leading `/` or `https://api.github.com/`<br>- [ ] It allows `gh api` reads, `POST` to add labels, and GraphQL queries<br>- [ ] Each blocked and allowed `gh api` case in the edge-case table has a test; all old cases pass<br>- [ ] The hook header lists the `gh api` gaps (`--input`, `@file` fields, label IDs, `curl`)<br>- [ ] Evidence: test output and a live refusal of `gh api -X DELETE repos/<owner>/<repo>/git/refs/heads/does-not-exist` | #107 |
