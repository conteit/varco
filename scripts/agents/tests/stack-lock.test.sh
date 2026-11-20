#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -uo pipefail
lock="$(cd "$(dirname "$0")" && pwd)/../stack-lock.sh"
t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
export VARCO_AGENTS_HOME="$t" STACK_LOCK_POLL=1 STACK_LOCK_MAX=2
failed=0; fail() { echo "FAIL: $*"; failed=1; }

VARCO_SESSION_ID=a "$lock" acquire || fail "first acquire"
VARCO_SESSION_ID=a "$lock" acquire || fail "re-acquire by the holder"
VARCO_SESSION_ID=b "$lock" acquire 2>/dev/null && fail "[A1] second session must time out while the lock is held"
VARCO_SESSION_ID=b "$lock" release; [ -d "$t/stack-lock" ] || fail "release by a non-holder freed the lock"
VARCO_SESSION_ID=a "$lock" release; [ ! -d "$t/stack-lock" ] || fail "release did not free the lock"
VARCO_SESSION_ID=b "$lock" acquire || fail "acquire after release"
CI=1 VARCO_SESSION_ID=c "$lock" acquire || fail "no-op under CI"
env -u VARCO_SESSION_ID "$lock" acquire || fail "no-op outside agent sessions"

[ "$failed" -eq 0 ] && echo "stack-lock.test: ok"
exit "$failed"
