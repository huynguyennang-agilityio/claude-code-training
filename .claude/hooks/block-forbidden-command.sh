#!/usr/bin/env bash
# Claude Code `PreToolUse` hook for the Bash tool: refuse the git commands that CLAUDE.md
# ("Git and GitHub permissions") says Claude never runs, and their gh forms. Exit 2 blocks
# the command and shows Claude the reason.
#
# Blocked:
#   git push to develop or main (also a bare `git push` while one of them is checked out)
#   git push --force / -f / --force-with-lease / --force-if-includes / +refspec
#   git push --delete / -d / :refspec / --mirror / --all / --prune (branches and tags alike:
#     a release tag is never deleted, moved or force-pushed; pushing a new one is allowed)
#   git branch -d / -D / --delete
#   git push to the gitlab remote (the user mirrors GitLab by hand)
#   gh pr merge / gh pr close with --delete-branch / -d (also in a cluster such as -sd)
#   gh pr edit / gh issue edit --remove-label naming human-merge (any case, in a list too)
#   gh label delete human-merge, gh label edit human-merge --name
#   gh repo edit --delete-branch-on-merge
#   gh release delete --cleanup-tag (deletes the tag with the release)
#   gh api: DELETE on git/refs/heads/<branch>; any write to git/refs/heads/develop or main;
#     DELETE or PATCH on git/refs/tags/<tag> (deleting or moving a tag);
#     DELETE on issues/<n>/labels/human-merge; DELETE or PUT on issues/<n>/labels; PATCH on
#     issues/<n> or pulls/<n> with a labels field; DELETE or PATCH on labels/human-merge;
#     PATCH on the repository with delete_branch_on_merge; GraphQL deleteRef, updateRefs,
#     removeLabelsFromLabelable, clearLabelsFromLabelable, deleteLabel, updateLabel
# human-merge is the label that makes /run-tasks stop for the user (plan 021).
#
# Best effort, not a security boundary: the command text is split on ; & | ( ) ` and
# newlines (not inside quotes). Then each $(...) and `...` inside double quotes, and, when
# the command has `sh -c` / `bash -c` / `eval`, every quoted string, is split and checked
# the same way, up to three levels deep.
# Known gaps: a command built through a variable or a script file; a bare `git push` after
# a `checkout`, `switch` or `cd` in the same command (the branch is read before they run);
# exotic refs such as `develop^{}`; `git update-ref -d`; a gh alias or extension;
# `gh api --input <file>` and `@file` fields (the body is in a file); GraphQL that removes
# a label by ID through another mutation; `curl` calls to the GitHub API. Known nuisance:
# when the command contains `bash -c` or `eval`, any quoted string that reads as a blocked
# command is blocked too.
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
  local arg pending="" remote="" spec dest branch
  local refs=()
  for arg in "$@"; do
    if [ -n "$pending" ]; then
      [ "$pending" = repo ] && remote=$arg
      pending=""
      continue
    fi
    case "$arg" in
      -o | --push-option | --receive-pack | --exec) pending=skip ;;
      --repo) pending=repo ;;
      --repo=*) remote=${arg#--repo=} ;;
      --force | --force-with-lease | --force-with-lease=* | --force-if-includes)
        block "force-push (of a branch or a tag)" ;;
      --delete) block "deleting a remote branch or tag" ;;
      --mirror | --all | --prune) block "git push $arg can overwrite or delete remote branches" ;;
      --*) ;;
      -*)
        case "$arg" in *f*) block "force-push (of a branch or a tag)" ;; esac
        case "$arg" in *d*) block "deleting a remote branch or tag" ;; esac
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
      +refs/tags/*) block "force-pushing a tag" ;;
      :refs/tags/*) block "deleting a remote tag" ;;
      +*) block "force-push" ;;
      :*) block "deleting a remote branch or tag" ;;
    esac
    dest=${spec##*:}
    dest=${dest#refs/heads/}
    [ "$dest" = HEAD ] && dest=$(current_branch)
    is_protected "$dest" && block "pushing to $dest"
  done
}

check_branch() {
  local arg skip=false
  for arg in "$@"; do
    if $skip; then
      skip=false
      continue
    fi
    case "$arg" in
      --delete) block "deleting a branch" ;;
      --sort | --format | --contains | --no-contains | --merged | --no-merged | --points-at) skip=true ;;
      --*) ;;
      -*) case "$arg" in *d* | *D*) block "deleting a branch" ;; esac ;;
    esac
  done
}

# --- gh ---
# Bash 3.2 (macOS) has no ${var,,}.
lower() { tr '[:upper:]' '[:lower:]' <<<"$1"; }

# is_false <bool flag value>: the values gh (pflag) reads as false.
is_false() {
  case $(lower "$1") in
    false | f | 0) return 0 ;;
  esac
  return 1
}

# names_human_merge <label list>: a comma list, with \x01 for the spaces inside quotes.
names_human_merge() {
  local list=${1//$'\x01'/ } label labels
  IFS=, read -r -a labels <<<"$list"
  for label in "${labels[@]}"; do
    label=${label#"${label%%[! ]*}"}
    label=${label%"${label##*[! ]}"}
    [ "$(lower "$label")" = human-merge ] && return 0
  done
  return 1
}

# gh pr merge / gh pr close: --delete-branch, -d, -d inside a short-flag cluster.
check_gh_delete_branch() {
  local arg pending=false flags=true chars c j
  for arg in "$@"; do
    if $pending; then
      pending=false
      continue
    fi
    $flags || continue
    case "$arg" in
      --) flags=false ;;
      --delete-branch) block "deleting a branch (gh pr $sub --delete-branch)" ;;
      --delete-branch=*) is_false "${arg#*=}" || block "deleting a branch (gh pr $sub --delete-branch)" ;;
      --subject | --body | --body-file | --author-email | --match-head-commit | --comment | --repo) pending=true ;;
      --*) ;;
      -?*)
        # A value-taking letter ends the cluster: in -td the d is the subject.
        chars=${arg#-}
        for ((j = 0; j < ${#chars}; j++)); do
          c=${chars:$j:1}
          case "$c" in
            d) block "deleting a branch (gh pr $sub -d)" ;;
            t | b | F | A | c | R)
              [ $((j + 1)) -eq ${#chars} ] && pending=true
              break
              ;;
          esac
        done
        ;;
    esac
  done
}

# gh pr edit / gh issue edit: --remove-label naming human-merge.
check_gh_remove_label() {
  local arg pending="" flags=true
  for arg in "$@"; do
    if [ -n "$pending" ]; then
      [ "$pending" = label ] && names_human_merge "$arg" && block "removing the human-merge label"
      pending=""
      continue
    fi
    $flags || continue
    case "$arg" in
      --) flags=false ;;
      --remove-label) pending=label ;;
      --remove-label=*) names_human_merge "${arg#*=}" && block "removing the human-merge label" ;;
      --*=*) ;;
      --title | --body | --body-file | --base | --add-label | --add-assignee | --remove-assignee | \
        --add-reviewer | --remove-reviewer | --add-project | --remove-project | --milestone | --repo)
        pending=skip
        ;;
      --*) ;;
      -t | -b | -F | -B | -m | -R) pending=skip ;;
    esac
  done
}

# gh label delete human-merge; gh label edit human-merge --name (a rename).
check_gh_label() {
  local action=$1 arg pending=false name="" rename=false
  shift
  for arg in "$@"; do
    if $pending; then
      pending=false
      continue
    fi
    case "$arg" in
      --name | -n) rename=true pending=true ;;
      --name=* | -n?*) rename=true ;;
      --color | --description | --repo | -c | -d | -R) pending=true ;;
      -*) ;;
      *) [ -z "$name" ] && name=$arg ;;
    esac
  done
  names_human_merge "$name" || return
  [ "$action" = delete ] && block "deleting the human-merge label"
  $rename && block "renaming the human-merge label"
}

# gh repo edit --delete-branch-on-merge: GitHub would delete the head branch of every merged PR.
check_gh_repo_edit() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --delete-branch-on-merge) block "turning on branch deletion at merge" ;;
      --delete-branch-on-merge=*) is_false "${arg#*=}" || block "turning on branch deletion at merge" ;;
    esac
  done
}

# gh api: the REST and GraphQL calls that delete a branch, move develop or main, turn on
# branch deletion at merge, or remove, replace, rename or delete the human-merge label.
# A call that replaces every label is blocked even when it keeps human-merge: the hook
# cannot see the issue's labels, and `gh pr edit --add-label` does the same safely.
check_gh_api() {
  local arg pending="" method="" endpoint="" body=false fields=() field key repo='repos/[^/]+/[^/]+'
  for arg in "$@"; do
    if [ -n "$pending" ]; then
      case "$pending" in
        method) method=$arg ;;
        field) fields+=("$arg") ;;
      esac
      pending=""
      continue
    fi
    case "$arg" in
      -X | --method) pending=method ;;
      --method=*) method=${arg#*=} ;;
      -X?*) method=${arg#-X} ;;
      -f | -F | --field | --raw-field) pending=field body=true ;;
      --field=* | --raw-field=*) fields+=("${arg#*=}") body=true ;;
      -f?* | -F?*) fields+=("${arg:2}") body=true ;;
      --input) pending=skip body=true ;;
      --input=*) body=true ;;
      -H | --header | -q | --jq | -t | --template | -p | --preview | --hostname | --cache) pending=skip ;;
      -*) ;;
      *) [ -z "$endpoint" ] && endpoint=$arg ;;
    esac
  done

  # gh sends GET, or POST once a field or --input gives the request a body.
  if [ -z "$method" ]; then
    if $body; then method=POST; else method=GET; fi
  fi
  method=$(tr '[:lower:]' '[:upper:]' <<<"$method")
  endpoint=$(lower "$endpoint")
  endpoint=${endpoint#https://api.github.com}
  endpoint=${endpoint#/}
  endpoint=${endpoint%%\?*}

  if [ "$endpoint" = graphql ]; then
    case "$*" in
      *deleteRef* | *updateRefs* | *removeLabelsFromLabelable* | *clearLabelsFromLabelable* | *deleteLabel* | *updateLabel*)
        block "deleting a branch or removing a label through gh api graphql"
        ;;
    esac
    return
  fi

  local tag_ref="^$repo/git/refs/tags/" branch_ref="^$repo/git/refs/heads/" protected="^$repo/git/refs/heads/(develop|main)\$"
  local issue_labels="^$repo/issues/[0-9]+/labels\$" one_label="^$repo/issues/[0-9]+/labels/human-merge\$"
  local issue="^$repo/(issues|pulls)/[0-9]+\$" label="^$repo/labels/human-merge\$" repo_only="^$repo\$"

  [[ $method = DELETE && $endpoint =~ $branch_ref ]] && block "deleting a branch (gh api)"
  [[ $method = DELETE && $endpoint =~ $tag_ref ]] && block "deleting a tag (gh api)"
  [[ $method = PATCH && $endpoint =~ $tag_ref ]] && block "moving a tag (gh api)"
  [[ $method != GET && $endpoint =~ $protected ]] && block "moving develop or main (gh api)"
  [[ $method = DELETE && $endpoint =~ $one_label ]] && block "removing the human-merge label (gh api)"
  [[ ($method = DELETE || $method = PUT) && $endpoint =~ $issue_labels ]] &&
    block "removing or replacing every label of an issue (gh api)"
  [[ ($method = DELETE || $method = PATCH) && $endpoint =~ $label ]] &&
    block "deleting or renaming the human-merge label (gh api)"
  for field in "${fields[@]}"; do
    key=$(lower "${field%%=*}")
    [[ $method = PATCH && $endpoint =~ $issue && ($key = labels || $key = 'labels[]') ]] &&
      block "replacing every label of an issue (gh api)"
    [[ $method = PATCH && $endpoint =~ $repo_only && $key = delete_branch_on_merge ]] &&
      ! is_false "${field#*=}" && block "turning on branch deletion at merge (gh api)"
  done
  return 0
}

# gh release delete --cleanup-tag (or =true): deletes the tag too. Without it the tag stays.
check_gh_release_delete() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --) return ;;
      --cleanup-tag) block "deleting a tag (gh release delete --cleanup-tag)" ;;
      --cleanup-tag=*) is_false "${arg#*=}" || block "deleting a tag (gh release delete --cleanup-tag)" ;;
    esac
  done
}

# check_gh <args after gh>: the first two words that are not flags (or a -R value) name the
# command; gh accepts -R before or after `pr`. The rest goes to the command's check.
check_gh() {
  local args=("$@") i=0 n=$# words=() rest=() cmd sub
  # gh api has one command word; its first argument is the endpoint.
  if [ "${1:-}" = api ]; then
    check_gh_api "${@:2}"
    return
  fi
  while [ "$i" -lt "$n" ]; do
    case "${args[$i]}" in
      -R | --repo)
        [ ${#words[@]} -lt 2 ] || rest+=("${args[$i]}" "${args[$((i + 1))]:-}")
        i=$((i + 2))
        continue
        ;;
      -*) rest+=("${args[$i]}") ;;
      *)
        if [ ${#words[@]} -lt 2 ]; then words+=("${args[$i]}"); else rest+=("${args[$i]}"); fi
        ;;
    esac
    i=$((i + 1))
  done
  [ ${#words[@]} -eq 2 ] || return
  cmd="${words[0]} ${words[1]}"
  sub=${words[1]}

  case "$cmd" in
    "pr merge" | "pr close") check_gh_delete_branch "${rest[@]}" ;;
    "pr edit" | "issue edit") check_gh_remove_label "${rest[@]}" ;;
    "label delete" | "label edit") check_gh_label "${words[1]}" "${rest[@]}" ;;
    "repo edit") check_gh_repo_edit "${rest[@]}" ;;
    "release delete") check_gh_release_delete "${rest[@]}" ;;
  esac
}

# analyze_fragment <one simple command>: `git push`, `git branch` and the gh commands above
# are checked.
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
  if [ "${toks[$i]##*/}" = gh ]; then
    check_gh "${toks[@]:$((i + 1))}"
    return
  fi
  [ "${toks[$i]##*/}" = git ] || return
  i=$((i + 1))

  while [ "$i" -lt "$n" ]; do
    case "${toks[$i]}" in
      -C)
        dir=${toks[$((i + 1))]:-}
        dir=${dir//$'\x01'/ }
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

# shellcheck disable=SC2016  # the perl programs are meant to be literal
# Split a command text into simple commands. Inside quotes, ; & | ( ) ` and newlines become
# spaces and spaces become \x01, so a commit message that mentions `git push -f`, or
# `-c user.name="A B"`, stays one argument. Outside quotes they split commands.
split_commands='s/("(?:\\.|[^"\\])*"|\x27[^\x27]*\x27)/(my $q = $1) =~ tr{;&|\n()`}{       }; $q =~ s{[ \t]}{\x01}g; $q/ge;
  s/&&|\|\||[;|&\n()`]/\n/g'

# shellcheck disable=SC2016
# The command texts a shell runs from inside quotes, one per line (newlines as \x02): each
# $(...) and `...` inside double quotes and, with SCAN_ALL set (`bash -c "..."`,
# `eval "..."`), the whole content of every quoted string, one level of escapes removed.
quoted_commands='while (/"((?:\\.|[^"\\])*)"|\x27([^\x27]*)\x27/g) {
    my @out;
    if (defined $1) {
      (my $s = $1) =~ s/\\(["\\\$`])/$1/g;
      push @out, $s if $ENV{SCAN_ALL};
      while ($s =~ /\$(\((?:[^()]++|(?-1))*\))/g) { push @out, substr($1, 1, -1) }
      while ($s =~ /`([^`]*)`/g) { push @out, $1 }
    } elsif ($ENV{SCAN_ALL}) {
      push @out, $2;
    }
    for (@out) { s/\n/\x02/g; print "$_\n" }
  }'

# scan <command text> <depth>: check each simple command, then the command texts inside
# its quotes with the same quote-aware split, so a quoted value inside `bash -c "..."`
# does not hide the flags after it.
scan() {
  local frags frag all=""
  frags=$(perl -0pe "$split_commands" <<<"$1") || return 0
  while IFS= read -r frag; do
    analyze_fragment "$frag"
  done <<<"$frags"

  [ "$2" -lt 3 ] || return 0
  grep -Eq '(sh|bash|zsh|dash)[[:space:]]+-[a-zA-Z]*c|(^|[^[:alnum:]_])eval[[:space:]]' <<<"$1" && all=1
  frags=$(SCAN_ALL=$all perl -0ne "$quoted_commands" <<<"$1") || return 0
  [ -n "$frags" ] || return 0
  while IFS= read -r frag; do
    scan "${frag//$'\x02'/$'\n'}" $(($2 + 1))
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

# A heredoc with a quoted delimiter (<<'EOF') is plain text, never run, so drop its body.
# shellcheck disable=SC2016
command_text=$(perl -0pe 's/<<-?[ \t]*(["\x27])(\w+)\1([^\n]*)\n.*?\n[ \t]*\2[ \t]*(?=\n|$)/<<$1$2$1$3/gs' <<<"$command_text") || exit 0

scan "$command_text" 0

exit 0
