#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Pure review-gate evaluator (ADR-0016 section 5). State JSON on stdin; prints PASS or FAIL lines.
# Exit 0 = pass, 1 = fail, 2 = bad input.
set -euo pipefail

owner="" budget=""
while [ $# -gt 0 ]; do
  case "$1" in
    --owner) owner="${2:?}"; shift 2 ;;
    --budget) budget="${2:?}"; shift 2 ;;
    *) echo "usage: review-gate.sh --owner <login> --budget <lines> < state.json" >&2; exit 2 ;;
  esac
done
{ [[ "$budget" =~ ^[0-9]+$ ]] && [ -n "$owner" ]; } || { echo "review-gate: --owner and numeric --budget are required" >&2; exit 2; }

state="$(cat)"
printf '%s' "$state" | jq -e '.pr.head.sha and (.reviews | type == "array") and (.files | type == "array") and (.checks | type == "array") and (.events | type == "array")' >/dev/null 2>&1 \
  || { echo "review-gate: invalid state JSON" >&2; exit 2; }

failures="$(printf '%s' "$state" | jq -r --arg owner "$owner" --argjson budget "$budget" -f "$(dirname "$0")/lib/review-gate.jq")"
if [ -z "$failures" ]; then echo PASS; else printf '%s\n' "$failures"; exit 1; fi
