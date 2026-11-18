# ADR-0009 — Runtime branding and UI stack

**Status:** Accepted · **Date:** 2026-11-18

## Context
Public showcase repo; adopters should rebrand (name, logo, colours) **without rebuilding images**. The UI must look deliberate, not like a default component kit.

## Decision
- **Branding inputs:** env vars `VARCO_BRAND_*` + a mounted `branding/` folder (logos, icons, favicon). Defaults ship in the image.
- **Edge renders** `/config.json` and `/manifest.webmanifest` via Caddy `templates` from env; SPA fetches `/config.json` before first paint (inline-free bootstrap; splash uses neutral colours until loaded).
- **Theme generation** in `packages/brand` (pure TS, unit-tested): primary hex → OKLCH tonal scale → CSS custom properties, contrast-checked (WCAG 2.x AA ≥ 4.5:1 for text on brand; auto-adjust lightness otherwise). Same function used by the login theme.
- **UI stack:** React Aria Components (headless, accessible, Italian-aware date/time) + CSS Modules + tokens; Phosphor icons; Instrument Sans/Serif self-hosted. No Tailwind, no MUI/shadcn defaults.

## Consequences
+ Rebrand = edit `.env` + drop files + restart.
+ Visual identity is designed, not inherited.
− More CSS to write than with a kit; mitigated by a small, well-defined `ui/` component set built in the foundation phase.
