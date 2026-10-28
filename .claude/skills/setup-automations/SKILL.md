---
name: setup-automations
description: Set up the StrideQuest Desktop scheduled task on this Mac, the 17:00 PR report (`stridequest-pr-report`, which runs /pr-report). Use when the user asks to set up the StrideQuest automations, or when the SessionStart hook says the task is missing.
---

# Set up StrideQuest automations

Creates the evening PR report task from [plan 016](../../../docs/plans/016-cloud-routines.md) on this person's Mac, so they get the same task as everyone else. [`docs/automations.md`](../../../docs/automations.md) describes it. The morning Slack routine is a claude.ai routine in one account and is not set up here.

## Steps

1. **Check that this is Claude Desktop.** Desktop scheduled tasks need the scheduled-tasks tools `list_scheduled_tasks` and `create_scheduled_task`. If they are not available (for example in the CLI or a cloud session), tell the user that the task needs Claude Desktop on their Mac, point to `docs/automations.md`, and stop.
2. **Look for the task.** Call `list_scheduled_tasks`.
   - If `stridequest-pr-report` exists and its prompt is `Run /pr-report.`, say it is already set up and stop.
   - If it exists with another prompt (an older setup), do not change it. Show the user the current prompt next to `Run /pr-report.`, and tell them to change it in the task's **Edit** form under **Scheduled**. Then stop.
3. **Ask the user before creating it.** Say what will be created:
   - a Desktop scheduled task, daily at 17:00 local time;
   - it runs `/pr-report` in this repo folder;
   - it only reads GitHub with `gh`;
   - it publishes a private English artifact in their own account each day;
   - it runs only while Claude Desktop is open and the Mac is awake.

   Create nothing without a clear yes.
4. **Create it** with `create_scheduled_task`:
   - `taskId`: `stridequest-pr-report`
   - `title`: `StrideQuest PR report`
   - `description`: `Daily 17:00: StrideQuest PR report (runs /pr-report). Plan 016.`
   - `cronExpression`: `0 17 * * *` (local time)
   - `prompt`: `Run /pr-report.`

   The task runs in the folder of this session, so check that the session is in the repo root (the folder that contains `CLAUDE.md`).
5. **Tell the user what to do next:**
   - Open the task under **Scheduled** in the sidebar and click **Run now** once.
   - When asked, choose "always allow" for the read-only `gh` commands and the artifact publish, so later runs do not stop.
   - Optional: turn on **Keep computer awake** in **Settings > This computer > System**, so 17:00 runs are not skipped.
   - The task's permission mode can be changed in its **Edit** form.

Never change or delete an existing task: this skill only creates `stridequest-pr-report` when it is missing.
