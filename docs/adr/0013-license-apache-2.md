# ADR-0013 — Licence: Apache License 2.0

**Status:** Accepted (owner decision; supersedes the MIT placeholder) · **Date:** 2026-11-18

## Context
Public showcase repo, possibly adopted by companies. The owner prefers Apache 2.0.

## Decision
- `LICENSE` = Apache-2.0 full text; `NOTICE` with copyright line and third-party attributions that require it (e.g. fonts under SIL OFL 1.1).
- SPDX header `SPDX-License-Identifier: Apache-2.0` in source files (Java via Spotless `licenseHeader`, TS via ESLint header rule); generated files exempt.
- **Licence compliance in CI:** allowlist for dependencies — Apache-2.0, MIT, BSD-2/3-Clause, ISC, 0BSD, CC0-1.0, Unlicense, MPL-2.0 (unmodified, file-level), EPL-2.0 (test scope only), OFL-1.1 (fonts). Anything else (GPL/AGPL/LGPL/SSPL/BUSL/unknown) fails the build pending human review. Maven: `license-maven-plugin` third-party report; pnpm: `license-checker-rseidelsohn` or equivalent.
- Contributions: inbound = outbound under Apache-2.0 §5; DCO sign-off (`Signed-off-by`) required by a CI check — no CLA.

## Why Apache-2.0 over MIT
Both are permissive and compatible with the stack (Spring, Keycloak, React are Apache-2.0/MIT). Apache-2.0 adds an **explicit patent grant and patent-retaliation clause**, requires stating modifications, and has the NOTICE mechanism — the protection enterprise legal teams look for when adopting. MIT is shorter but silent on patents.

## Consequences
+ Enterprise-friendly, patent clarity, aligned with the main dependencies.
− Slightly more ceremony (NOTICE, headers, modification statements for redistributors).
