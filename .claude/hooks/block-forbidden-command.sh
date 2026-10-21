#!/usr/bin/env bash
# Claude Code `PreToolUse` hook for the Bash tool: refuse the git commands that CLAUDE.md
# ("Git and GitHub permissions") says Claude never runs. Exit 2 blocks the command and
# shows Claude the reason.
#
# Blocked:
#   git push to develop or main (also a bare `git push` while one of them is checked out)
#   git push --force / -f / --force-with-lease / --force-if-includes / +refspec
#   git push --delete / -d / :refspec / --mirror / --all / --prune
#   git branch -d / -D / --delete
#   git push to the gitlab remote (the user mirrors GitLab by hand)
#
# Best effort, not a security boundary: the command text is split on ; & | ( ) ` and
# newlines (not inside quotes), and `sh -c` / `bash -c` / `eval` strings are scanned too.
# A command built through a variable or a script file can still slip past.
# Needs jq and perl; without them the hook warns and allows the command.
# Tests: .claude/hooks/test-block-forbidden-command.sh
set -o pipefail

block() {
  echo "Blocked by .claude/hooks/block-forbidden-command.sh: $1. CLAUDE.md (Git and GitHub permissions) says Claude never does this; ask the user to run it themselves." >&2
  exit 2
}

is_protected() { [ "$1" = develop ] || [ "$1" = main ]; }

# git_cmd is `git` or `git -C <dir>`, set by analyze_fragment.
current_branch() { "${git_cmd[@]}" symbolic-ref --short -q HEAD 2>/dev/null || true; }

check_push() {
  local arg skip=false remote="" spec dest branch
  local refs=()
  for arg in "$@"; do
    if $skip; then
      skip=false
      continue
    fi
    case "$arg" in
      -o | --push-option | --repo | --receive-pack | --exec) skip=true ;;
      --force | --force-with-lease | --force-with-lease=* | --force-if-includes)
        block "force-push" ;;
      --delete) block "deleting a remote branch" ;;
      --mirror | --all | --prune) block "git push $arg can overwrite or delete remote branches" ;;
      --*) ;;
      -*)
        case "$arg" in *f*) block "force-push" ;; esac
        case "$arg" in *d*) block "deleting a remote branch" ;; esac
        ;;
      *)
        if [ -z "$remote" ]; then remote=$arg; else refs+=("$arg"); fi
        ;;
    esac
  done

  case "$remote" in
    *[gG][iI][tT][lL][aA][bB]*) block "pushing to the gitlab remote" ;;
  esac

  if [ ${#refs[@]} -eq 0 ]; then
    branch=$(current_branch)
    is_protected "$branch" && block "pushing $branch"
    return
  fi
  for spec in "${refs[@]}"; do
    case "$spec" in
      +*) block "force-push" ;;
      :*) block "deleting a remote branch" ;;
    esac
    dest=${spec##*:}
    dest=${dest#refs/heads/}
    [ "$dest" = HEAD ] && dest=$(current_branch)
    is_protected "$dest" && block "pushing to $dest"
  done
}

check_branch() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --delete) block "deleting a branch" ;;
      --*) ;;
      -*) case "$arg" in *d* | *D*) block "deleting a branch" ;; esac ;;
    esac
  done
}

# analyze_fragment <one simple command>: only `git push` and `git branch` are checked.
analyze_fragment() {
  local frag=$1 toks=() i=0 n dir="" sub
  frag=${frag//\"/}
  frag=${frag//\'/}
  read -r -a toks <<<"$frag"
  n=${#toks[@]}

  while [ "$i" -lt "$n" ]; do
    case "${toks[$i]}" in
      *=* | sudo | command | env | time | exec | nohup) i=$((i + 1)) ;;
      *) break ;;
    esac
  done
  [ "$i" -ge "$n" ] && return
  [ "${toks[$i]##*/}" = git ] || return
  i=$((i + 1))

  while [ "$i" -lt "$n" ]; do
    case "${toks[$i]}" in
      -C)
        dir=${toks[$((i + 1))]:-}
        i=$((i + 2))
        ;;
      -c | --git-dir | --work-tree | --namespace) i=$((i + 2)) ;;
      -*) i=$((i + 1)) ;;
      *) break ;;
    esac
  done
  sub=${toks[$i]:-}
  local rest=("${toks[@]:$((i + 1))}")

  git_cmd=(git)
  [ -n "$dir" ] && git_cmd=(git -C "$dir")

  case "$sub" in
    push) check_push "${rest[@]}" ;;
    branch) check_branch "${rest[@]}" ;;
  esac
}

# scan <perl program> <command text>: split into simple commands and check each one.
scan() {
  local frags frag
  frags=$(perl -0pe "$1" <<<"$2") || return 0
  while IFS= read -r frag; do
    analyze_fragment "$frag"
  done <<<"$frags"
}

for tool in jq perl; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "block-forbidden-command.sh: $tool is not installed, so the command was not checked." >&2
    exit 0
  fi
done

input=$(cat)
command_text=$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null) || exit 0
[ -n "$command_text" ] || exit 0

# shellcheck disable=SC2016  # the perl programs are meant to be literal
# Pass 1: inside quotes, ; & | and newlines become spaces, so a commit message that
# mentions `git push -f` stays one harmless argument. Outside quotes they split commands.
scan 's/("(?:\\.|[^"\\])*"|\x27[^\x27]*\x27)/(my $q = $1) =~ tr{;&|\n}{    }; $q/ge;
     s/&&|\|\||[;|&\n()`]/\n/g' "$command_text"

# shellcheck disable=SC2016
# Pass 2: a shell string (`bash -c "..."`, `eval "..."`) runs its content, so look inside quotes.
if grep -Eq '(sh|bash|zsh|dash)[[:space:]]+-[a-zA-Z]*c|(^|[^[:alnum:]_])eval[[:space:]]' <<<"$command_text"; then
  scan 's/["\x27]/\n/g; s/&&|\|\||[;|&\n()`]/\n/g' "$command_text"
fi

exit 0
