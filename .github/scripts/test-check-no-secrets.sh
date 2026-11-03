#!/usr/bin/env bash
# Tests for check-no-secrets.sh: write a file, run the check on it, and compare the exit
# code and what it printed.
#   bash .github/scripts/test-check-no-secrets.sh
set -uo pipefail

script="$(cd "$(dirname "$0")" && pwd)/check-no-secrets.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0

# The token-shaped samples are built at run time, so this file never holds one and a
# review of it cannot quote one.
repeat() { printf "%${2}s" "" | tr ' ' "$1"; }
gh_token="gh""p_$(repeat a 36)"
gh_pat="github""_pat_$(repeat b 30)"
ant_key="sk-""ant-$(repeat c 20)"
jwt="ey""J$(repeat d 10).ey""J$(repeat e 10).$(repeat f 10)"
secret="s3cr3t-value-1234"

# check <exit code> <name> <content> [ENV_NAME...]; the named variables come from the
# caller's environment. The output must never hold a sample value.
check() {
  local expect=$1 name=$2 content=$3 out code
  shift 3
  printf '%s' "$content" >"$tmp/file"
  out=$("$script" "$tmp/file" "$@" 2>&1)
  code=$?
  local leaked=""
  for v in "$secret" "$gh_token" "$gh_pat" "$ant_key" "$jwt" "${SHORT-}"; do
    if [ -n "$v" ] && [[ $out == *"$v"* ]]; then leaked=$v; fi
  done
  if [ $code -eq "$expect" ] && [ -z "$leaked" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL ($name): expected exit $expect, got $code${leaked:+, printed a value}"
  fi
}

export SECRET=$secret

# --- named variables ---
check 1 "raw value" "review text $secret more text" SECRET
check 0 "value of a variable not named" "review text $secret" OTHER
check 0 "unset variable" "clean review" UNSET_VARIABLE
for prefix in "" "x" "xy" "xyz" "abcd"; do
  encoded=$(printf '%s%s tail' "$prefix" "$secret" | base64 | tr -d '\n')
  check 1 "base64 value after '$prefix'" "blob: $encoded" SECRET
done
SHORT=abc1234 check 0 "7-character value is skipped" "abc1234 appears here" SHORT
SHORT=abc12345 check 1 "8-character value is checked" "abc12345 appears here" SHORT

# --- token shapes ---
check 1 "GitHub token" "token $gh_token here"
check 1 "GitHub fine-grained token" "token $gh_pat here"
check 1 "Anthropic key" "key $ant_key here"
check 1 "JWT" "bearer $jwt"
check 0 "short gh prefix" "see ghp_short and gho_ docs"
check 0 "clean review" '{"review":"## Claude review · abc1234\n\nNo issues found."}' SECRET

# --- output names the rule ---
printf '%s' "$gh_token" >"$tmp/file"
out=$("$script" "$tmp/file" 2>&1)
if [[ $out == *"rule github-token"* ]]; then pass=$((pass + 1)); else
  fail=$((fail + 1))
  echo "FAIL (rule name): output does not name github-token"
fi
printf '%s' "$secret" >"$tmp/file"
out=$("$script" "$tmp/file" SECRET 2>&1)
if [[ $out == *"value of SECRET"* ]]; then pass=$((pass + 1)); else
  fail=$((fail + 1))
  echo "FAIL (variable name): output does not name SECRET"
fi

# --- usage ---
"$script" >/dev/null 2>&1
if [ $? -eq 2 ]; then pass=$((pass + 1)); else
  fail=$((fail + 1))
  echo "FAIL (usage): no arguments should exit 2"
fi
"$script" "$tmp/missing" >/dev/null 2>&1
if [ $? -eq 2 ]; then pass=$((pass + 1)); else
  fail=$((fail + 1))
  echo "FAIL (usage): a missing file should exit 2"
fi

echo "$pass passed, $fail failed"
[ $fail -eq 0 ]
