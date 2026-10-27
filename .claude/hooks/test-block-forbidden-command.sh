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
blocked on-feature 'git -c user.name="A B" push origin main'
blocked on-feature 'git -C "my dir" push origin main'
blocked on-feature 'GIT_SSH_COMMAND="ssh -i k" git push origin main'
blocked on-feature 'git push --repo=gitlab'
blocked on-feature 'git push --repo gitlab feat/x'

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
allowed on-feature 'git -c user.name="A B" commit -m "x y"'
allowed on-feature 'GIT_SSH_COMMAND="ssh -i k" git push origin feat/x'
allowed on-feature 'git push --repo=origin feat/x'
allowed on-feature 'git branch --sort -committerdate'
allowed on-feature 'git branch --merged develop'
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

# --- gh: deleting a branch ---
blocked on-feature 'gh pr merge 5 --merge --delete-branch'
blocked on-feature 'gh pr merge 5 --merge -d'
blocked on-feature 'gh pr merge 5 -sd'
blocked on-feature 'gh pr merge 5 -dm'
blocked on-feature 'gh pr merge 5 --delete-branch=true'
blocked on-feature 'gh pr merge 5 --delete-branch=1'
blocked on-feature 'gh pr merge --auto --squash --delete-branch'
blocked on-feature 'gh pr close 5 -d'
blocked on-feature 'gh pr close 5 --comment "done" --delete-branch'
blocked on-feature 'gh pr merge 5 --repo o/r -d'
blocked on-feature 'gh -R o/r pr merge 5 -d'
blocked on-feature 'gh pr -R o/r merge 5 -d'
blocked on-feature 'gh pr merge 5 -t "x y" -d'
blocked on-feature 'gh repo edit --delete-branch-on-merge'
blocked on-feature 'gh repo edit o/r --delete-branch-on-merge=true'

# --- gh: removing, deleting or renaming human-merge ---
blocked on-feature 'gh pr edit 5 --remove-label human-merge'
blocked on-feature 'gh issue edit 5 --remove-label human-merge'
blocked on-feature 'gh pr edit 5 --remove-label=human-merge'
blocked on-feature 'gh pr edit 5 --remove-label "human-merge"'
blocked on-feature "gh pr edit 5 --remove-label 'bug, human-merge'"
blocked on-feature 'gh pr edit 5 --remove-label bug,human-merge'
blocked on-feature 'gh pr edit 5 --remove-label Human-Merge'
blocked on-feature 'gh pr edit 5 --remove-label bug --remove-label human-merge'
blocked on-feature 'gh issue edit 5 6 --add-label bug --remove-label human-merge'
blocked on-feature 'gh issue edit 5 -R o/r --remove-label human-merge'
blocked on-feature 'gh -R o/r issue edit 5 --remove-label human-merge'
blocked on-feature 'gh label delete human-merge --yes'
blocked on-feature 'gh label delete --yes human-merge'
blocked on-feature 'gh label edit human-merge --name merge-ok'
blocked on-feature 'gh label edit human-merge -n merge-ok'
blocked on-feature 'gh label edit human-merge --name=merge-ok'

# --- gh: hidden behind other syntax ---
blocked on-feature 'bash -c "gh pr merge 5 --merge -d"'
blocked on-feature "sh -c 'gh pr edit 5 --remove-label human-merge'"
blocked on-feature 'eval "gh pr close 5 -d"'
blocked on-feature 'gh pr checks 5 && gh pr merge 5 --merge -d'
blocked on-feature '(gh pr close 5 -d)'
blocked on-feature 'GH_REPO=o/r gh pr merge 5 -d'
blocked on-feature 'env GH_REPO=o/r gh pr merge 5 -d'
blocked on-feature '/opt/homebrew/bin/gh pr merge 5 -d'
blocked on-feature $'gh pr view 5\ngh pr edit 5 --remove-label human-merge'

# --- gh: allowed ---
allowed on-feature 'gh pr merge 5 --merge'
allowed on-feature 'gh pr merge 5 --squash --auto'
allowed on-feature 'gh pr merge 5 --delete-branch=false'
allowed on-feature 'gh pr merge 5 --merge -t "drop -d flag"'
allowed on-feature 'gh pr merge 5 -m -t -d'
allowed on-feature 'gh pr merge 5 -td'
allowed on-feature 'gh pr merge 5 --merge -b "use -d later"'
allowed on-feature 'gh pr close 5 --comment "superseded"'
allowed on-feature 'gh pr edit 5 --add-label human-merge'
allowed on-feature 'gh pr edit 5 --remove-label bug'
allowed on-feature 'gh pr edit 5 --remove-label human-merge-later'
allowed on-feature 'gh issue edit 5 --remove-label "needs triage"'
allowed on-feature 'gh pr edit 5 --title "--remove-label human-merge"'
allowed on-feature 'gh pr view 5 --json labels'
allowed on-feature 'gh issue view 107 --json labels'
allowed on-feature 'gh label list'
allowed on-feature 'gh label edit human-merge --description "Stop /run-tasks"'
allowed on-feature 'gh label delete stale --yes'
allowed on-feature 'gh repo edit --delete-branch-on-merge=false'
allowed on-feature 'gh repo view'
allowed on-feature 'gh pr checks 5 --watch --required'
allowed on-feature 'gh pr create --body "never gh pr merge -d or --remove-label human-merge"'
allowed on-feature 'git commit -m "block gh pr edit --remove-label human-merge"'
allowed on-feature $'gh pr create --body "$(cat <<\'EOF\'\nNever run gh pr merge 5 --delete-branch\nor gh pr edit 5 --remove-label human-merge\nEOF\n)"'
allowed on-feature 'gh api repos/o/r/pulls/5/files --paginate'

# --- nested quotes and parentheses inside quotes (review of #109) ---
blocked on-feature "bash -c \"gh pr merge 5 --merge -t 'Release' -d\""
blocked on-feature "bash -c \"gh pr edit 5 --remove-label 'human-merge'\""
blocked on-feature "sh -c 'gh pr edit 5 --remove-label \"bug, human-merge\"'"
blocked on-feature "bash -c \"git -c user.name='A B' push origin main\""
blocked on-feature 'gh pr merge 5 -t "fix (x)" -d'
blocked on-feature 'gh pr close 5 -c "done (for now)" --delete-branch'
# shellcheck disable=SC2016  # the $( ) and backticks must reach the hook literally
blocked on-feature 'gh pr create --body "$(git push origin main)"'
# shellcheck disable=SC2016
blocked on-feature 'echo "`git push origin main`"'
allowed on-feature 'gh pr create --body "see (gh pr merge -d)"'
allowed on-feature 'git commit -m "fix: block (git push origin main)"'
# shellcheck disable=SC2016
allowed on-feature "echo '\$(git push origin main)'"
allowed on-feature 'gh pr merge 5 --delete-branch=0'
allowed on-feature 'gh pr merge 5 --delete-branch=f'
blocked on-feature 'gh pr close 5 -c x -d'

# --- gh api ---
blocked on-feature 'gh api -X DELETE repos/o/r/git/refs/heads/feat/x'
blocked on-feature 'gh api repos/o/r/git/refs/heads/x -X DELETE'
blocked on-feature 'gh api -XDELETE /repos/o/r/git/refs/heads/x'
blocked on-feature 'gh api --method=delete https://api.github.com/repos/o/r/git/refs/heads/x'
blocked on-feature 'gh api -X PATCH repos/o/r/git/refs/heads/main -f sha=abc -F force=true'
blocked on-feature 'gh api -X DELETE repos/o/r/issues/5/labels/human-merge'
blocked on-feature 'gh api -XDELETE /repos/{owner}/{repo}/issues/5/labels/Human-Merge'
blocked on-feature 'gh api -X DELETE repos/o/r/issues/5/labels'
blocked on-feature "gh api --method put repos/o/r/issues/5/labels -f 'labels[]=bug'"
blocked on-feature "gh api -X PATCH repos/o/r/issues/5 -f 'labels[]=bug'"
blocked on-feature 'gh api -X PATCH repos/o/r/pulls/5 --field labels=bug'
blocked on-feature 'gh api -X DELETE repos/o/r/labels/human-merge'
blocked on-feature 'gh api -X PATCH repos/o/r/labels/human-merge -f new_name=ok'
blocked on-feature 'gh api -X PATCH repos/o/r -F delete_branch_on_merge=true'
blocked on-feature "gh api graphql -f query='mutation { deleteRef(input: {refId: \"x\"}) { clientMutationId } }'"
blocked on-feature "gh api graphql -f query='mutation { removeLabelsFromLabelable(input: {labelableId: \"x\", labelIds: [\"y\"]}) { clientMutationId } }'"
blocked on-feature 'eval "gh api -X DELETE repos/o/r/git/refs/heads/x"'
blocked on-feature "bash -c \"gh api -X DELETE 'repos/o/r/issues/5/labels/human-merge'\""
allowed on-feature "gh api repos/o/r/issues/5/comments --jq '.[].body'"
allowed on-feature "gh api -X POST repos/o/r/issues/5/labels -f 'labels[]=human-merge'"
allowed on-feature "gh api repos/o/r/issues/5/labels -f 'labels[]=human-merge'"
allowed on-feature 'gh api -X DELETE repos/o/r/issues/comments/9'
allowed on-feature 'gh api -X DELETE repos/o/r/issues/5/labels/bug'
allowed on-feature 'gh api -X PATCH repos/o/r/issues/5 -f title=x'
allowed on-feature 'gh api -X PATCH repos/o/r -F delete_branch_on_merge=false'
allowed on-feature 'gh api repos/o/r/git/refs/heads/main'
allowed on-feature "gh api graphql -f query='query { viewer { login } }'"

# --- release tags: pushing a new tag is allowed; deleting, moving or force-pushing one is not ---
allowed on-feature 'git push origin refs/tags/v1.2.3'
allowed on-feature 'git push origin refs/tags/api-v1.2.3'
allowed on-develop 'git push origin refs/tags/ios-v0.1.0'
allowed on-feature 'git push origin v1.2.3'
allowed on-feature 'git tag -a v1.2.3 origin/main -m "StrideQuest v1.2.3"'
allowed on-feature 'gh api repos/o/r/git/refs/tags/v1'
allowed on-feature 'gh release delete v1.2.3 --yes'
allowed on-feature 'gh release delete v1.2.3 --cleanup-tag=false'
blocked on-feature 'git push origin :refs/tags/v1.2.3'
blocked on-feature 'git push origin :v1.2.3'
blocked on-feature 'git push --delete origin v1.2.3'
blocked on-feature 'git push origin --delete refs/tags/v1.2.3'
blocked on-feature 'git push -d origin v1.2.3'
blocked on-feature 'git push -f origin refs/tags/v1.2.3'
blocked on-feature 'git push --force origin v1.2.3'
blocked on-feature 'git push origin +refs/tags/v1.2.3'
blocked on-feature 'git push origin +v1.2.3'
blocked on-feature 'git push --force origin --tags'
blocked on-feature 'gh api -X DELETE repos/o/r/git/refs/tags/v1'
blocked on-feature 'gh api --method PATCH repos/o/r/git/refs/tags/v1 -f sha=abc -F force=true'
blocked on-feature 'gh release delete v1.2.3 --cleanup-tag'
blocked on-feature 'gh release delete v1.2.3 --yes --cleanup-tag=true'
blocked on-feature 'gh release delete -R o/r v1.2.3 --cleanup-tag'

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
