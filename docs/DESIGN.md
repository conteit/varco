# Varco — Design Direction

> Binding for every UI task (SPA and Keycloak login theme). Reviewers reject UI that drifts from this document.

## 1. Concept: *segnaletica* (wayfinding)

Varco is a gate. The visual language borrows from **Italian transit and building signage**: confident type, a single strong brand colour used as a *field* (not a decoration), big legible numbers, thin rules, clear arrows. It should feel like a well-designed badge reader that happens to live in your pocket — calm, fast, unmistakable.

Three words: **decisa, calma, leggibile** (confident, calm, legible).

### What we are NOT building ("AI slop" blacklist)
Reviewers search for and reject:
- Purple/blue gradients, glassmorphism, glowing blobs, gradient text.
- Generic hero sections, marketing copy, emoji as icons, "✨".
- Card-inside-card layouts; every element in its own rounded shadowed box.
- Default component-kit look (shadcn/MUI/Bootstrap defaults), Inter + slate-grey + `rounded-xl` everywhere.
- Centred everything; dashboards made of identical KPI tiles with tiny sparklines.
- Lorem ipsum, English placeholders, "Welcome back, User! 👋".
- Spinners for everything — use skeletons that match final layout, and optimistic UI for presence actions.
- Ambiguous icons without labels in primary navigation.

## 2. Foundations (tokens live in `packages/brand`)

**Type**
- UI & display: **Instrument Sans** (variable, 400–700). Editorial accent: **Instrument Serif** italic, used sparingly (greeting line, empty states). Both self-hosted via Fontsource.
- Numbers always `font-variant-numeric: tabular-nums`. Live count and clock times use display size.
- Scale (rem): 0.75 · 0.875 · 1 · 1.125 · 1.375 · 1.75 · 2.25 · 3.5 (live count). Line-height 1.4 body, 1.1 display. Letter-spacing −0.02em on ≥1.75rem.

**Colour** — generated at runtime from `VARCO_BRAND_PRIMARY` in OKLCH:
- `--brand-50…950` tonal scale (11 steps), `--brand-ink` (text on brand, auto black/white by APCA/WCAG contrast).
- Neutrals: warm grey (`oklch(… 0.005 80)`), not slate-blue.
- Semantic: `--state-in` (derived from brand, used for *In sede*), `--state-out` (neutral), `--warn` (amber), `--danger` (red), `--ok` (green) — all with AA text pairs.
- Default brand: deep teal `#0E5E6F`, accent: signal orange `#F26B1D` (accent reserved for *attention*: pending sync, coverage gaps, capacity near).
- Light and dark themes; dark is a true dark (`oklch(0.18 …)`), not inverted grey. Respect `prefers-color-scheme`, overridable in *Profilo*.

**Shape & space**
- 4 px grid; spacing tokens 4/8/12/16/24/32/48/64.
- Radius from `VARCO_BRAND_RADIUS`: `sharp` 2px · `soft` 8px (default) · `round` 16px. Buttons follow; the status field does not round its top on mobile (it is a field, edge to edge).
- Elevation: almost none. Separation through rules (1px `--line`) and background steps, not shadows.

**Motion**
- 150–220 ms, `cubic-bezier(.2,.7,.2,1)`. The only "signature" motion: on ENTER/EXIT the status field **slides** like a gate (brand field sweeps in from the bottom for *In sede*, out for *Fuori sede*). Disabled under `prefers-reduced-motion`.
- Haptics: `navigator.vibrate(12)` on successful presence action where supported.

**Iconography**: Phosphor, *regular* weight, 20/24 px, always paired with a text label in navigation and primary actions. Arrow motif: `ArrowLineDownRight` style for *Ingresso*, `ArrowLineUpRight` for *Uscita*.

## 3. Layout

- **Phone (< 768 px)**: bottom tab bar (max 5): *Oggi · Pianifica · Storico · Sede* (only referenti/admin) · *Profilo*. Primary action in the thumb zone.
- **Desktop (≥ 1024 px)**: left rail with the same items + *Amministrazione* group (admin/referente), content max-width 1200 px, office views use a 2-column grid (people list | coverage & expected).
- Tablet: rail collapses to icons + labels below.

## 4. Key screens

### 4.1 *Oggi* (phone, everyone) — the heart of the app
```
┌──────────────────────────────┐
│ mer 18 novembre      ● Online│  ← date (serif italic greeting on first open of day: "Buongiorno, Mario")
├──────────────────────────────┤
│██████████████████████████████│
│██ IN SEDE                  ██│  ← status field: full-bleed brand colour
│██ Padova                   ██│     office name, display size
│██ dalle 08:42 · 3 h 12 min ██│     tabular nums, live-updating duration
│██                          ██│
│██ Uscita prevista  17:30 ✎ ██│  ← chip, tap to set/clear (time wheel sheet)
│██████████████████████████████│
│                              │
│ Domani: Padova 09:00–17:30   │  ← next plan, one line, tap → Pianifica
│                              │
│ ┌──────────────────────────┐ │
│ │  ↗  Registra uscita      │ │  ← primary action, 64px tall, full width
│ └──────────────────────────┘ │
├──────────────────────────────┤
│ Oggi  Pianifica Storico Prof.│
└──────────────────────────────┘
```
- *Fuori sede* state: neutral field, text "Fuori sede", last exit "Ultima uscita ieri 18:04", primary action **Registra ingresso** with office selector chip above it when user has > 1 office ("Sede: Padova ▾").
- After action: optimistic state change + toast "Ingresso registrato · Annulla" (10 s, countdown bar).
- Pending (offline) state: accent stripe on the field edge + "In attesa di invio" label; failed: inline message with "Contatta il referente".
- No membership: calm empty state (serif line) "Non sei ancora associato a nessuna sede." + explanation who to contact.

### 4.2 *Pianifica*
- Horizontal **week strip** (Lun–Ven, swipe for next weeks, up to 60 days). Each day a tall tile: planned office code + times, or "—". Tap → bottom sheet: office (segmented if ≤ 3 offices), "Arrivo" / "Uscita" time pickers (15-min steps), note, *Salva* / *Rimuovi*.
- Weekends shown collapsed but plannable.

### 4.3 *Storico*
- Grouped by day; each visit as one row: `08:42 → 17:31  Padova  8 h 49`. Badges (text, not colour-only): *Rettifica*, *Uscita non registrata*, *Cambio sede*, *Annullata* (struck-through).

### 4.4 *Sede* (referente / admin, desktop-first, works on phone)
Tabs: **Ora · Registro · Pianificazioni · Persone · Impostazioni**.
- **Ora**:
  - Big number block: `23` (display 3.5 rem) `presenti` + ` / 40` + capacity bar with textual state ("Quasi pieno"). Without capacity: just the number and `presenti`, no bar, no placeholder — the block must still look complete, not like something is missing.
  - **Coverage banner** (top, full width): one sentence, plain language: "Un altro referente è in sede: Marco Ferri, fino alle 18:00." / "Sei l'unico referente in sede." (accent) / "Nessun referente in sede." (danger).
  - **Coverage timeline**: 08:00–19:00 axis, one lane per referente (present = solid brand, planned = hatched, gap = accent band labelled "Scoperto 16:00–17:30"). This is the signature visual of the app — make it beautiful and readable at 360 px (lanes stack, axis labels every 2 h).
  - **In sede ora** list: name, "dalle 08:42", "esce 17:30" if planned, *Referente* tag; search box; row action menu: *Chiudi presenza…*.
  - **Attesi oggi**: planned but not arrived, with expected arrival.
- **Registro**: filter bar (period presets *Oggi / Ieri / Settimana / Mese / Personalizzato*, person combobox, type, source, "mostra annullate"), dense table (desktop) / list (phone), pagination, *Esporta CSV*, *Aggiungi rettifica*.
- **Pianificazioni**: calendar-ish grid date × person (desktop), list by date (phone).
- **Persone**: members with role selector (Membro/Referente), *Aggiungi persona* (search users / pre-provision by username), remove with confirm.
- **Impostazioni**: office fields; code & archive only for admin.

### 4.5 *Amministrazione* (admin)
- **Sedi**: table with code, name, people count, referenti count ("Nessun referente" flagged), capacity (`—` when unset), status; *Nuova sede*.
- **Utenti**: search, filters (sede, ruolo, attivi), toggles *Amministratore* / *Attivo* with confirmation dialogs explaining consequences.
- **Audit**: timeline list grouped by day, each entry as a sentence ("Giulia Bianchi ha nominato Luca Verdi referente di Milano") with expandable before/after.

### 4.6 Login (Keycloakify)
- Split layout on desktop: left 40 % brand field with logo and app name in display type; right form. Phone: brand band on top (120 px) + form.
- Fields: *Nome utente*, *Password*, *Ricordami* checkbox, button *Accedi*. Errors inline in Italian. No social providers, no registration link, no "forgot password" unless an env flag enables a URL to the corporate reset portal (`VARCO_PASSWORD_RESET_URL`).

## 5. Microcopy & glossary (Italian, binding)

Tone: second person singular (*tu*), short, factual, no exclamation marks except success toasts. Sentence case.

| Concept | Copy |
|---|---|
| Enter / Exit action | **Registra ingresso** / **Registra uscita** |
| Status | *In sede* / *Fuori sede* |
| Since | *dalle 08:42* |
| Planned exit | *Uscita prevista* |
| Office (entity) | *Sede* (plural *Sedi*) |
| Office admin | *Referente* (plural *Referenti*) |
| Admin | *Amministratore* |
| Member | *Membro* |
| Present count | *23 presenti* (1 → *1 presente*) |
| Expected today | *Attesi oggi* |
| Coverage | *Copertura referenti* |
| Correction | *Rettifica* |
| Auto-close | *Uscita non registrata* |
| Office switch | *Cambio sede* |
| Undo | *Annulla* |
| Pending sync | *In attesa di invio* |
| Offline | *Offline – mostro l'ultimo stato noto* |
| Logout | *Esci* |
| Save / Cancel / Remove | *Salva* / *Annulla* / *Rimuovi* |
| Export | *Esporta CSV* |
| Errors (codes) | `PRESENCE_ALREADY_IN` → "Risulti già in sede." · `PRESENCE_NOT_IN` → "Non risulti in sede." · `UNDO_WINDOW_EXPIRED` → "Non è più possibile annullare. Chiedi una rettifica al referente." · `LAST_ADMIN` → "Deve restare almeno un amministratore attivo." · generic → "Qualcosa non ha funzionato. Riprova tra poco." |

Date/time: `Intl.DateTimeFormat('it-IT', {timeZone: office.timezone})`; durations "3 h 12 min"; relative only for < 1 h ("12 min fa").

## 6. Accessibility checklist (per screen)
- All interactive targets ≥ 44×44 px; focus ring visible (2 px brand + 2 px offset) in both themes.
- Status changes announced via `aria-live="polite"` region.
- Capacity, coverage and badges carry text, not only colour.
- Timeline has an accessible table alternative (visually hidden) listing intervals and gaps.
- Forms: labels always visible (no placeholder-as-label); errors linked with `aria-describedby`.

## 7. Showcase assets
- **Storybook** (ADR-0017) is the living catalogue: every component and view in all states, themes and viewports, published at `/storybook/` on the docs site; its screenshots are the visual-regression baseline.
- README screenshots generated by Playwright (`make screenshots`): *Oggi* (in/out, phone, light+dark), *Sede › Ora* (desktop), login page with default and custom branding.
