#!/usr/bin/env bash
# Writes what a second claude-review needs to look only at what changed since the first
# (plan 038, assumption 6). Runs no model and needs only a token that reads the PR; on a
# public repository that also covers the compare calls.
#   bash .github/scripts/review-context.sh <owner/repo> <pr number> <out dir>
#
# When the PR's claude-review comment is for a commit still in the PR's history, <out dir> gets:
#   earlier-review.md  the earlier review, without its marker
#   changes.diff       the changes from that commit to the head, in the files the PR changes now
#                      or changed then (develop's other files are left out)
#   meta.txt           both commits, and whether the base branch was merged in between
# Otherwise nothing is written, and the review is the full one; the same when the API lists
# fewer files than changed. On an API error the script exits non-zero and writes nothing.
#
# The comment body is untrusted text: it is never evaluated, and only a strict hex SHA from
# its first line, matched to one of the PR's commits, reaches an API path. File names from the
# API only go into file contents.
set -euo pipefail

if [ $# -ne 3 ]; then
  echo "usage: review-context.sh <owner/repo> <pr number> <out dir>" >&2
  exit 2
fi
repo=$1 pr=$2 out=$3
if ! [[ $repo =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || ! [[ $pr =~ ^[0-9]+$ ]]; then
  echo "review-context.sh: bad repository or PR number" >&2
  exit 2
fi
if [ -e "$out" ]; then
  echo "review-context.sh: $out already exists" >&2
  exit 2
fi

# The one comment the post job of claude-review.yml writes and edits, found by its filter
# (test-review-context.sh checks they match). Each body is JSON-encoded to stay on one line.
body=$(gh api "repos/$repo/issues/$pr/comments" --paginate \
  --jq '.[] | select(.user.login == "github-actions[bot]" and (.body | test("<!-- claude-review -->\\s*$"))) | .body | @json' |
  awk 'NR==1' | jq -r '.')
if [ -z "$body" ]; then
  echo "No earlier claude-review: full review."
  exit 0
fi

# The heading as the /run-tasks review watch reads it.
pattern='^## Claude review · ([0-9a-f]{7,40})$'
if ! [[ ${body%%$'\n'*} =~ $pattern ]]; then
  echo "The earlier review has no SHA heading: full review."
  exit 0
fi
short=${BASH_REMATCH[1]}

pull=$(gh api "repos/$repo/pulls/$pr")
head=$(jq -r '.head.sha' <<<"$pull")
base=$(jq -r '.base.ref' <<<"$pull")
changed=$(jq -r '.changed_files' <<<"$pull")
if ! [[ $head =~ ^[0-9a-f]{40}$ && $base =~ ^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$ && $changed =~ ^[0-9]+$ ]] ||
  [[ $base == *..* ]]; then
  echo "review-context.sh: unexpected PR data" >&2
  exit 1
fi

# The earlier commit must be exactly one of the PR's commits; after a force-push it is none.
earlier=$(gh api "repos/$repo/pulls/$pr/commits" --paginate --jq '.[].sha' |
  awk -v p="$short" 'index($0, p) == 1')
if ! [[ $earlier =~ ^[0-9a-f]{40}$ ]]; then
  echo "The earlier review's commit $short is not one of the PR's commits: full review."
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# The PR's files now, its files at the earlier review (a file it reverted or deleted since is
# only there), and the changes since. File names stay JSON, so any name survives.
gh api "repos/$repo/pulls/$pr/files" --paginate --jq '[.[].filename]' | jq -s 'add // []' >"$tmp/now.json"
gh api "repos/$repo/compare/$base...$earlier" >"$tmp/then.json"
gh api "repos/$repo/compare/$earlier...$head" >"$tmp/since.json"

# The API lists at most 3000 files of a PR and 300 of a comparison, without saying so.
if [ "$(jq 'length' "$tmp/now.json")" -lt "$changed" ] ||
  [ "$(jq '.files // [] | length' "$tmp/then.json")" -ge 300 ] ||
  [ "$(jq '.files // [] | length' "$tmp/since.json")" -ge 300 ]; then
  echo "More changed files than the API lists: full review."
  exit 0
fi

jq -s '.[0] + (.[1].files // [] | map(.filename)) | unique' "$tmp/now.json" "$tmp/then.json" >"$tmp/keep.json"
mkdir "$tmp/out"
jq -r --slurpfile keep "$tmp/keep.json" '
  .files // [] | .[] | select(.filename | IN($keep[0][])) |
  "diff --git a/\(.previous_filename // .filename) b/\(.filename)\nstatus: \(.status)\n" +
  (.patch // "(no patch: binary, too large, or a rename only)") + "\n"
' "$tmp/since.json" >"$tmp/out/changes.diff"
# A merge commit in between (or more commits than the API lists) can bring the base branch's
# hunks into the files kept above.
merged=$(jq -r '(.commits // []) as $c |
  if ($c | any(.parents | length > 1)) or ((.total_commits // 0) > ($c | length)) then "yes" else "no" end' \
  "$tmp/since.json")

printf '%s\n' "$body" | sed '/<!-- claude-review -->[[:space:]]*$/d' >"$tmp/out/earlier-review.md"
{
  echo "earlier: $earlier"
  echo "head: $head"
  echo "$base merged in since the earlier review: $merged"
} >"$tmp/out/meta.txt"
mkdir -p "$(dirname "$out")"
mv "$tmp/out" "$out"
echo "Wrote the context for a review of the changes since $short."
