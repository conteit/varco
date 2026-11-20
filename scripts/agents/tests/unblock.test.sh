#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Offline tests for the dependency logic in scripts/agents/lib/dispatch.jq.
set -uo pipefail
lib="$(dirname "$0")/../lib"
failed=0

# expect <name> <expected numbers, space separated> <input json>
expect() {
  local got
  got="$(printf '%s' "$3" | jq -r -L "$lib" 'include "dispatch"; unblocked | map(tostring) | join(" ")')"
  [ "$got" = "$2" ] || { echo "FAIL: $1 (got '$got', want '$2')"; failed=1; }
}

issue() { # number, body, extra labels (json array of names), author_association, login
  jq -nc --argjson n "$1" --arg b "$2" --argjson l "${3:-[]}" --arg a "${4:-OWNER}" --arg u "${5:-the-owner}" \
    '{number:$n, body:$b, labels:($l|map({name:.})), author_association:$a, user:{login:$u}}'
}

i5="$(issue 5 'Depends on: #3')"
expect "[A1] issue whose only dependency just closed is unblocked" "5" "{\"closed\":3,\"issues\":[$i5]}"
expect "[A1] other open dependency keeps it blocked" "" "{\"closed\":3,\"issues\":[$(issue 5 $'Depends on: #3\nDepends on: #4'),$(issue 4 'x')]}"
expect "[A1] unrelated issue is not touched" "" "{\"closed\":8,\"issues\":[$i5]}"
expect "[A1] already agent-ready is skipped" "" "{\"closed\":3,\"issues\":[$(issue 5 'Depends on: #3' '["agent-ready"]')]}"
expect "[A1] needs-design is skipped" "" "{\"closed\":3,\"issues\":[$(issue 5 'Depends on: #3' '["needs-design"]')]}"
expect "[A1] non-owner author is skipped" "" "{\"closed\":3,\"issues\":[$(issue 5 'Depends on: #3' '[]' NONE stranger)]}"
expect "[A1] varco-impl author is accepted" "5" "{\"closed\":3,\"issues\":[$(issue 5 'Depends on: #3' '[]' NONE 'varco-impl[bot]')]}"
expect "[A1] pull requests are skipped" "" "{\"closed\":3,\"issues\":[$(issue 5 'Depends on: #3' | jq -c '.pull_request={}')]}"

[ "$failed" -eq 0 ] && echo "unblock.test: ok"
exit "$failed"
