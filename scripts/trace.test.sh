#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Self-check for trace.sh: a test naming [AC-01] under e2e/ must flip AC-01 to covered (incl. E2E).
set -euo pipefail
cd "$(dirname "$0")/.."

probe=e2e/tests/trace-probe.spec.ts
trap 'rm -f "$probe"' EXIT

echo "// [AC-01] probe" > "$probe"
scripts/trace.sh >/dev/null
grep -q '^| AC-01 | yes | .*trace-probe.spec.ts.* | yes |' build/trace.md || { echo "FAIL: AC-01 not covered"; exit 1; }
echo "trace.test: ok"
