#!/usr/bin/env bash
# Claude Code `SessionStart` hook: when this Mac has no `stridequest-pr-report` Desktop
# scheduled task yet, tell Claude so it can offer `/setup-automations` (plan 016).
#
# It only prints context for Claude; it never creates a task. It does nothing:
#   - when STRIDEQUEST_AUTOMATIONS_HINT=0 (for people who use only the CLI, or said no),
#   - in GitHub Actions (GITHUB_ACTIONS=true) or a cloud session (CLAUDE_CODE_REMOTE=true),
#   - off macOS (Desktop scheduled tasks need Claude Desktop on this Mac),
#   - when the task's SKILL.md already exists under ${CLAUDE_CONFIG_DIR:-~/.claude}.
# It always exits 0. Tests: .claude/hooks/test-automations-check.sh
set -uo pipefail

[ "${STRIDEQUEST_AUTOMATIONS_HINT:-1}" = 0 ] && exit 0
[ "${GITHUB_ACTIONS:-}" = "true" ] && exit 0
[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] && exit 0
[ "$(uname)" = Darwin ] || exit 0

task="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/scheduled-tasks/stridequest-pr-report/SKILL.md"
[ -f "$task" ] && exit 0

cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"StrideQuest automations: this Mac has no `stridequest-pr-report` Desktop scheduled task (the 17:00 PR report, docs/automations.md). At a natural point early in the conversation, tell the user in one line and offer to run /setup-automations. Do not create the task without the user's yes."}}
JSON
exit 0
