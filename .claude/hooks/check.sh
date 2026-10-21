#!/usr/bin/env bash
# Claude Code `Stop` hook: before Claude finishes, run the fast checks for the parts
# of the repo that changed. Exit 2 blocks the stop and shows Claude the failures.
#
# Changed = files that differ from the merge base with develop (committed or not),
# plus untracked files.
#   mobile/   flutter analyze, flutter test
#   backend/  ruff check, ruff format --check, mypy, pytest tests/unit
# Integration tests need Docker (docker compose up -d --wait db), so run them by hand
# in Phase 4. After MAX_BLOCKS failed stops in a row the hook lets Claude stop and warns
# the user, so a failure Claude can't fix doesn't loop forever.
# In GitHub Actions (GITHUB_ACTIONS=true) the hook does nothing: the CI workflows run these
# checks, and the runners Claude uses there have no Flutter or Python toolchain (plan 014).
set -uo pipefail

[ "${GITHUB_ACTIONS:-}" = "true" ] && exit 0

MAX_BLOCKS=3

input=$(cat)
session=$(jq -r '.session_id // "unknown"' <<<"$input" 2>/dev/null || echo unknown)
counter="${TMPDIR:-/tmp}/stridequest-stop-hook-${session//[^A-Za-z0-9_-]/_}"

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$root" || exit 0

base=develop
git rev-parse --verify --quiet origin/develop >/dev/null && base=origin/develop
git rev-parse --verify --quiet "$base" >/dev/null || exit 0
merge_base=$(git merge-base "$base" HEAD 2>/dev/null) || exit 0
changed=$({
  git diff --name-only "$merge_base"
  git ls-files --others --exclude-standard
} 2>/dev/null)

run_mobile=false
run_backend=false
grep -q '^mobile/' <<<"$changed" && run_mobile=true
grep -q '^backend/' <<<"$changed" && run_backend=true
if ! $run_mobile && ! $run_backend; then
  rm -f "$counter"
  exit 0
fi

failures=""

# run <label> <dir> <command...>: keep the tail of the output when it fails.
run() {
  local label=$1 dir=$2 output
  shift 2
  if ! output=$(cd "$dir" && "$@" 2>&1); then
    failures+=$'\n'"== ${label} failed: $* =="$'\n'"$(tail -n 40 <<<"$output")"$'\n'
  fi
}

# Prefer the backend's virtualenv, as the docs do.
tool() {
  if [ -x "$root/backend/.venv/bin/$1" ]; then echo "$root/backend/.venv/bin/$1"; else echo "$1"; fi
}

if $run_mobile; then
  run "mobile lint" mobile flutter analyze
  run "mobile tests" mobile flutter test
fi
if $run_backend; then
  run "backend lint" backend "$(tool ruff)" check .
  run "backend format" backend "$(tool ruff)" format --check .
  run "backend types" backend "$(tool mypy)"
  run "backend unit tests" backend "$(tool pytest)" -q tests/unit
fi

if [ -z "$failures" ]; then
  rm -f "$counter"
  exit 0
fi

blocks=$(($(cat "$counter" 2>/dev/null || echo 0) + 1))
if [ "$blocks" -gt "$MAX_BLOCKS" ]; then
  rm -f "$counter"
  message="Stop hook: checks still fail after $MAX_BLOCKS attempts, so Claude was allowed to stop. Review the failures before merging."
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg message "$message" '{systemMessage: $message}'
  fi
  exit 0
fi

echo "$blocks" >"$counter"
{
  echo "The checks for the files you changed failed (attempt $blocks of $MAX_BLOCKS). Fix them before you finish:"
  echo "$failures"
} >&2
exit 2
