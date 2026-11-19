#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# AC traceability: lists every AC from docs/SPEC.md and the files whose tests name it as "[AC-nn]".
# Writes build/trace.md. With --strict, exits non-zero if an AC has no test, or an AC marked (E2E)
# has no test under e2e/.
set -euo pipefail

strict=0
[ "${1:-}" = "--strict" ] && strict=1

cd "$(dirname "$0")/.."
mkdir -p build

dirs=()
for d in backend/src/test frontend/src packages keycloak-theme e2e; do
  [ -d "$d" ] && dirs+=("$d")
done

acs=$(sed -nE 's/^- \*\*(AC-[0-9]+) \(E2E[,)].*/\1 E2E/p; s/^- \*\*(AC-[0-9]+)\*\*.*/\1 -/p' docs/SPEC.md)
hits=""
if [ ${#dirs[@]} -gt 0 ]; then
  hits=$(grep -rIoE --exclude-dir=node_modules --exclude-dir=target --exclude-dir=dist \
    '\[AC-[0-9]+\]' "${dirs[@]}" 2>/dev/null | sed -E 's/:\[(AC-[0-9]+)\]$/ \1/' | sort -u || true)
fi

printf '%s\n' "$acs" | awk -v strict="$strict" -v hits="$hits" '
  BEGIN {
    n = split(hits, lines, "\n")
    for (i = 1; i <= n; i++) {
      if (split(lines[i], p, " ") == 2) {
        files[p[2]] = files[p[2]] (files[p[2]] ? ", " : "") "`" p[1] "`"
        if (p[1] ~ /^e2e\//) e2e[p[2]] = 1
      }
    }
    print "# AC traceability\n\n| AC | E2E required | Tests | E2E covered |\n|---|---|---|---|"
  }
  NF {
    total++
    need = ($2 == "E2E")
    if (files[$1] == "") { missing++; if (strict) bad = 1 }
    if (need && !e2e[$1]) { if (strict) bad = 1 }
    tests = (files[$1] == "") ? "uncovered" : files[$1]
    cov = need ? ((e2e[$1]) ? "yes" : "no") : "n/a"
    printf "| %s | %s | %s | %s |\n", $1, (need ? "yes" : "no"), tests, cov
  }
  END {
    printf "\n%d ACs, %d uncovered.\n", total, missing
    exit bad
  }' > build/trace.md || { echo "trace: coverage gaps (see build/trace.md)" >&2; exit 1; }

tail -1 build/trace.md
