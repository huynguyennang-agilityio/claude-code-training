#!/usr/bin/env bash
# Tests for format-on-edit.sh: feed each file to the hook as the JSON that Claude Code
# sends, in a throwaway project folder, and check the file and the exit code.
#   bash .claude/hooks/test-format-on-edit.sh
# Cases that need ruff or dart print SKIPPED when the tool is not installed.
set -uo pipefail

repo="$(cd "$(dirname "$0")/../.." && pwd)"
hook="$repo/.claude/hooks/format-on-edit.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

proj="$tmp/proj"
mkdir -p "$proj/backend/app" "$proj/backend/.venv/lib" "$proj/backend/.venv/bin" \
  "$proj/mobile/lib/core" "$proj/mobile/test" "$proj/mobile/ios" "$proj/docs" "$proj/tools"
# `exclude = []` turns off ruff's own default exclusion of .venv, so the .venv case below
# can only pass because of the hook's guard.
printf '[tool.ruff]\nline-length = 100\nexclude = []\n\n[tool.ruff.format]\nquote-style = "double"\n' \
  >"$proj/backend/pyproject.toml"

ruff=""
if [ -x "$repo/backend/.venv/bin/ruff" ]; then ruff="$repo/backend/.venv/bin/ruff"; else ruff=$(command -v ruff || true); fi
[ -n "$ruff" ] && ln -s "$ruff" "$proj/backend/.venv/bin/ruff"
have_dart=false
command -v dart >/dev/null 2>&1 && have_dart=true

pass=0
fail=0
skipped=0

ok() { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL: $1"; }

# run_hook <path>: send the hook the Edit/Write JSON for that path, return its exit code.
run_hook() {
  local input
  input=$(jq -n --arg p "$1" '{tool_name: "Write", tool_input: {file_path: $p}}')
  CLAUDE_PROJECT_DIR="$proj" "$hook" <<<"$input" >/dev/null 2>&1
}

# make <relative path> <content>: write a file in the project and return its path.
make() {
  mkdir -p "$(dirname "$proj/$1")"
  printf '%s\n' "$2" >"$proj/$1"
  echo "$proj/$1"
}

# unchanged <label> <path>: the hook exits 0 and leaves the file as it was.
unchanged() {
  local before after
  before=$(cksum <"$2")
  run_hook "$2" || { bad "$1: exit code was not 0"; return; }
  after=$(cksum <"$2")
  if [ "$before" = "$after" ]; then ok; else bad "$1: the file changed"; fi
}

UGLY_PY="x = {  'a':1 }"
UGLY_DART="void main(){print( 'hi' );}"

# --- Python ---
if [ -n "$ruff" ]; then
  f=$(make backend/app/ugly.py "$UGLY_PY")
  run_hook "$f" || bad "python: exit code was not 0"
  if "$ruff" format --check --quiet --config "$proj/backend/pyproject.toml" "$f" &&
    [ "$(cat "$f")" = 'x = {"a": 1}' ]; then ok; else bad "python: unformatted file was not formatted"; fi

  f=$(make backend/app/clean.py 'x = {"a": 1}')
  unchanged "python: formatted file" "$f"

  f="$proj/backend/app/../app/dots.py"
  make backend/app/dots.py "$UGLY_PY" >/dev/null
  run_hook "$f" || bad "python with ..: exit code was not 0"
  if [ "$(cat "$proj/backend/app/dots.py")" = 'x = {"a": 1}' ]; then ok; else bad "python with ..: not formatted"; fi

  f=$(make backend/app/broken.py 'def f(:')
  unchanged "python: syntax error" "$f"
  f=$(make backend/.venv/lib/vendored.py "$UGLY_PY")
  unchanged "python: backend/.venv" "$f"

  # A symlink inside the project that points outside it: the target must stay as it is.
  mkdir -p "$tmp/outside"
  printf '%s\n' "$UGLY_PY" >"$tmp/outside/victim.py"
  ln -s "$tmp/outside/victim.py" "$proj/backend/app/link.py"
  unchanged "python: symlink to a file outside the project" "$proj/backend/app/link.py"
  if [ "$(cat "$tmp/outside/victim.py")" = "$UGLY_PY" ]; then ok; else bad "python: the symlink target was formatted"; fi
else
  echo "SKIPPED: python cases (ruff not installed)"
  skipped=$((skipped + 1))
fi
f=$(make tools/script.py "$UGLY_PY")
unchanged "python outside backend/" "$f"

# --- Dart ---
if $have_dart; then
  f=$(make mobile/lib/core/ugly.dart "$UGLY_DART")
  run_hook "$f" || bad "dart: exit code was not 0"
  if (cd "$proj/mobile" && dart format --output=none --set-exit-if-changed "$f" >/dev/null 2>&1) &&
    [ "$(cat "$f")" != "$UGLY_DART" ]; then ok; else bad "dart: unformatted file was not formatted"; fi

  f=$(make mobile/test/ugly_test.dart "$UGLY_DART")
  run_hook "$f" || bad "dart test file: exit code was not 0"
  if (cd "$proj/mobile" && dart format --output=none --set-exit-if-changed "$f" >/dev/null 2>&1); then ok; else bad "dart test file: not formatted"; fi

  f=$(make mobile/lib/core/clean.dart $'void main() {\n  print(\'hi\');\n}')
  unchanged "dart: formatted file" "$f"
else
  echo "SKIPPED: dart cases (dart not installed)"
  skipped=$((skipped + 1))
fi
for name in model.g.dart model.freezed.dart injection.config.dart; do
  f=$(make "mobile/lib/core/$name" "$UGLY_DART")
  unchanged "generated dart $name" "$f"
done
f=$(make mobile/ios/Runner.dart "$UGLY_DART")
unchanged "dart under mobile/ios" "$f"

# --- everything else ---
f=$(make docs/notes.md '#  title  ')
unchanged "markdown file" "$f"
f=$(make backend/app/notes.txt "$UGLY_PY")
unchanged "text file in backend/" "$f"

outside="$tmp/outside/other.py"
mkdir -p "$tmp/outside"
printf '%s\n' "$UGLY_PY" >"$outside"
unchanged "file outside the project" "$outside"

# --- input the hook cannot use ---
if run_hook "$proj/backend/app/missing.py"; then ok; else bad "missing file: exit code was not 0"; fi
for raw in '' 'not json' '{}' '{"tool_input":{}}'; do
  if CLAUDE_PROJECT_DIR="$proj" "$hook" <<<"$raw" >/dev/null 2>&1; then ok; else bad "input '$raw': exit code was not 0"; fi
done

echo "$pass passed, $fail failed, $skipped skipped"
[ $fail -eq 0 ]
