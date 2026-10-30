#!/usr/bin/env bash
# The checks are single-quoted on purpose: ok() evaluates them after the case runs, so the
# variables they read look unused to shellcheck.
# shellcheck disable=SC2016,SC2034
# Tests for review-context.sh: a fake `gh` on PATH serves fixture JSON for each API path,
# then the test checks what the script wrote.
#   bash .github/scripts/test-review-context.sh
set -uo pipefail

script="$(cd "$(dirname "$0")" && pwd)/review-context.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0

repo=acme/app
pr=7
head=$(printf 'c%.0s' $(seq 40))
earlier=$(printf 'b%.0s' $(seq 40))
lost=$(printf 'a%.0s' $(seq 40))

# The fake gh: `gh api <path> [--paginate] [--jq <expr>]` prints $FIXTURES/<path with / as _>,
# through `jq -r <expr>` when given, and logs each path. A path with no fixture fails.
mkdir -p "$tmp/bin"
cat >"$tmp/bin/gh" <<'EOF'
#!/usr/bin/env bash
[ "$1" = api ] || exit 9
path=$2
shift 2
expr=""
while [ $# -gt 0 ]; do
  case $1 in
    --jq) expr=$2; shift 2 ;;
    *) shift ;;
  esac
done
echo "$path" >>"$FIXTURES/calls.log"
file="$FIXTURES/$(printf '%s' "$path" | tr '/' '_')"
[ -f "$file" ] || { echo "no fixture for $path" >&2; exit 1; }
if [ -n "$expr" ]; then jq -r "$expr" "$file"; else cat "$file"; fi
EOF
chmod +x "$tmp/bin/gh"

# comment <author> <body>: one issue comment as JSON.
comment() { jq -n --arg u "$1" --arg b "$2" '{user: {login: $u}, body: $b}'; }

# setup <case> <comments JSON array>: the fixtures every case shares; the PR has two files.
setup() {
  local d="$tmp/$1"
  mkdir -p "$d"
  printf '{"head":{"sha":"%s"}}' "$head" >"$d/repos_${repo/\//_}_pulls_$pr"
  printf '%s' "$2" >"$d/repos_${repo/\//_}_issues_${pr}_comments"
  printf '[{"sha":"%s"},{"sha":"%s"}]' "$earlier" "$head" >"$d/repos_${repo/\//_}_pulls_${pr}_commits"
  printf '[{"filename":"app/main.py"},{"filename":"README.md"}]' >"$d/repos_${repo/\//_}_pulls_${pr}_files"
  # Since the earlier commit: a PR file and a file that came in with develop.
  cat >"$d/repos_${repo/\//_}_compare_${earlier}...${head}" <<'EOF'
{"files": [
  {"filename": "app/main.py", "status": "modified", "patch": "@@ -1 +1 @@\n-old\n+new"},
  {"filename": "develop/only.py", "status": "added", "patch": "@@ -0,0 +1 @@\n+from develop"}
]}
EOF
  printf '%s' "$d"
}

# run <case dir>: runs the script with the fake gh from <case dir>, so a command run by
# mistake leaves its file there; the context goes to <case dir>/ctx, the exit code to $code.
code=0
run() {
  code=0
  (cd "$1" && FIXTURES=$1 PATH="$tmp/bin:$PATH" bash "$script" "$repo" "$pr" "$1/ctx" >"$1/out.txt" 2>&1) || code=$?
}

ok() {
  if eval "$2"; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    echo "FAIL ($1): $2"
  fi
}

review="## Claude review · ${earlier:0:7}

### 1. Correctness
- app/main.py:1 returns old. \$(touch PWNED) \`touch PWNED\`

<!-- claude-review -->"

# --- no earlier review ---
d=$(setup none "[$(comment someone "## Claude review · ${earlier:0:7}
<!-- claude-review -->")]")
run "$d"
ok "no review: exit 0" '[ $code -eq 0 ]'
ok "no review: nothing written" '[ ! -e "$d/ctx" ]'
ok "no review: no compare call" '! grep -q compare "$d/calls.log"'

d=$(setup empty "[]")
run "$d"
ok "no comments: nothing written" '[ ! -e "$d/ctx" ]'

# --- an earlier review ---
d=$(setup earlier "[$(comment someone "looks good"),$(comment 'github-actions[bot]' "$review")]")
run "$d"
ok "earlier review: exit 0" '[ $code -eq 0 ]'
ok "earlier review: compare from the full earlier SHA" 'grep -qx "repos/acme/app/compare/$earlier...$head" "$d/calls.log"'
ok "earlier review: review written" 'grep -q "returns old" "$d/ctx/earlier-review.md"'
ok "earlier review: marker removed" '! grep -q "claude-review -->" "$d/ctx/earlier-review.md"'
ok "earlier review: body not run" '[ ! -e "$d/PWNED" ] && grep -qF "\$(touch PWNED)" "$d/ctx/earlier-review.md"'
ok "earlier review: PR file in the diff" 'grep -qx "diff --git a/app/main.py b/app/main.py" "$d/ctx/changes.diff" && grep -qx "+new" "$d/ctx/changes.diff"'
ok "earlier review: meta names both SHAs" 'grep -qx "earlier: $earlier" "$d/ctx/meta.txt" && grep -qx "head: $head" "$d/ctx/meta.txt"'

# --- a file outside the PR is left out ---
ok "outside file: not in the diff" '! grep -q "develop/only.py" "$d/ctx/changes.diff"'
ok "outside file: not in meta" '! grep -q "develop/only.py" "$d/ctx/meta.txt"'

# --- a lost SHA (force-pushed away) ---
d=$(setup lost "[$(comment 'github-actions[bot]' "${review//${earlier:0:7}/${lost:0:7}}")]")
run "$d"
ok "lost SHA: exit 0" '[ $code -eq 0 ]'
ok "lost SHA: nothing written" '[ ! -e "$d/ctx" ]'
ok "lost SHA: no compare call" '! grep -q compare "$d/calls.log"'

# --- a review of the head itself ---
d=$(setup same "[$(comment 'github-actions[bot]' "${review//${earlier:0:7}/${head:0:9}}")]")
run "$d"
ok "same head: nothing written" '[ ! -e "$d/ctx" ]'

# --- a heading that is not a strict SHA never reaches an API path ---
for bad in "${earlier:0:7}; touch PWNED" "${earlier:0:6}" "../../x" "${earlier:0:7} extra"; do
  d=$(setup "bad$((pass + fail))" "[$(comment 'github-actions[bot]' "## Claude review · $bad
<!-- claude-review -->")]")
  run "$d"
  ok "bad heading '$bad': nothing written" '[ ! -e "$d/ctx" ] && [ ! -e "$d/PWNED" ]'
  ok "bad heading '$bad': no commits or compare call" '! grep -qE "commits|compare" "$d/calls.log"'
done

# --- a stale context is removed ---
d=$(setup stale "[]")
mkdir -p "$d/ctx" && echo old >"$d/ctx/meta.txt"
run "$d"
ok "stale context: removed" '[ ! -e "$d/ctx" ]'

# --- an API error writes nothing and fails ---
d=$(setup error "[$(comment 'github-actions[bot]' "$review")]")
rm "$d/repos_acme_app_compare_${earlier}...${head}"
run "$d"
ok "API error: non-zero exit" '[ $code -ne 0 ]'
ok "API error: nothing written" '[ ! -e "$d/ctx" ]'

# --- usage ---
code=0
bash "$script" >/dev/null 2>&1 || code=$?
ok "usage: no arguments exit 2" '[ $code -eq 2 ]'
code=0
bash "$script" "acme/app" "7; x" "$tmp/x" >/dev/null 2>&1 || code=$?
ok "usage: bad PR number exit 2" '[ $code -eq 2 ]'

echo "$pass passed, $fail failed"
[ $fail -eq 0 ]
