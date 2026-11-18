# ADR-0016 — Autonomous delivery loop: issues, models, automated review & auto-merge, post-merge human review, release baptism

**Status:** Accepted · **Date:** 2026-11-18

## Context
The owner wants PRs to proceed and merge **without waiting for him**, with the PR history showing one agent implementing and a different agent reviewing — and **all agents run on his own PC** (sbx sandboxes), security first, no secret leakage. GitHub Actions runs only deterministic CI and gates; while keeping the ability to review everything later and disagree. Work, design discussion and handoffs live in **GitHub issues** — no agent plan/spec scratch files committed. Agents never appear as co-authors. Releases are "baptised" only after manual test scripts pass on a specific `main` commit.

## Decision

### 1. Where things run, and identities (who did what is always visible)
- **On the owner's PC:** every agent — planner (Opus), implementers (Haiku/Sonnet), reviewer (Sonnet) — each in its own sbx microVM, launched by `scripts/agents/dispatch.sh`. Claude authentication stays on the PC.
- **On GitHub Actions:** only deterministic jobs (build, tests, scanners, docs, `review-gate`, `release-gate`, labelling) with `GITHUB_TOKEN`. **No Claude/Anthropic token or other AI credential is ever stored in GitHub.**

| Identity | Role | Credential & limits |
|---|---|---|
| **Owner** (human) | Admin; approves owner-gated PRs; post-merge review; runs release tests | own account (2FA, passkey) |
| **`<owner>-bot`** machine user (GitHub allows one free machine account per person) | Implementer & planner agents: push branches, open PRs, comment on issues, enable auto-merge | **fine-grained PAT**, this repo only, 90-day expiry: Contents RW, Pull requests RW, Issues RW, Workflows RW, Metadata R — **no Administration** (cannot touch rulesets/settings/secrets). Repo role *Write*. |
| **`varco-reviewer`** GitHub App (free, installed on this repo only) | Reviewer agent: inline comments, `APPROVE` / `REQUEST_CHANGES` | Permissions: Pull requests RW, Contents **R**, Issues R, Checks R, Metadata R — it **cannot push code**. Private key stays in the PC's keychain; the dispatcher mints a ≤ 1 h installation token per review run. |
| **`github-actions[bot]`** | CI and gates only | `GITHUB_TOKEN`, per-job least-privilege `permissions:` |

**Secret handling (no leakage by construction):** PAT and installation tokens are registered with `sbx secret set` as sandbox-scoped secrets and **injected by the host-side proxy** only into requests to `github.com`/`api.github.com` — the agent never sees raw values, they are not in env vars, files, logs or images. The App private key never enters a sandbox. Deny-by-default network allowlist. gitleaks runs as pre-commit hook, in CI, and GitHub push protection is on. Reviewer and implementer never share a sandbox or a credential.

Commits are authored by the bot (`<owner>-bot <id+<owner>-bot@users.noreply.github.com>`), DCO-signed by the bot. Auto-merge is enabled by the bot's token (not `GITHUB_TOKEN`), so the merge push triggers downstream workflows normally.

### 2. No AI co-authorship (enforced, three layers)
1. `.claude/settings.json` (committed): commit/PR attribution disabled and a **PreToolUse hook** (`.claude/hooks/block-attribution.sh`) that blocks any `git commit`, `gh pr create/edit`, `gh issue create/comment` whose text contains `Co-Authored-By:` with an AI identity, `noreply@anthropic.com`, or "Generated with". Permission deny rules block `git push` to `main` and `git commit --no-verify`.
2. `commit-msg` hook installed by `make bootstrap` rejecting the same patterns.
3. CI job `no-ai-attribution` (required) scans every commit message and the PR body.

### 3. Model routing (labels on issues; dispatcher and workflows read them)
| Work | Model | Effort |
|---|---|---|
| Planning: design comments on issues, splitting, re-planning after failure | **Opus 5.5** (`claude-opus-5-5`) | high |
| Implementation of well-defined cards (`model:haiku`) | **Haiku 5.5** (`claude-haiku-5-5`) | default |
| Complex implementation (`model:sonnet`) and **all reviews** | **Sonnet 5.5** (`claude-sonnet-5-5`) | high for R1/foundation reviews, default otherwise |

Escalation: Haiku doesn't converge in 2 fix rounds → relabel `model:sonnet`, fresh sandbox. Sonnet doesn't converge in 2 rounds → `needs-replan` → Opus re-plans in the issue (revised card as a comment), then back to `agent-ready`. Cards labelled `needs-design` get an Opus design comment before implementation.

### 4. Issues are the source of truth for work
- Each task card is an issue (seeded once from the planning pack; the pack's card files are **not committed**). Dependencies as `Depends on: #n` lines (+ native "blocked by" links where available); an `unblock` workflow adds `agent-ready` when all dependencies are closed.
- Comment protocol on the issue (templates in `scripts/agents/prompts/`): **Design** (Opus: approach, files, risks, test plan), **Started** (branch, model), **Handoff** (what was done, decisions and why, deviations, deferred shortcuts, follow-ups, how to verify) — posted by the implementer when the PR is ready. Reviews stay on the PR.
- Forbidden in the repo: agent plans, specs, scratch or handoff files (`docs/plans/`, `docs/superpowers/`, `.plans/`, `PLAN.md`, `HANDOFF*.md`, `NOTES*.md`, …). `.gitignore` + required CI check `no-scratch-docs`. Durable engineering docs (SPEC, ARCHITECTURE, DESIGN, ADRs, manual tests) and the docs site are the only committed docs.

### 5. PRs: concise, auto-reviewed, auto-merged
- PR body = **Summary** (≤ 6 bullets of behaviour changes) + **Tests** (requirement + integration tests added/changed, commands run) + optional **Notes** (only if non-empty: outside-scope files, new deps, deferred shortcuts, contract requests) + `Closes #n`. Detail belongs in the issue Handoff comment.
- **Reviewer agent (local)**: when a PR is ready and CI is green on its head SHA with no review from `varco-reviewer[bot]` on that SHA, the dispatcher starts a **fresh** sandbox (Sonnet 5.5, cold context) with the reviewer App token. It reviews against the linked issue (incl. Design/Handoff comments), AGENTS.md, SPEC/DESIGN; posts inline comments and one summary review `APPROVE` or `REQUEST_CHANGES` (tags `[blocker]/[should]/[nit]`, risk labels). The reviewer can't push, so it can't "fix" what it reviews.
- **`review-gate`** (required check on GitHub, deterministic, no LLM, no secrets): passes only if (a) an `APPROVE` review from `varco-reviewer[bot]` exists **on the current head SHA** and no later `REQUEST_CHANGES`, (b) no `needs-human` label, (c) all other required checks green, (d) diff within size budget, (e) the PR closes exactly one open issue. Prompt injection in PR content can at most influence the reviewer's verdict (a); (b)–(e) and owner-gated paths are enforced by code and rulesets.
- **Owner-gated paths** via `CODEOWNERS` + ruleset "require code owner review": `.github/**`, `.claude/**`, `AGENTS.md`, `CODEOWNERS`, `Makefile`, `scripts/**`, `dist/**`, `**/Dockerfile`, `compose*.yaml`, `docker-bake.hcl`, `infra/edge/**`, `backend/**/shared/security/**`, `api/openapi.yaml` (non-additive), `docs/adr/**`, `docs/SPEC.md`, `LICENSE`, `NOTICE`. These PRs auto-review but wait for the owner — the one intentional human checkpoint (code that runs with the owner's credentials or changes the rules).
- Ruleset on `main`: no direct pushes for anyone (no bypass), PR required, required checks (CI, E2E, CodeQL, docs, commitlint, DCO, no-ai-attribution, no-scratch-docs, review-gate), code-owner review, approvals of the most recent push only, merge methods squash + merge commit. Auto-merge enabled at repo level.

### 6. Post-merge human review (review later, disagree cheaply)
- On merge, workflow labels the PR `human-review:pending` and appends it to the pinned issue **"Human review queue"** (week sections, PR title, issue, risk tags from the reviewer: `risk:security`, `risk:data`, `risk:ux`, `size:L`).
- Owner reviews at leisure: label `human-review:ok`, or opens a **Disagreement** issue (form: PR, what/why, desired outcome, severity, revert yes/no). Disagreements are labelled `agent-ready`, `model:sonnet` and get dispatcher priority; revert requests produce a revert PR first.
- Weekly digest comment in the queue issue: counts pending, oldest age, merged-with-risk list.

### 7. Release baptism (manual test scripts)
- release-please keeps a release PR open. When the owner wants a release: open a **Release candidate** issue (form) → workflow records the candidate SHA (= current `main` head), builds/publishes `edge` + `sha-*` images and a dist package for that SHA, and renders the checklist of manual test scripts `tests/manual/MT-*.md` applicable to the changes since the last release (all **core** scripts always).
- Owner executes the scripts (dist demo on his Mac + phone), records pass/fail per step in the issue; failures become bug issues (`agent-ready`).
- **`release-gate`** (required check on the release-please PR): passes only if an RC issue labelled `rc:passed` by the owner references the release PR's base SHA, and no commits other than release-please's landed after it. Merging the release PR = baptism: tag `vX.Y.Z` on the tested commit lineage → images, dist, docs `/`.

## Consequences
+ Work flows continuously; the owner's attention goes to owner-gated PRs, the review queue and releases.
+ Full audit trail: issue (design/handoff) → PR (summary/tests/review) → merge → human-review label → RC issue.
− Auto-merged mistakes reach `main` before human review — accepted; mitigated by tests, gates, owner-gated paths, cheap disagreement/revert flow, and releases gated by manual testing.
− Throughput is bound by the PC (3–5 microVMs) and subscription usage limits; the dispatcher caps concurrency and queues work while the PC is off.
− Two bot identities to set up once (machine user + GitHub App).
