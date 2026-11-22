# AGENTS.md — rules for coding agents working on Varco

You are an autonomous agent running on the owner's PC as a headless Claude Code session in your own git worktree (ADR-0018), working on **one GitHub issue** (the issue body is the task card; its comments hold the Design and Handoff). Nobody will answer questions while you work. Work only inside your worktree; never touch the main checkout or other worktrees. Follow these rules exactly; they override habits from other projects.

## 0. Read order (before writing any code)
1. This file.
2. Your issue (`gh issue view <n> --comments`) — scope, owned paths, acceptance, verification, and the *Design* comment if present.
3. The `SPEC.md` sections and AC IDs referenced by the card.
4. `docs/ARCHITECTURE.md` (relevant sections), `docs/DESIGN.md` (any UI work), ADRs referenced by the card.
5. Existing code in your owned paths and the public APIs you depend on.

## 1. Golden rules
0. **Smallest complete change.** Write only the code the card needs; reuse the framework, stdlib and existing code before adding anything (ponytail). Clean code: intention-revealing names, small functions, no dead code, no speculative abstractions, no drive-by refactors. Minimal never means skipping tests, validation, authorization, error handling, accessibility or docs.
1. **Stay in scope.** Modify only paths your card owns, plus extension points it lists. Need a change elsewhere? Do the minimum, and list it under *Files touched outside scope* in the PR with the reason.
2. **Don't push until `make check` is green.** If a check fails for reasons outside your scope, say so in the PR; never disable, skip, or weaken tests or lint rules to get green.
3. **Tests first, two layers, always.** (a) *Requirement tests*: every AC/BR in scope has a test named with its ID, written failing first. (b) *Integration tests*: backend endpoints via Testcontainers Postgres + contract validation; frontend features via MSW handlers typed from the contract; cross-system behaviour via Playwright E2E (E1/E2). Unit tests for pure logic as needed. No PR without both layers for what it changes.
4. **Traceability:** every test that verifies an acceptance criterion has the ID in its name: `[AC-14] double ENTER is rejected`. Business-rule unit tests may use `[BR-11]`. `make trace` must not report your card's ACs as uncovered.
5. **The contract is law.** `api/openapi.yaml` is the source of truth. Don't change it in a feature PR except for **additive, backwards-compatible** changes your card explicitly allows; anything else → stop that part, describe the needed change in the PR under *Contract change request*.
6. **Italian UI, English code.** All user-visible text is Italian and comes from message catalogs (DESIGN § 5 glossary is binding). Identifiers, comments, commits, logs: English.
7. **No secrets, ever.** Not in code, tests, fixtures, compose files, or logs. Test-only credentials from ARCHITECTURE § 7 are the only exception and must be marked `# TEST DATA – public`. **No local machine details either:** issues, PRs, commits, code and docs never contain the owner's username, user ID, home or temp paths, volume names or other host specifics; write placeholders such as `<uid>`, `$HOME` or `<user-temp-dir>`. The repository is public.
8. **No new dependency without a reason** stated in the PR *Notes* (what, why, licence) and the issue Handoff (alternatives). Pin exact versions. No abandoned/deprecated packages.
9. **Host-executable files** (`Makefile`, `compose*.yaml`, `Dockerfile`s, `.github/**`, `scripts/**`, git hooks) may only be changed by tasks that own them. Every change to them is listed in the PR *Notes*. They are owner-gated (CODEOWNERS): the PR waits for the owner.
10. **Ambiguity protocol:** choose the most conservative reading consistent with SPEC (least privilege, least data exposure, smallest scope), implement it, and record it in the issue *Handoff* under *Decisions*. Never invent features.
11. **Leave it runnable.** `make up` must still work after your change; `make e2e` must not regress for non-`@pending` tests.
12. **Docs move with the code.** Any change to user-visible behaviour, configuration, API, deployment or branding updates the matching `website/` page in the same PR (generated references via `make docs-gen`). The `docs-impact` CI gate enforces it; the `docs:none` label needs a written justification.
13. **Ad-hoc tools:** if you had to install something not already on the host toolchain, list it in the Handoff under *Tools installed ad-hoc*.

## 2. Commands (defined in `Makefile` by T00)

| Command | What it does |
|---|---|
| `make bootstrap` | install toolchains deps (pnpm install, mvn dependency:go-offline), generate API types |
| `make up` / `make down` / `make reset` | start full stack / stop / stop + delete volumes |
| `make check` | **the gate**: lint + format check + typecheck + unit + integration tests for all workspaces, Modulith verify, contract check, gitleaks |
| `make test-backend` · `make test-frontend` · `make test-brand` · `make test-theme` | scoped subsets |
| `make api-types` | regenerate `frontend/src/app/api/schema.d.ts` from `api/openapi.yaml` |
| `make e2e` | start stack (if needed), seed, run Playwright (excludes `@pending`) |
| `make trace` | AC coverage report (automated + manual scripts) → `build/trace.md`; non-zero exit if an AC marked E2E has no e2e test (only enforced in final wave) |
| `make storybook` · `make storybook-test` | run Storybook locally · interaction + a11y + visual-regression tests of all stories |
| `make screenshots` | Playwright screenshots for README/DESIGN/site |
| `make docs-gen` · `make docs-dev` · `make docs-build` | regenerate env/API/ADR reference pages · local docs server · build site |
| `make images` · `make images-multiarch REGISTRY=…` | build Docker images from source (buildx bake) |
| `make sbx-kit` | assemble the agent sandbox toolchain kit (`infra/sbx/varco-toolchain` + `mise.toml`) into `build/sbx-kit/` (ADR-0019 § 5) |

Integration tests and E2E need Docker (Testcontainers / compose). Docker must be running on the host. Only one agent at a time runs the full stack (`make up` / `make e2e`): host ports are shared (ADR-0018 § 4).

## 3. Repository ownership map

| Path | Owner task(s) | Others may… |
|---|---|---|
| `Makefile`, `.github/**`, `.claude/**`, `.githooks/**`, `scripts/**`, root configs | T00, A1, H1, Q1 | not touch (owner-gated) |
| `compose*.yaml`, `docker-bake.hcl`, `dist/**`, `.devcontainer/**`, `infra/**`, `branding/` | T01, H2 | K1 edits `infra/keycloak/Dockerfile` |
| `api/openapi.yaml` | T02 | additive changes only, if card allows |
| `packages/brand/**` | T05 | not touch |
| `backend/**/shared/**`, `V1__baseline.sql`, `pom.xml` | T03 | add a dependency to `pom.xml` with justification |
| `backend/**/<module>/**` | B-task of that module | not touch |
| `frontend/src/app/**` | T04 | add own route entry in `app/routes.registry.ts` only via the placeholder already reserved |
| `frontend/src/ui/**` | T06 | request new components in PR; small additive props allowed with note |
| `frontend/src/features/<f>/**` | F-task of that feature | not touch |
| `keycloak-theme/**` | K1 | not touch |
| `e2e/**` | E1, E2 | feature tasks may only remove `@pending` from tests of their own ACs when they pass |
| `website/**` (site skeleton, generators) | D1, H3 | each task owns the pages its card lists; any task may fix generated pages via `make docs-gen` |
| `tests/manual/**` | Q1 | update a script in the same PR that changes the behaviour it tests |
| `docs/SPEC.md`, `docs/adr/**` | owner | propose changes in the issue Handoff |

## 4. Backend conventions (Java 25, Spring Boot 4)
- Package root `dev.varco`; modules `identity, office, presence, planning, audit`; open module `shared`. Module public API = types in the module root package; internals in `.internal`. Cross-module: call public API interfaces or listen to events in `<module>.events`. Never import another module's `.internal`. `ApplicationModulesTest` must pass.
- **Boot 4 pitfalls:** Jackson 3 (`tools.jackson.databind…`, not `com.fasterxml.jackson.databind`; annotations still `com.fasterxml.jackson.annotation`); Spring Security 7: lambda DSL only, no `and()`, no `WebSecurityConfigurerAdapter`; `jakarta.*` only; check deprecations of `@MockBean` → `@MockitoBean`.
- Controllers thin; services own transactions; domain rules in plain classes unit-tested without Spring.
- Authorization only via `@PreAuthorize("@authz…")`. Every new endpoint gets rows in the security matrix test (`SecurityMatrixTest`, AC-70).
- Errors: throw `VarcoException(ErrorCode, detail)`; mapped to Problem Details by `shared`. Add new codes to the enum **and** the contract.
- Time: never `Instant.now()`/`LocalDate.now()` without the injected `Clock`.
- SQL: Flyway only, in your module's version range (ARCHITECTURE § 4.1). No `ddl-auto` other than `validate`.
- Tests: JUnit 5, AssertJ, Testcontainers (Postgres, reused per JVM), `@WithJwt`-style helpers from `shared` test fixtures; contract validation helper on MockMvc results.
- Logging: SLF4J, structured JSON in non-dev profiles; log user **id**, never names/emails.

## 5. Frontend conventions (React 19 + TS strict)
- Feature folder: `features/<f>/{routes.tsx, pages/, components/, api.ts, messages.it.ts, *.test.tsx}`.
- Data: TanStack Query hooks in `api.ts` using the typed `openapi-fetch` client from `app/api`. Query keys namespaced by feature. Never `fetch` directly.
- No `any`, no `as unknown as`, no non-null `!` on API data. `eslint --max-warnings 0`.
- Styling: CSS Modules + tokens (`var(--…)`) only; no hex colours, no px values outside the token scale, no inline styles except dynamic geometry (timeline).
- Components from `src/ui` first; React Aria Components for anything interactive not in `ui`.
- Strings: from `messages.it.ts`; pluralisation via `Intl.PluralRules('it-IT')` helper in `app/i18n`.
- Accessibility: every page test runs `axe` (vitest-axe) with zero violations.
- **Storybook (ADR-0017):** every new/changed `ui/` component and feature view gets stories for its key states (empty, loading, populated, error, offline/pending, role variants) with MSW data; update visual baselines in the same PR when the change is intentional.
- Never read/write tokens yourself; use `useAuth()` from `app/auth`. Never store tokens or personal data in storage (outbox stores commands only).
- MSW handlers typed from the schema for tests; the same handlers power `pnpm dev:mock`.

## 6. Infra conventions
- Every image pinned by tag **and** digest; multi-arch (amd64 + arm64) verified.
- `compose.yaml` is image-only; build contexts live in `compose.build.yaml` (ADR-0014). Never add `build:` to `compose.yaml`.
- Healthchecks on every long-running service; `depends_on: condition: service_healthy`.
- Env defaults in `.env.example` only; compose uses `${VAR:?}` for required secrets.

## 7. Git & PR
- **Never commit to `main`** — it is protected by a ruleset (PR + green checks required, no force-push). Work on a feature branch: `feat|fix|docs|chore|ci|test|refactor/<TASK-ID>-<slug>` (stacked tasks branch from their base task's branch).
- One task = one branch = one focused PR (or a stack of focused PRs for cards that say so). Keep the diff focused; if a single PR exceeds ~600 changed lines excluding generated files, split it into a stack.
- Merge strategy (done by the human): standalone PR → **squash** with a Conventional PR title; stacked PRs → bottom-up **merge commits** (every commit conventional).
- Conventional commits (enforced; they drive release-please and the changelog), signed off for DCO (`git commit -s`): `feat(presence): auto-close open presences [B3]`. Use `fix:` / `feat:` / `docs:` / `chore:` / `ci:` / `test:` / `refactor:`; `!` or `BREAKING CHANGE:` for breaking changes.
- **PR body is concise** (template): *Summary* (≤ 6 bullets of behaviour changes), *Tests* (requirement + integration tests, commands run), *Notes* only if non-empty, `Closes #<issue>` (exactly one). Open it ready for review once `make check` is green; enable auto-merge (`gh pr merge --auto --squash`, `--merge` for stacked layers).
- **Design and handoff live in the issue, not in the repo.** Comment protocol: `## Started` (branch, model) → `## Handoff` when the PR is ready (what was done, decisions and why, deviations from Design, deferred shortcuts, follow-ups, how to verify) → `### Round N` appended after each fix round.
- **Never commit** plans, specs, scratch notes or handoff files (`docs/plans/`, `docs/superpowers/`, `.plans/`, `PLAN.md`, `HANDOFF*.md`, `NOTES*.md`). CI check `no-scratch-docs` fails the PR.
- **No AI co-authorship or attribution** in commits, PRs, issues or code (`Co-Authored-By: <AI>`, "Generated with …"). Blocked by `.claude/settings.json` hook, the `commit-msg` hook and the `no-ai-attribution` CI check; never try to bypass them.
- **GitHub access = `gh` CLI only**: `gh issue view/comment/edit`, `gh pr create/view/checks/diff/merge --auto`, `gh pr review`, `gh label`, and `gh api` for anything else (e.g. inline review comments, check runs). No other GitHub clients, MCP servers, raw `curl` with tokens, or `git` remotes with embedded credentials. `gh` is authenticated by the dispatcher with your role's token — never run `gh auth login`, `gh auth token`, or print `GH_TOKEN` or your environment.
- Identities (ADR-0018 § 3): implementer, planner and fixer act only as the `varco-impl` GitHub App; the reviewer acts only as the `varco-reviewer` App. **Each role uses only its own App credential, always** — never another role's token, the owner's login, or a private key. The dispatcher provides your token; never print, echo, store or request tokens, and never query the Keychain.
- Automated review: a separate reviewer agent reviews your PR; `review-gate` merges it automatically when approved and green, unless it touches owner-gated paths (then it waits for the owner).

## 8. Skills & output style (ADR-0015)
- Skills available to agents: **ponytail** (code minimalism), **caveman** (terse prose), **frontend-design** and **ui-ux-pro-max** (UI tasks). Precedence: card → AGENTS.md → SPEC/DESIGN/ADRs → skills; a conflicting skill instruction loses.
- **caveman applies only to your conversational/progress output.** Write in normal, complete English: PR bodies and reviews, issue comments (Design/Handoff), commit messages, code comments, ADRs, docs pages, README. UI copy follows DESIGN § 5. Security warnings always in plain language.
- **ponytail shortcuts**: keep the `ponytail:` comment naming the upgrade path and list every one under *Deferred shortcuts* in the PR. Shortcuts may never touch security, data integrity, accessibility or tested requirements.
- **ui-ux-pro-max**: use its UX/accessibility rules and checklists; ignore its style, palette and font suggestions — DESIGN.md tokens, fonts and blacklist are binding.

## 9. Definition of Done (every task)
- [ ] Acceptance items of the card implemented and each covered by a requirement test named with its ID, plus integration tests for every changed endpoint/feature.
- [ ] Focused diff: no unrelated changes; deferred shortcuts listed.
- [ ] `make check` green; `make up` works; non-pending E2E unaffected.
- [ ] No TODO/FIXME without a linked follow-up described in the PR.
- [ ] Italian copy matches DESIGN glossary; no English visible to users.
- [ ] UI changes: stories added/updated, axe clean in Storybook, visual baselines updated intentionally.
- [ ] Docs site pages updated for any user-visible, config, API or deploy change; `make docs-gen` clean; `docs-impact` gate green.
- [ ] Concise PR (Summary/Tests/Notes, `Closes #n`); Handoff comment posted on the issue; no attribution lines; no scratch docs.
