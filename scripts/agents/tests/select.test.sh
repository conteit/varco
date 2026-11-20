#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Offline tests for next_issues (issue selection, ordering, branch naming) in lib/dispatch.jq.
set -uo pipefail
lib="$(dirname "$0")/../lib"
failed=0

# issue <number> <title> <labels json> [author_association] [body] [milestone]
issue() {
  jq -nc --argjson n "$1" --arg t "$2" --argjson l "$3" --arg a "${4:-OWNER}" --arg b "${5:-}" --arg m "${6:-v1.0}" \
    '{number:$n, title:$t, body:$b, labels:($l|map({name:.})), author_association:$a, user:{login:"u"}, milestone:{title:$m}}'
}
# expect <name> <expected "<number>:<branch>" list, space separated> <issues json array> [prs json] [branches json]
expect() {
  local got
  got="$(jq -nc -L "$lib" --argjson i "$3" --argjson p "${4:-[]}" --argjson b "${5:-[]}" 'include "dispatch"; {issues:$i,prs:$p,branches:$b} | next_issues("v1.0") | "\(.number):\(.branch)"' | tr -d '"' | tr '\n' ' ')"
  [ "$got" = "${2:+$2 }" ] || { echo "FAIL: $1 (got '$got', want '$2')"; failed=1; }
}

ready='"agent-ready"'
a="$(issue 10 '[T1] Alpha thing' "[$ready,\"wave:1\"]")"
expect "[A1] ready issue is picked, branch is type/ID-slug" "10:feat/T1-alpha-thing" "[$a]"
expect "[A1] priority: disagreement > bug > lowest wave > lowest number" \
  "13:fix/GH13-d 12:fix/GH12-b 11:feat/T0-w0 10:feat/T1-alpha-thing" \
  "[$a,$(issue 11 '[T0] w0' "[$ready,\"wave:0\"]"),$(issue 12 'b' "[$ready,\"bug\",\"wave:5\"]"),$(issue 13 'd' "[$ready,\"disagreement\",\"wave:9\"]")]"
expect "[A1] in-progress is skipped" "" "[$(issue 10 '[T1] x' "[$ready,\"in-progress\"]")]"
expect "[A1] needs-design is skipped" "" "[$(issue 10 '[T1] x' "[$ready,\"needs-design\"]")]"
expect "[A1] needs-human is skipped" "" "[$(issue 10 '[T1] x' "[$ready,\"needs-human\"]")]"
expect "[A1] not agent-ready is skipped" "" "[$(issue 10 '[T1] x' '[]')]"
expect "[A1] other milestone is skipped" "" "[$(issue 10 '[T1] x' "[$ready]" OWNER '' v2.0)]"
expect "[A1] non-owner author is skipped" "" "[$(issue 10 '[T1] x' "[$ready]" NONE)]"
expect "[A1] open dependency blocks" "" "[$(issue 10 '[T1] x' "[$ready]" OWNER 'Depends on: #3'),$(issue 3 '[T0] dep' '[]')]"
expect "[A1] closed dependency does not block" "10:feat/T1-x" "[$(issue 10 '[T1] x' "[$ready]" OWNER 'Depends on: #3')]"
expect "[A1] open PR for the ID skips the issue" "" "[$a]" '[{"head":{"ref":"feat/T1-alpha-thing"}}]'
expect "[A1] existing remote branch gets -r2" "10:feat/T1-alpha-thing-r2" "[$a]" '[]' '["feat/T1-alpha-thing"]'
expect "[A1] docs area gives docs/ branch" "10:docs/T1-x" "[$(issue 10 '[T1] x' "[$ready,\"area:docs\"]")]"
long="$(issue 10 '[T1] An extremely long title that keeps going and going forever' "[$ready]")"
expect "[A1] slug is capped at 40 chars" "10:feat/T1-an-extremely-long-title-that-keeps-going" "[$long]"

[ "$failed" -eq 0 ] && echo "select.test: ok"
exit "$failed"
