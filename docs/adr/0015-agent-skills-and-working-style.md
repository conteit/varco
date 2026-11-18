# ADR-0015 — Agent skills and working style

**Status:** Accepted · **Date:** 2026-11-18

## Context
Owner wants focused, minimal changes (no wasted tokens or code), clean code, requirement + integration tests, conventional commits on feature branches with a protected `main`, and wants to try community skills: **ponytail** (minimal code), **caveman** (terse agent prose) and **ui-ux-pro-max** (UI/UX guidance). All three are MIT-licensed. Skills are prompts injected into autonomous agents — a supply-chain surface like any dependency.

## Decision

### Skills in the sandbox kit (pinned, reviewed)
| Skill | Source | Used by | Scope / limits |
|---|---|---|---|
| **ponytail** | `DietrichGebert/ponytail` | all implementers + reviewer | Smallest complete change; reuse stdlib/framework/existing code. **Never** removes or skips tests, validation, authorization, error handling, accessibility or docs required by AGENTS.md/the card. Every deferred shortcut keeps its `ponytail:` comment and is listed in the PR *Notes* and the issue Handoff; R1 harvests them into issues (`/ponytail-debt`). Reviewer runs its over-engineering review on the diff. |
| **caveman** | `JuliusBrussee/caveman` | all agents | Terse **conversational/progress output only**. Never applies to: PR bodies and reviews, issue comments, commit messages (Conventional Commits, normal English), code comments, ADRs, docs site, README, UI copy, the R1 report — those are read cold by humans and other agents. Security warnings and irreversible actions always in plain language. |
| **frontend-design** | Anthropic (official) | T06, T04, F*, K1, H3 | Aesthetic execution within DESIGN.md. |
| **ui-ux-pro-max** | `nextlevelbuilder/ui-ux-pro-max-skill` | T06, F*, K1 (optional) | **UX/accessibility guidelines and checklists only.** Its style/palette/font catalogue must not override DESIGN.md (binding: tokens, fonts, blacklist — e.g. no glassmorphism). Its search scripts need Python 3 in the template. |

- Each skill is vendored into the kit at a **pinned commit SHA**, its SKILL.md and scripts read by the owner before first use and on every bump (same rule as host-executable files). Hooks that run code (ponytail's plugin hooks need `node`) are allowed inside the sandbox only.
- Precedence: task card → AGENTS.md → SPEC/DESIGN/ADRs → skills. A skill instruction that conflicts with the repo rules loses.

### Working style (also in AGENTS.md)
- One task = one branch = one focused PR; no drive-by refactors; diff kept focused (stack when > ~600 lines).
- Tests are not optional under minimalism: every AC/BR in scope has a requirement test with its ID; every module/feature has integration tests (backend: Testcontainers + contract validation; frontend: MSW typed from the contract; system: Playwright E2E).
- Branches `feat|fix|docs|chore|ci|test|refactor/<ID>-<slug>`; **no direct commits to `main`** (ruleset); Conventional Commits + DCO. Merge: standalone PRs **squash-merged** with a Conventional PR title; stacked PRs merged bottom-up with **merge commits** (each commit conventional).

### Measure, don't assume
Published skill benchmarks are vendor-run prompt-level tests. We track per PR: lines added/removed, tests added, review rounds, CI minutes, and (when sbx exposes it) tokens. After wave 3, compare against expectations and keep/drop skills accordingly (recorded as a comment on the pinned plan issue).

## Consequences
+ Smaller diffs, cheaper runs, easier reviews; UI guidance without surrendering the design direction.
− Risk of over-terse artefacts or skipped safeguards — mitigated by explicit exclusions and reviewer checks.
− Pinned third-party prompts need periodic review.
