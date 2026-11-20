#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# At most one agent session runs the full stack (make up / make e2e) at a time: host ports are shared.
# Usage: stack-lock.sh acquire|release. No-op in CI and outside agent sessions (no VARCO_SESSION_ID).
set -euo pipefail
{ [ -z "${CI:-}" ] && [ -n "${VARCO_SESSION_ID:-}" ]; } || exit 0

lock="${VARCO_AGENTS_HOME:-$HOME/.varco-agents}/stack-lock"
me="$VARCO_SESSION_ID"
holder() { cat "$lock/holder" 2>/dev/null || true; }

case "${1:-}" in
  acquire)
    waited=0
    until mkdir "$lock" 2>/dev/null || [ "$(holder)" = "$me" ]; do
      [ "$waited" -lt "${STACK_LOCK_MAX:-2700}" ] || { echo "stack-lock: held by '$(holder)'; gave up after ${waited}s" >&2; exit 1; }
      sleep "${STACK_LOCK_POLL:-30}"
      waited=$((waited + ${STACK_LOCK_POLL:-30}))
    done
    echo "$me" > "$lock/holder" ;;
  release) [ "$(holder)" != "$me" ] || rm -rf "$lock" ;;
  *) echo "usage: stack-lock.sh acquire|release" >&2; exit 2 ;;
esac
