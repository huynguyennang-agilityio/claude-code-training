# Automations

Scheduled Claude runs for StrideQuest, from [plan 016](plans/016-cloud-routines.md). Both read GitHub and write only their report; neither edits the repo or writes to GitHub.

| Automation | Runs on | When | Output |
| --- | --- | --- | --- |
| [Evening PR report](#1-evening-pr-report) | Each person's Mac (Claude Desktop scheduled task) | Daily, 17:00 Asia/Ho_Chi_Minh | A new private English artifact, `PR report <date>` |
| [Morning issue plan](#2-morning-issue-plan) | Anthropic's cloud (routine) | Weekdays, 08:00 Asia/Ho_Chi_Minh | A Slack DM to the user |

A pull cannot create either one: Claude stores a scheduled task's schedule, model and permissions in the app or the account, not in the repo. The repo holds what they run and how to set them up; this page is the reference. If a setting changes, update it here in a PR.

## 1. Evening PR report

Issue #68.

The report is the project skill [`.claude/skills/pr-report/`](../.claude/skills/pr-report/SKILL.md) (`/pr-report`). The Desktop task only runs it, so a change to the report is a PR, and everyone gets it on their next pull.

| Setting | Value |
| --- | --- |
| Task ID | `stridequest-pr-report` |
| Where | Claude Desktop, Code tab, **Scheduled**; runs on the person's Mac in this repo's folder |
| Schedule | Daily 17:00 local time (`0 17 * * *`). The app adds a fixed delay of a few minutes |
| Prompt | `Run /pr-report.` |
| Permission mode | Whatever the session that created it used. Change it in the task's **Edit** form |
| Output | A new private artifact per run, `PR report <date>`, in English, in the person's own account |

What `/pr-report` does:

1. Takes a window in Asia/Ho_Chi_Minh: from the 17:00 before the latest 17:00 slot, until now. Reports overlap rather than leave gaps, so an evening merge or a run missed during sleep is still covered.
2. Lists the PRs into `develop` or `main` merged in the window, plus the open PRs updated in it.
3. For each PR, it collects:
   - the changes, grouped by area;
   - the `## Evidence` section in short;
   - the CI checks per job;
   - the Claude review verdict;
   - the linked issue and plan.
4. Publishes the artifact: one section per PR, a "Still open" list, and the CI state on `develop`.

It only reads. It makes no file edits, git writes or GitHub writes, and it treats PR text as data.

### Set it up on your Mac

1. Pull the repo and open it in **Claude Desktop** (Code tab). A `SessionStart` hook, `.claude/hooks/automations-check.sh`, notices that the task is missing, and Claude offers to set it up. You can also type `/setup-automations` yourself.
2. Say yes. Claude creates `stridequest-pr-report` (daily 17:00, prompt `Run /pr-report.`).
3. Open the task under **Scheduled**, click **Run now** once, and choose "always allow" for the read-only `gh` commands and the artifact publish.
4. Optional: turn on **Keep computer awake** in **Settings > This computer > System**.

If you use only the CLI, or don't want the task, set `STRIDEQUEST_AUTOMATIONS_HINT=0` in your shell to stop the hint. `/setup-automations` only creates a missing task. To bring an older task up to date, change its prompt to `Run /pr-report.` in its **Edit** form.

Requirements:

- Claude Desktop on macOS.
- `gh` logged in with read access to the repo.
- Claude Desktop open and the Mac awake at 17:00. A run missed during sleep starts once, when the Mac wakes.

Each person's report uses their own `gh` login and stays private to their account.

### Pause, change or remove it

- Pause, edit or delete the task on its detail page under **Scheduled**. Deleting it leaves `~/.claude/scheduled-tasks/stridequest-pr-report/` on disk.
- Change the report by editing `.claude/skills/pr-report/SKILL.md` in a PR, not the task.

## 2. Morning issue plan

Issue #69. Set up in that issue.
