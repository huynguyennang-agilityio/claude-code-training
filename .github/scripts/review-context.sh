#!/usr/bin/env bash
# Writes what a second claude-review needs to look only at what changed since the first
# (plan 038, assumption 6). Runs no model and needs only a token that reads the PR.
#   bash .github/scripts/review-context.sh <owner/repo> <pr number> <out dir>
#
# With an earlier review whose commit is still in the PR's history, <out dir> gets:
#   earlier-review.md  the earlier review, without its marker
#   changes.diff       the changes from that commit to the head, in the PR's own files only
#   meta.txt           the earlier commit, the head commit and the changed files
# Otherwise <out dir> is left out, and the review is the full one. On an API error the script
# exits non-zero and writes nothing.
#
# The comment body is untrusted text: it is never evaluated, and only a strict hex SHA from
# its first line reaches an API path. File names from the API only go into file contents.
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

# A context left by an earlier call never survives into this one.
rm -rf "$out"

head=$(gh api "repos/$repo/pulls/$pr" --jq '.head.sha')
if ! [[ $head =~ ^[0-9a-f]{40}$ ]]; then
  echo "review-context.sh: unexpected head SHA" >&2
  exit 1
fi

# The one comment the post job of claude-review.yml writes and edits: by github-actions[bot],
# ending with the marker. Each body is JSON-encoded so it stays on one line.
body=$(gh api "repos/$repo/issues/$pr/comments" --paginate \
  --jq '.[] | select(.user.login == "github-actions[bot]" and (.body | test("<!-- claude-review -->\\s*$"))) | .body | @json' |
  awk 'NR==1' | jq -r '.')
if [ -z "$body" ]; then
  echo "No earlier claude-review: full review."
  exit 0
fi

first=${body%%$'\n'*}
first=${first%$'\r'}
pattern='^## Claude review · ([0-9a-f]{7,40})[[:space:]]*$'
if ! [[ $first =~ $pattern ]]; then
  echo "The earlier review has no SHA heading: full review."
  exit 0
fi
short=${BASH_REMATCH[1]}
if [[ $head == "$short"* ]]; then
  echo "The earlier review is of the head itself: full review."
  exit 0
fi

# The earlier commit must still be one of the PR's commits; after a force-push it is not.
earlier=$(gh api "repos/$repo/pulls/$pr/commits" --paginate --jq '.[].sha' |
  awk -v p="$short" 'index($0, p) == 1')
if [ -z "$earlier" ] || [ "$(printf '%s\n' "$earlier" | awk 'END { print NR }')" != 1 ]; then
  echo "The earlier review's commit $short is not in the PR's history: full review."
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

gh api "repos/$repo/pulls/$pr/files" --paginate --jq '.[].filename' >"$tmp/pr-files.txt"
gh api "repos/$repo/compare/$earlier...$head" >"$tmp/compare.json"

# Only the PR's own files: after develop is merged in, the compare also holds develop's.
jq -R -s 'split("\n") | map(select(length > 0))' "$tmp/pr-files.txt" >"$tmp/pr-files.json"
jq -r --slurpfile keep "$tmp/pr-files.json" '
  .files // [] | .[] | select(.filename as $f | any($keep[0][]; . == $f)) |
  "diff --git a/\(.previous_filename // .filename) b/\(.filename)\n" +
  "status: \(.status)\n" +
  (if .patch then .patch + "\n" else "(no patch: binary or too large)\n" end)
' "$tmp/compare.json" >"$tmp/changes.diff"
jq -r --slurpfile keep "$tmp/pr-files.json" \
  '.files // [] | .[] | select(.filename as $f | any($keep[0][]; . == $f)) | .filename' \
  "$tmp/compare.json" >"$tmp/changed-files.txt"

mkdir -p "$tmp/out"
printf '%s\n' "$body" | sed '/<!-- claude-review -->[[:space:]]*$/d' >"$tmp/out/earlier-review.md"
mv "$tmp/changes.diff" "$tmp/out/changes.diff"
{
  echo "earlier: $earlier"
  echo "head: $head"
  echo "files changed since the earlier review (the PR's own files only):"
  sed 's/^/  /' "$tmp/changed-files.txt"
} >"$tmp/out/meta.txt"
mkdir -p "$(dirname "$out")"
mv "$tmp/out" "$out"
echo "Wrote the context for a review of the changes since $short."
