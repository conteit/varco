# ADR-0017 — Storybook as the living UI catalogue

**Status:** Accepted · **Date:** 2026-11-18 · Supersedes the `/__design` route idea in DESIGN § 7

## Context
UI work is split across many agent tasks (T06, T04, F1–F5, K1). To grow the interface coherently, every component and every view must be visible in isolation, in all states, themes and viewports — for implementers, the reviewer agent, the owner and portfolio visitors.

## Decision
- **Storybook** (latest stable, React + Vite builder) in `frontend/` (`pnpm storybook`, `make storybook`), using the real tokens/themes from `packages/brand` and a toolbar for theme (light/dark), viewport (360 / 768 / 1440) and brand preset (default / custom).
- **What gets stories:**
  - every `src/ui/` component: all variants and states (T06);
  - every feature **view** (page-level) in its key states — empty, loading skeleton, populated, error, offline/pending, role variants — with data from **MSW handlers typed from the OpenAPI contract** (`msw-storybook-addon`), no backend needed (T04, F1–F5);
  - the Keycloakify login pages (K1; Keycloakify ships Storybook support).
- **Docs pages in Storybook:** *Introduzione* (links DESIGN.md), *Foundations* (tokens, type, colour scales with contrast values, motion), *Patterns* (status field, coverage timeline, toasts/undo, forms), *Copy* (glossary from DESIGN § 5). DESIGN.md stays the binding source; Storybook demonstrates it.
- **Quality gates (CI, free):**
  - accessibility addon (axe) on every story — zero violations;
  - interaction tests (`play` functions) run with the Vitest/test-runner integration for behaviour-heavy stories (undo toast, time picker, week strip, coverage timeline);
  - **visual regression** with Playwright screenshots of each story (phone + desktop, light + dark), baselines committed, diffs uploaded as artifacts; intentional changes update baselines in the same PR.
- **Published** to GitHub Pages at `/storybook/` (release) and `/next/storybook/` (main) with the docs site.
- **Definition of done** for UI tasks: new/changed components and views have stories; the reviewer agent reviews the changed stories' screenshots alongside the diff.

## Consequences
+ Coherent, organic UI growth; design drift is visible in diffs; portfolio visitors can browse every screen without running the app.
− More files per UI task and baseline churn; mitigated by deterministic data (fixed clock, seeded fixtures) and fonts bundled locally.
