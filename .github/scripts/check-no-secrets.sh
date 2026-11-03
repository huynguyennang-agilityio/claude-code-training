#!/usr/bin/env bash
# Fails when a file about to leave a job that holds secrets looks like it carries one.
# Plan: docs/plans/029-review-artifact-secret-check.md (assumption 2)
#
#   check-no-secrets.sh <file> <ENV_NAME>...
#
# Exit 1 when <file> holds the value of one of the named environment variables (raw or
# base64, at any byte offset; values shorter than 8 characters are skipped), a GitHub
# token, an Anthropic key or a JWT. It prints only the rule or variable name, never the
# value. Exit 0 when nothing matches, 2 on a usage error.
set -euo pipefail

if [ $# -lt 1 ] || [ ! -f "$1" ]; then
  echo "usage: check-no-secrets.sh <file> <ENV_NAME>..." >&2
  exit 2
fi
file=$1
shift

found=0
match() {
  echo "check-no-secrets: matched $1" >&2
  found=1
}

# The base64 forms of a value inside a longer encoded text: one per starting offset in
# a 3-byte group, without the edge characters that also hold bits of the bytes around it.
base64_forms() {
  local value=$1 pad enc lead
  for pad in "" "x" "xx"; do
    enc=$(printf '%s%s' "$pad" "$value" | base64 | tr -d '\n=')
    lead=$(((${#pad} * 4 + 2) / 3))
    enc=${enc:lead}
    if [ $(((${#pad} + ${#value}) % 3)) -ne 0 ]; then
      enc=${enc%?}
    fi
    if [ ${#enc} -ge 8 ]; then
      printf '%s\n' "$enc"
    fi
  done
}

for name in "$@"; do
  value=${!name-}
  if [ ${#value} -lt 8 ]; then
    continue
  fi
  if grep -aqF -- "$value" "$file"; then
    match "the value of $name"
  fi
  while IFS= read -r form; do
    if grep -aqF -- "$form" "$file"; then
      match "the base64 value of $name"
      break
    fi
  done < <(base64_forms "$value")
done

rules=(
  "github-token:gh[pousr]_[A-Za-z0-9]{36,}"
  "github-pat:github_pat_[A-Za-z0-9_]{20,}"
  "anthropic-key:sk-ant-[A-Za-z0-9_-]{10,}"
  "jwt:eyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}"
)
for rule in "${rules[@]}"; do
  if grep -aqE -- "${rule#*:}" "$file"; then
    match "rule ${rule%%:*}"
  fi
done

if [ $found -ne 0 ]; then
  exit 1
fi
echo "check-no-secrets: no match in $(basename "$file")"
