#!/usr/bin/env bash
# Claude Code `PostToolUse` hook for the Edit and Write tools: format the file Claude just
# wrote, so the `Stop` hook's `ruff format --check` has nothing to complain about.
#
#   backend/**/*.py                            ruff format (config: backend/pyproject.toml)
#   mobile/lib/**/*.dart, mobile/test/**/*.dart  dart format
#
# Skipped: generated Dart (*.g.dart, *.freezed.dart, *.config.dart), backend/.venv, every
# other file type, paths outside the project, missing files and missing tools. Only the one
# file is touched. The hook never blocks: it always exits 0, so a formatter that fails on a
# half-written file loses nothing.
# Needs jq. Tests: .claude/hooks/test-format-on-edit.sh
set -o pipefail

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
file=$(jq -r '.tool_input.file_path // empty' <<<"$input" 2>/dev/null) || exit 0
[ -n "$file" ] && [ -f "$file" ] || exit 0
# A symlinked file could point outside the project, and the formatters follow the link.
[ ! -L "$file" ] || exit 0

root=${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)} || exit 0
root=$(cd "$root" 2>/dev/null && pwd -P) || exit 0
abs="$(cd "$(dirname "$file")" 2>/dev/null && pwd -P)/$(basename "$file")" || exit 0
rel=${abs#"$root"/}
[ "$rel" != "$abs" ] || exit 0

format_python() {
  local ruff="$root/backend/.venv/bin/ruff"
  [ -x "$ruff" ] || ruff=$(command -v ruff) || return 0
  (cd "$root/backend" && "$ruff" format --quiet --force-exclude "$abs") >/dev/null 2>&1
}

format_dart() {
  command -v dart >/dev/null 2>&1 || return 0
  (cd "$root/mobile" && dart format "$abs") >/dev/null 2>&1
}

case "$rel" in
  *.g.dart | *.freezed.dart | *.config.dart) ;;
  backend/.venv/*) ;;
  backend/*.py) format_python ;;
  mobile/lib/*.dart | mobile/test/*.dart) format_dart ;;
esac

exit 0
