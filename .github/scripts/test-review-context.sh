#!/usr/bin/env bash
# Tests for review-context.sh: a fake `gh` on PATH serves fixture JSON for each API path,
# then the test checks what the script wrote.
#   bash .github/scripts/test-review-context.sh
# `check && ok || bad` is safe here: ok only counts and always succeeds.
# shellcheck disable=SC2015
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
script="$here/review-context.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL: $1"; }

repo=acme/app
pr=7
sha() { printf "$1%.0s" $(seq 40); }
head=$(sha c)
earlier=$(sha b)
lost=$(sha a)
odd=$'app/odd\nname.py'

# The fake gh: `gh api <path> [--paginate] [--jq <expr>]` prints $FIXTURES/<path with / as _>,
# and the second page in <that file>.2 only with --paginate, each page through `jq -r <expr>`
# when given. It logs each path; a path with no fixture fails.
mkdir -p "$tmp/bin"
cat >"$tmp/bin/gh" <<'EOF'
#!/usr/bin/env bash
[ "$1" = api ] || exit 9
path=$2
shift 2
expr="" paginate=""
while [ $# -gt 0 ]; do
  case $1 in
    --jq) expr=$2; shift 2 ;;
    --paginate) paginate=1; shift ;;
    *) shift ;;
  esac
done
echo "$path" >>"$FIXTURES/calls.log"
file="$FIXTURES/$(printf '%s' "$path" | tr '/' '_')"
[ -f "$file" ] || { echo "no fixture for $path" >&2; exit 1; }
pages=("$file")
if [ -n "$paginate" ] && [ -f "$file.2" ]; then pages+=("$file.2"); fi
for page in "${pages[@]}"; do
  if [ -n "$expr" ]; then jq -r "$expr" "$page"; else cat "$page"; fi
done
EOF
chmod +x "$tmp/bin/gh"

# fixture <case dir> <api path>[.2] <json>
fixture() { printf '%s' "$3" >"$1/$(printf '%s' "$2" | tr '/' '_')"; }
# comment <author> <body>: one issue comment as JSON.
comment() { jq -n --arg u "$1" --arg b "$2" '{user: {login: $u}, body: $b}'; }
# review <sha>: a review comment body as the post job writes it, with commands that must
# never run.
# shellcheck disable=SC2016
review() {
  printf '## Claude review · %s\n\n### 1. Correctness\n- app/main.py:1 returns old. %s %s\n\n<!-- claude-review -->\n' \
    "$1" '$(touch PWNED)' '`touch PWNED`'
}

# setup <case> <comments JSON array>: the PR has app/main.py, README.md and an odd file name;
# at the earlier review it also had tests/test_main.py. Since then: main.py changed, the test
# was deleted, the odd file was added, and develop/only.py came in from develop.
setup() {
  local d="$tmp/$1"
  mkdir -p "$d"
  fixture "$d" "repos/$repo/issues/$pr/comments" "$2"
  fixture "$d" "repos/$repo/pulls/$pr" "{\"head\":{\"sha\":\"$head\"},\"base\":{\"ref\":\"develop\"},\"changed_files\":3}"
  fixture "$d" "repos/$repo/pulls/$pr/commits" "[{\"sha\":\"$(sha d)\"}]"
  fixture "$d" "repos/$repo/pulls/$pr/commits.2" "[{\"sha\":\"$earlier\"},{\"sha\":\"$head\"}]"
  fixture "$d" "repos/$repo/pulls/$pr/files" '[{"filename":"app/main.py"},{"filename":"README.md"}]'
  fixture "$d" "repos/$repo/pulls/$pr/files.2" "$(jq -n --arg f "$odd" '[{filename: $f}]')"
  fixture "$d" "repos/$repo/compare/develop...$earlier" \
    '{"files":[{"filename":"app/main.py"},{"filename":"tests/test_main.py"}]}'
  fixture "$d" "repos/$repo/compare/$earlier...$head" "$(jq -n --arg f "$odd" '{
    total_commits: 1, commits: [{parents: [{}]}],
    files: [
      {filename: "app/main.py", status: "modified", patch: "@@ -1 +1 @@\n-old\n+new"},
      {filename: "develop/only.py", status: "added", patch: "@@ -0,0 +1 @@\n+from develop"},
      {filename: "tests/test_main.py", status: "removed", patch: "@@ -1 +0,0 @@\n-def test(): pass"},
      {filename: $f, status: "added", patch: "@@ -0,0 +1 @@\n+odd"}]}')"
  printf '%s' "$d"
}

# run <case dir>: runs the script with the fake gh from <case dir>, so a command run by
# mistake leaves its file there. The context goes to <case dir>/ctx, the exit code to $code.
run() {
  code=0
  (cd "$1" && FIXTURES=$1 PATH="$tmp/bin:$PATH" bash "$script" "$repo" "$pr" "$1/ctx" >"$1/out.txt" 2>&1) || code=$?
}

# --- no earlier review ---
d=$(setup none "[$(comment someone "$(review "${earlier:0:7}")")]")
run "$d"
[ "$code" -eq 0 ] && ok || bad "a marked comment by someone else: exit 0"
[ ! -e "$d/ctx" ] && ok || bad "a marked comment by someone else: nothing written"
[ "$(cat "$d/calls.log")" = "repos/$repo/issues/$pr/comments" ] && ok || bad "no review: only the comments call"

d=$(setup empty "[]")
run "$d"
[ ! -e "$d/ctx" ] && ok || bad "no comments: nothing written"

# --- an earlier review ---
# The security scan posts as the same account with its own marker; a second marked comment
# (which the post job never makes) must not win over the first.
scan="## Claude security scan · ${lost:0:7}

<!-- claude-security-scan -->"
d=$(setup earlier "[$(comment 'github-actions[bot]' "$scan"),$(comment someone "looks good")]")
fixture "$d" "repos/$repo/issues/$pr/comments.2" \
  "[$(comment 'github-actions[bot]' "$(review "${earlier:0:7}")"),$(comment 'github-actions[bot]' "$(review "${lost:0:7}")")]"
run "$d"
[ "$code" -eq 0 ] && ok || bad "earlier review: exit 0"
grep -qsx "repos/$repo/compare/$earlier...$head" "$d/calls.log" && ok || bad "earlier review: compare from the full earlier SHA"
grep -qs "returns old" "$d/ctx/earlier-review.md" && ok || bad "earlier review: review written"
! grep -qs "security scan" "$d/ctx/earlier-review.md" && ok || bad "earlier review: the scan comment is not the review"
grep -qs "^## Claude review · ${earlier:0:7}$" "$d/ctx/earlier-review.md" && ok || bad "earlier review: the first marked comment wins"
! grep -qs "claude-review -->" "$d/ctx/earlier-review.md" && ok || bad "earlier review: marker removed"
[ ! -e "$d/PWNED" ] && grep -qsF "\$(touch PWNED)" "$d/ctx/earlier-review.md" && ok || bad "earlier review: body not run"
grep -qsx "diff --git a/app/main.py b/app/main.py" "$d/ctx/changes.diff" && grep -qsx "+new" "$d/ctx/changes.diff" &&
  ok || bad "earlier review: PR file in the diff"
grep -qsx "status: removed" "$d/ctx/changes.diff" && grep -qsx -- "-def test(): pass" "$d/ctx/changes.diff" &&
  ok || bad "earlier review: a file the PR changed then and deleted since is kept"
grep -qsx "+odd" "$d/ctx/changes.diff" && ok || bad "earlier review: a file name with a newline is kept"
grep -qsx "earlier: $earlier" "$d/ctx/meta.txt" && grep -qsx "head: $head" "$d/ctx/meta.txt" &&
  ok || bad "earlier review: meta names both SHAs"
grep -qsx "develop merged in since the earlier review: no" "$d/ctx/meta.txt" && ok || bad "earlier review: no merge"

# --- a file outside the PR is left out ---
! grep -qs "develop/only.py" "$d/ctx/changes.diff" && ok || bad "outside file: not in the diff"

# --- develop merged in between ---
d=$(setup merged "[$(comment 'github-actions[bot]' "$(review "${earlier:0:7}")")]")
fixture "$d" "repos/$repo/compare/$earlier...$head" \
  '{"total_commits":2,"commits":[{"parents":[{}]},{"parents":[{},{}]}],"files":[]}'
run "$d"
grep -qsx "develop merged in since the earlier review: yes" "$d/ctx/meta.txt" && ok || bad "merge: meta says so"

# --- a lost SHA (force-pushed away), and a prefix two commits share ---
d=$(setup lost "[$(comment 'github-actions[bot]' "$(review "${lost:0:7}")")]")
run "$d"
[ "$code" -eq 0 ] && [ ! -e "$d/ctx" ] && ok || bad "lost SHA: exit 0, nothing written"
! grep -qs compare "$d/calls.log" && ok || bad "lost SHA: no compare call"

d=$(setup ambiguous "[$(comment 'github-actions[bot]' "$(review "${earlier:0:7}")")]")
fixture "$d" "repos/$repo/pulls/$pr/commits.2" "[{\"sha\":\"$earlier\"},{\"sha\":\"${earlier:0:39}e\"},{\"sha\":\"$head\"}]"
run "$d"
[ "$code" -eq 0 ] && [ ! -e "$d/ctx" ] && ! grep -qs compare "$d/calls.log" && ok || bad "ambiguous prefix: full review"

# --- a review of the head itself: the earlier findings are still checked ---
d=$(setup same "[$(comment 'github-actions[bot]' "$(review "${head:0:9}")")]")
fixture "$d" "repos/$repo/compare/develop...$head" '{"files":[{"filename":"app/main.py"}]}'
fixture "$d" "repos/$repo/compare/$head...$head" '{"status":"identical","total_commits":0,"commits":[],"files":[]}'
run "$d"
[ "$code" -eq 0 ] && grep -qs "returns old" "$d/ctx/earlier-review.md" && [ ! -s "$d/ctx/changes.diff" ] &&
  ok || bad "same head: context with an empty diff"

# --- a heading that is not exactly the one /run-tasks reads never reaches an API path ---
n=0
for heading in "${earlier:0:7}; touch PWNED" "${earlier:0:6}" "../../x" "${earlier:0:7} extra" \
  "${earlier:0:7} " "${earlier:0:7}"$'\r'; do
  n=$((n + 1))
  d=$(setup "heading$n" "[$(comment 'github-actions[bot]' "## Claude review · $heading
<!-- claude-review -->")]")
  run "$d"
  [ "$code" -eq 0 ] && [ ! -e "$d/ctx" ] && [ ! -e "$d/PWNED" ] && ok || bad "heading $n: full review"
  [ "$(cat "$d/calls.log")" = "repos/$repo/issues/$pr/comments" ] && ok || bad "heading $n: no other call"
done

# --- more files than the API lists ---
d=$(setup cap "[$(comment 'github-actions[bot]' "$(review "${earlier:0:7}")")]")
fixture "$d" "repos/$repo/compare/$earlier...$head" "$(jq -n '{files: [range(300) | {filename: "f\(.)"}]}')"
run "$d"
[ "$code" -eq 0 ] && [ ! -e "$d/ctx" ] && ok || bad "300 files compared: full review"

d=$(setup listed "[$(comment 'github-actions[bot]' "$(review "${earlier:0:7}")")]")
fixture "$d" "repos/$repo/pulls/$pr" "{\"head\":{\"sha\":\"$head\"},\"base\":{\"ref\":\"develop\"},\"changed_files\":4}"
run "$d"
[ "$code" -eq 0 ] && [ ! -e "$d/ctx" ] && ok || bad "fewer PR files listed than changed: full review"

# --- an existing out dir is never touched ---
d=$(setup existing "[$(comment 'github-actions[bot]' "$(review "${earlier:0:7}")")]")
mkdir -p "$d/ctx" && echo keep >"$d/ctx/keep.txt"
run "$d"
[ "$code" -eq 2 ] && [ "$(cat "$d/ctx/keep.txt")" = keep ] && [ ! -e "$d/calls.log" ] &&
  ok || bad "existing out dir: exit 2, left as is"

# --- an API error writes nothing and fails ---
d=$(setup error "[$(comment 'github-actions[bot]' "$(review "${earlier:0:7}")")]")
rm "$d/repos_acme_app_compare_${earlier}...${head}"
run "$d"
[ "$code" -ne 0 ] && [ ! -e "$d/ctx" ] && ok || bad "API error: non-zero exit, nothing written"

# --- usage ---
code=0
bash "$script" >/dev/null 2>&1 || code=$?
[ "$code" -eq 2 ] && ok || bad "usage: no arguments exit 2"
code=0
bash "$script" "acme/app" "7; x" "$tmp/x" >/dev/null 2>&1 || code=$?
[ "$code" -eq 2 ] && ok || bad "usage: bad PR number exit 2"

# --- the script finds the comment by the same filter the post job edits it by ---
filter=$(grep -o 'select(.user.login == "github-actions\[bot\]".*\$")))' "$script")
[ -n "$filter" ] && grep -qsF "$filter" "$here/../workflows/claude-review.yml" &&
  ok || bad "the comment filter matches the post job's"

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
