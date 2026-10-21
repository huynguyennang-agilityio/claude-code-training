#!/usr/bin/env bash
# Tests for block-forbidden-command.sh: feed each command to the hook as the JSON that
# Claude Code sends, in a throwaway repo, and compare the exit code.
#   bash .claude/hooks/test-block-forbidden-command.sh
set -uo pipefail

hook="$(cd "$(dirname "$0")" && pwd)/block-forbidden-command.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# One repo with develop checked out, one with a feature branch checked out.
for spec in "on-develop:develop" "on-feature:feat/22-x"; do
  repo="$tmp/${spec%%:*}"
  git init -q -b develop "$repo"
  git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
  [ "${spec#*:}" = develop ] || git -C "$repo" switch -q -c "${spec#*:}"
done

pass=0
fail=0

# check <blocked|allowed> <on-develop|on-feature> <command>
check() {
  local expect=$1 repo=$2 cmd=$3 input code stderr
  input=$(jq -n --arg c "$cmd" '{tool_name: "Bash", tool_input: {command: $c}}')
  stderr=$(cd "$tmp/$repo" && "$hook" <<<"$input" 2>&1 >/dev/null)
  code=$?
  if { [ "$expect" = blocked ] && [ $code -eq 2 ] && [ -n "$stderr" ]; } ||
    { [ "$expect" = allowed ] && [ $code -eq 0 ]; }; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL (expected $expect, exit $code, $repo): $cmd"
  fi
}

blocked() { check blocked "$1" "$2"; }
allowed() { check allowed "$1" "$2"; }

# --- pushes to develop or main ---
blocked on-feature 'git push origin develop'
blocked on-feature 'git push origin main'
blocked on-feature 'git push -u origin develop'
blocked on-feature 'git push origin HEAD:develop'
blocked on-feature 'git push origin feat/x:main'
blocked on-feature 'git push origin refs/heads/main'
blocked on-develop 'git push'
blocked on-develop 'git push origin'
blocked on-develop 'git push -u origin HEAD'

# --- force and delete ---
blocked on-feature 'git push --force origin feat/x'
blocked on-feature 'git push -f origin feat/x'
blocked on-feature 'git push origin feat/x --force'
blocked on-feature 'git push --force-with-lease origin feat/x'
blocked on-feature 'git push --force-with-lease=feat/x origin feat/x'
blocked on-feature 'git push --force-if-includes origin feat/x'
blocked on-feature 'git push origin +feat/x'
blocked on-feature 'git push -fu origin feat/x'
blocked on-feature 'git push origin :feat/x'
blocked on-feature 'git push origin --delete feat/x'
blocked on-feature 'git push -d origin feat/x'
blocked on-feature 'git push --mirror origin'
blocked on-feature 'git push --all origin'
blocked on-feature 'git push --prune origin'
blocked on-feature 'git branch -d feat/x'
blocked on-feature 'git branch -D feat/x'
blocked on-feature 'git branch --delete feat/x'
blocked on-feature 'git branch -dr origin/x'

# --- the gitlab remote ---
blocked on-feature 'git push gitlab feat/x'
blocked on-feature 'git push -u gitlab feat/x'
blocked on-feature 'git push git@gitlab.com:team/stridequest.git feat/x'

# --- hidden behind other syntax ---
blocked on-feature 'git -C . push -f origin feat/x'
blocked on-feature 'git -c push.default=current push origin develop'
blocked on-feature 'cd mobile && git push --force origin feat/x'
blocked on-feature 'git status; git push origin main'
blocked on-feature 'git fetch | git push origin main'
blocked on-feature '(git push origin main)'
# shellcheck disable=SC2016  # the $( ) must reach the hook literally
blocked on-feature 'echo $(git push origin main)'
blocked on-feature 'FOO=1 git push origin main'
blocked on-feature '/usr/bin/git push origin develop'
blocked on-feature 'sudo git push -f origin feat/x'
blocked on-feature 'git push origin "develop"'
blocked on-feature 'bash -c "git push -f origin feat/x"'
blocked on-feature "sh -c 'git push origin main'"
blocked on-feature 'eval "git branch -D feat/x"'
blocked on-feature $'git status\ngit push origin main'

# --- allowed ---
allowed on-feature 'git push -u origin feat/22-block-forbidden-command'
allowed on-feature 'git push origin docs/plan-010-x'
allowed on-feature 'git push origin HEAD'
allowed on-feature 'git push'
allowed on-feature 'git push origin'
allowed on-feature 'git push origin feat/main-menu'
allowed on-feature 'git push origin feature/develop-notes'
allowed on-feature 'git push origin feat/x --tags'
allowed on-feature 'git push -o ci.skip origin feat/x'
allowed on-feature 'git push --dry-run origin feat/x'
allowed on-feature 'git branch --show-current'
allowed on-feature 'git branch -a'
allowed on-feature 'git branch -vv'
allowed on-feature 'git branch feat/new'
allowed on-feature 'git log --oneline develop..HEAD'
allowed on-feature 'git diff develop...HEAD'
allowed on-feature 'git fetch origin develop'
allowed on-feature 'git pull origin develop'
allowed on-feature 'git checkout develop'
allowed on-feature 'git switch -c feat/y origin/develop'
allowed on-feature 'git merge origin/develop'
allowed on-feature 'git remote -v'
allowed on-feature 'git tag -d v0.1.0'
allowed on-feature 'git commit -m "fix: never git push --force to main"'
allowed on-feature 'git commit -m "docs; git push -f origin main"'
allowed on-feature 'git commit -m "x" && git push origin feat/x'
allowed on-feature $'git commit -m "$(cat <<\'EOF\'\nfix: block git push origin main\n\nBody; git push -f\nEOF\n)"'
allowed on-feature $'gh pr create --body "$(cat <<\'EOF\'\nRefuses `git push --force` and `git push origin main`\n- `git branch -D x`\nEOF\n)"'
allowed on-feature 'echo "git push -f origin main"'
blocked on-feature $'git push origin main <<\'EOF\'\nplain text\nEOF'
blocked on-feature $'cat <<EOF\n$(git push origin main)\nEOF'
allowed on-feature 'gh pr create --base develop --head feat/x'
allowed on-feature 'cat docs/gitlab.md'
allowed on-feature 'ls .claude/hooks'
allowed on-feature 'bash .claude/hooks/check.sh'
allowed on-develop 'git push origin feat/x'
allowed on-develop 'git status'

# --- input the hook cannot use is allowed ---
for raw in '' 'not json' '{}' '{"tool_input":{}}'; do
  if "$hook" <<<"$raw" >/dev/null 2>&1; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL (expected allowed): raw input '$raw'"
  fi
done

echo "$pass passed, $fail failed"
[ $fail -eq 0 ]
