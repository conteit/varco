# Varco — Functional Specification

> **Varco** (Italian: *passage, gateway*) — office presence tracking and planning PWA.
> Source of truth for **what** the system does. Architecture lives in `ARCHITECTURE.md`, UI direction in `DESIGN.md`.
> Every business rule (`BR-xx`) and acceptance criterion (`AC-xx`) has a stable ID. Tests MUST reference AC IDs (see AGENTS.md § Traceability).

---

## 1. Purpose & scope

Authenticated employees record when they **enter** and **exit** an office (*sede*) from their phone, and **plan** future presence. Office administrators (*referenti di sede*) see who is in the office right now, whether another referente is available, and the audit log of entries, exits and planned exits. System administrators define offices and assign roles.

**In scope (v1):** OIDC login via Keycloak federated to 2+ LDAP directories; presence tracking; presence planning; live office view; people and role management; audit logs; CSV export; runtime branding (logo, colours, name); Italian UI; installable PWA; Docker Compose deployment.

**Out of scope (v1)** — do not implement, do not stub: geolocation/geofencing, QR/NFC/badge check-in, push notifications, desk/room booking, multi-language UI (English locale planned for v1.1), native apps, MFA configuration (Keycloak can add it later), payroll/HR integrations, multi-tenancy.

---

## 2. Roles

| Role (code) | UI label (it) | Scope | Source |
|---|---|---|---|
| `USER` | Dipendente | Implicit for any active authenticated user | Keycloak login + app DB |
| `MEMBER` | Membro della sede | Per office | `office_membership.role = MEMBER` |
| `OFFICE_ADMIN` | Referente di sede | Per office | `office_membership.role = OFFICE_ADMIN` |
| `ADMIN` | Amministratore | Global | `app_user.is_admin = true` |

- Roles are **cumulative**: an `OFFICE_ADMIN` is also a member of that office and tracks their own presence like anyone else. An `ADMIN` tracks presence only in offices where they hold a membership.
- A user may belong to several offices with different roles (e.g. `OFFICE_ADMIN` in Padova, `MEMBER` in Milano).
- Authentication happens in Keycloak; **authorization data lives in the app DB** (see ADR-0004).

### 2.1 Permission matrix

| Capability | USER (no membership) | MEMBER | OFFICE_ADMIN (own offices) | ADMIN |
|---|---|---|---|---|
| See own profile & status | ✓ | ✓ | ✓ | ✓ |
| Record own enter/exit | – | ✓ (own offices) | ✓ | ✓ (where member) |
| Plan own presence | – | ✓ | ✓ | ✓ (where member) |
| See own history | ✓ | ✓ | ✓ | ✓ |
| Live office view (count, people, referenti) | – | – | ✓ | ✓ (all) |
| Office presence log, plans, CSV export | – | – | ✓ | ✓ (all) |
| Presence corrections for others | – | – | ✓ | ✓ |
| Edit office details (name, address, hours, capacity, auto-close) | – | – | ✓ | ✓ |
| Create / archive office, change office code | – | – | – | ✓ |
| Search users (minimal fields) | – | – | ✓ | ✓ |
| Pre-provision user by username | – | – | ✓ | ✓ |
| Add/remove members, grant/revoke `OFFICE_ADMIN` | – | – | ✓ (own offices) | ✓ |
| Grant/revoke `ADMIN`, (de)activate users | – | – | – | ✓ |
| Admin audit log | – | – | ✓ (filtered to own offices) | ✓ (all) |

Standard users never see other people's presence (privacy by default, BR-20).

---

## 3. Domain glossary

| Term | Italian UI | Meaning |
|---|---|---|
| Office | Sede | A physical location. Has code, name, address, timezone, opening hours, optional capacity, auto-close time. |
| Presence event | Registrazione | Immutable `ENTER` (*Ingresso*) or `EXIT` (*Uscita*) record. |
| Current presence | In sede | Derived state: user is inside office X since time T. |
| Plan | Pianificazione | Intention to be at office X on date D, optional expected arrival / exit time. |
| Planned exit | Uscita prevista | Expected exit time today (stored on today's plan). |
| Correction | Rettifica | Presence event inserted or voided by a referente/admin, with mandatory note. |
| Auto-close | Chiusura automatica | System-generated `EXIT` for presences left open at the office's auto-close time. |
| Coverage | Copertura referenti | Whether at least one referente is present (now / over today's opening hours). |

---

## 4. Business rules

### Identity & provisioning
- **BR-01 JIT provisioning.** On the first authenticated API call, the backend resolves the user by `sub`; if not found, by lower-cased `preferred_username` among pre-provisioned users without `sub` (then links the `sub`); otherwise creates a new user. `display_name` and `email` are refreshed from the token on each login (`last_login_at` updated at most once per 5 minutes).
- **BR-02 Bootstrap admins.** Usernames listed in `VARCO_BOOTSTRAP_ADMINS` (comma-separated) get `is_admin = true` when provisioned. The flag is never removed automatically afterwards.
- **BR-03 Username uniqueness across directories.** Usernames must be unique across all federated LDAP directories (Keycloak constraint). Collisions are a documented operational limitation, not handled by the app.
- **BR-04 Inactive users.** A deactivated user gets `403 USER_INACTIVE` on every API call except `GET /api/me`, which returns `active=false` so the UI can explain. Deactivation closes any open presence (source `CORRECTION`, note "Utente disattivato").

### Presence tracking
- **BR-10 One place at a time.** A user is present in at most one office at a time.
- **BR-11 Enter.** `ENTER` requires an active membership in an active (non-archived) office.
  - Already present in the same office → `409 PRESENCE_ALREADY_IN`.
  - Present in a different office → the server first writes an `EXIT` for the previous office at the same instant (source `AUTO_SWITCH`), then the `ENTER`. Response flags `switchedFrom`.
- **BR-12 Exit.** `EXIT` when not present → `409 PRESENCE_NOT_IN`. `EXIT` always targets the office of the current presence (the request's `officeId` is ignored for EXIT and may be omitted).
- **BR-13 Client time (offline queue).** `occurredAt` is optional (default: server now). If provided it must satisfy `now − 24h ≤ occurredAt ≤ now + 2min` and be `≥` the user's latest non-voided event time; otherwise `422 PRESENCE_TIME_INVALID`.
- **BR-14 Idempotency.** Each client request carries `clientEventId` (UUID). A repeated `(user, clientEventId)` returns `200` with the originally created event and causes no state change.
- **BR-15 Undo.** A user may void their own latest non-voided `APP` event within **2 minutes** of `recorded_at` (`DELETE /api/me/presence/events/{id}`). Voiding restores the previous state (re-opens the previous presence if the voided event was an `EXIT`; closes nothing if it was an `ENTER` — the presence simply disappears). After the window → `409 UNDO_WINDOW_EXPIRED`. Voided events stay in the log, marked voided.
- **BR-16 Auto-close.** Every minute a job closes open presences of offices whose local time has passed `auto_close_time` today (default 21:00), writing `EXIT` at exactly `auto_close_time` local, source `AUTO_CLOSE`. The user's history shows these as "Uscita non registrata".
- **BR-17 Corrections.** Referenti (own offices) and admins can, with a mandatory note (5–500 chars):
  - (a) **Close an open presence** at a given time `≥ since` and `≤ now`.
  - (b) **Add a past visit**: an `ENTER`+`EXIT` pair in the past 31 days that does not overlap any existing non-voided interval of that user (in any office).
  - (c) **Void a visit**: void an `ENTER` and its matching `EXIT` together (or a lone open `ENTER`, which also removes the current presence).
  Corrections use source `CORRECTION`, `recorded_by` = actor, and produce audit entries. Events are never updated or deleted except by voiding (and retention purge, BR-41).
- **BR-18 Archived offices** accept no new events or plans. Archiving closes open presences (source `CORRECTION`, note "Sede archiviata") and deletes future plans.

### Planning
- **BR-20 Privacy by default.** Members see only their own presence and plans. Office-level data is visible only to referenti of that office and admins.
- **BR-21 One plan per user per date** (one office per day). Date range: today … today + 60 days (office timezone). If both times are set, `expectedArrival < expectedExit`.
- **BR-22 Planned exit.** While present, the user can set/clear *Uscita prevista* for today; this creates or updates today's plan for the current office. The time must be later than now (office local time).
- **BR-23 Plans and memberships.** Plans require membership in the target office. Removing a membership deletes that user's future plans in that office.

### Office view & coverage
- **BR-30 Live count** = number of current presences in the office. Capacity status: `OK` (< 90 %), `NEAR` (90–100 %), `OVER` (> 100 %, allowed but highlighted). **Capacity is optional**: an office without capacity has no capacity status (`null`), and the UI shows the count only — no ratio, no bar, no warnings.
- **BR-34 Optional capacity.** Capacity may be omitted at creation and set, changed or cleared (`null`) at any time by a referente of the office or an admin. Clearing it is audited like any office update.
- **BR-31 Coverage now.** For a viewing referente: `OK` if at least one **other** referente of the office is present; `ONLY_YOU` if the viewer is the only referente present; `NONE` if no referente is present (e.g. admin viewing).
- **BR-32 Coverage timeline.** For today, between office `open_time` and `close_time`, compute intervals where at least one referente is present or planned (present → from `since` to planned exit or `close_time`; planned-not-arrived → expected arrival..expected exit, default open..close). Gaps are returned explicitly.
- **BR-33 Expected today.** Office view lists members planned for today who have not entered yet, and planned exits of people currently present, sorted by time.

### Role management
- **BR-35** Referenti can add/remove members and grant/revoke `OFFICE_ADMIN` **only in offices where they are `OFFICE_ADMIN`**. A referente can revoke their own `OFFICE_ADMIN` (UI warns if they are the last one).
- **BR-36** Only admins grant/revoke `ADMIN` and (de)activate users. The **last active admin** cannot lose `ADMIN` or be deactivated → `409 LAST_ADMIN`.
- **BR-37** Pre-provisioning creates a user by username (lower-cased, `^[a-z0-9._-]{2,64}$`) with optional display name; duplicate → `409 USER_EXISTS`.
- **BR-38** An office may have zero referenti; the admin UI flags it ("Nessun referente").

### Audit & retention
- **BR-40 Admin audit.** Every state-changing administrative action writes an `audit_entry` (actor, action, office, subject user, details JSON with before/after): office created/updated/archived, membership added/changed/removed, admin granted/revoked, user (de)activated, user pre-provisioned, presence corrected/voided by others, auto-close, auto-switch. Audit entries are append-only.
- **BR-41 Retention.** Nightly job purges presence events and plans older than `VARCO_RETENTION_MONTHS` (default 24) and audit entries older than `VARCO_AUDIT_RETENTION_MONTHS` (default 60). The purge itself is audited (counts only).
- **BR-42 Time.** All instants stored in UTC (`timestamptz`). "Today", opening hours, auto-close and plans are evaluated in the office timezone (default `Europe/Rome`). UI shows 24-hour times, Italian dates.

---

## 5. Acceptance criteria

Format: *Given / When / Then*, condensed. **E2E** = must be covered by Playwright against the full stack. Others may be covered at API/integration or component level.

### Authentication (AUTH)
- **AC-01 (E2E)** Unauthenticated visit to `/` redirects to the branded Keycloak login at `/auth/...`; after login with an LDAP-A user, the user lands on *Oggi*.
- **AC-02 (E2E)** A user from LDAP-B can log in as well.
- **AC-03** Wrong password shows the Keycloak error in Italian on the branded page.
- **AC-04** API calls without a valid bearer token → `401`; token from another issuer or audience → `401`.
- **AC-05 (E2E)** *Esci* (logout) ends the Keycloak session; reopening `/` requires login again.
- **AC-06** Access tokens are never written to `localStorage`/`sessionStorage`/`IndexedDB` (component test inspects storage after login flow with mocked OIDC).
- **AC-07** First login of a pre-provisioned username links the account and keeps its memberships (BR-01).
- **AC-08** A bootstrap admin username becomes admin on first login (BR-02).
- **AC-09** An inactive user sees the screen "Account disattivato" and cannot call other APIs (BR-04).

### Tracking (TRK)
- **AC-10 (E2E, mobile viewport)** Member with one office taps *Registra ingresso* → status card shows *In sede · {Sede} · dalle HH:MM* within 1 s; history shows the event.
- **AC-11 (E2E, mobile)** Present member taps *Registra uscita* → status shows *Fuori sede*.
- **AC-12** Member with multiple offices is asked which office (default: primary office, else last used).
- **AC-13** ENTER while present in another office auto-switches (BR-11); history shows *Cambio sede*.
- **AC-14** Double ENTER → `409 PRESENCE_ALREADY_IN`; double EXIT → `409 PRESENCE_NOT_IN`; UI shows a friendly Italian message and refreshes state.
- **AC-15 (E2E)** After ENTER, *Annulla* toast is visible for 10 s; tapping it voids the event; status returns to *Fuori sede*. Server rejects undo after 2 minutes (BR-15, API test with clock).
- **AC-16** Offline: with network down, tapping ENTER stores the action locally and shows *In attesa di invio*; on reconnect it is sent with the original `occurredAt` and `clientEventId`; duplicates are not created (BR-13, BR-14).
- **AC-17** `occurredAt` older than 24 h or earlier than the last event → `422 PRESENCE_TIME_INVALID`; the UI shows the pending item as failed with a "Contatta il referente" hint.
- **AC-18** Auto-close writes `EXIT` at auto-close time for open presences; user history labels it *Uscita non registrata* (job test with fixed clock).
- **AC-19** User without memberships sees *Non sei ancora associato a nessuna sede* and no tracking buttons.

### Planning (PLN)
- **AC-20 (E2E)** Member plans presence for next Tuesday with arrival 09:00 and exit 17:30; it appears in *Pianifica* and in the referente's office plans.
- **AC-21** Plans outside today…+60 days, or with arrival ≥ exit, are rejected with field errors shown inline.
- **AC-22 (E2E)** Present member sets *Uscita prevista* 17:30 from *Oggi*; referente's live view shows it next to the person.
- **AC-23** Second plan for the same date replaces office/times (upsert), never duplicates.

### Office view (OFF)
- **AC-30 (E2E, desktop)** Referente opens *Sede* → sees live count `N presenti` (and `/ capacità` when set) that updates within 20 s of another user's ENTER, without reload.
- **AC-31 (E2E)** Present-people list shows name, since, planned exit; referenti are marked *Referente*.
- **AC-32 (E2E)** Coverage banner: with another referente present → *Un altro referente è in sede*; when alone → *Sei l'unico referente in sede*; including the other referente's planned exit when set.
- **AC-33** Coverage timeline for today returns and renders gaps between opening hours where no referente is present or planned (BR-32; API test with fixtures).
- **AC-34** Capacity states OK/NEAR/OVER render distinctly (not by colour alone); an office without capacity shows only `N presenti` with no bar or state.
- **AC-35** A `MEMBER` calling office endpoints gets `403`; a referente of office A calling office B gets `403`.
- **AC-36 (E2E)** Referente closes a forgotten presence with a note; the person's status becomes *Fuori sede*; the log shows *Rettifica* with actor and note.
- **AC-37** Add-past-visit rejects overlaps; void-visit voids both events (BR-17).

### Administration (ADM)
- **AC-40 (E2E, desktop)** Admin creates office "Milano Centrale" (code `MIL`), sets capacity 30 and hours 08:00–19:00; it appears in office lists.
- **AC-41 (E2E)** Admin pre-provisions `luca.verdi` and makes him referente of Milano; after Luca's first login he sees the *Sede* tab for Milano.
- **AC-42 (E2E)** Referente of Padova adds a member to Padova and promotes them to referente; the action appears in the admin audit log.
- **AC-43** Referente cannot see or manage memberships of offices they don't administer; cannot grant `ADMIN` (403).
- **AC-44** Revoking `ADMIN` from or deactivating the last admin → `409 LAST_ADMIN`.
- **AC-45** Archiving an office closes open presences, deletes future plans, hides it from tracking pickers; history remains visible to admins.
- **AC-47** An office can be created without capacity; capacity can later be set and then cleared (`PATCH` with `capacity: null`); live view returns `capacity: null, capacityStatus: null` when unset.
- **AC-46** Office code is unique (case-insensitive) → `409 OFFICE_CODE_EXISTS`.

### Audit (AUD)
- **AC-50 (E2E)** Referente filters the presence log by date range, person and type; results are paginated; *Esporta CSV* downloads a UTF-8 CSV (`;` separator, Italian header, local times) with the same filter.
- **AC-51** Every action listed in BR-40 produces exactly one audit entry with before/after details (parameterised integration test).
- **AC-52** Audit and presence tables cannot be updated via the API (no endpoints); voiding sets `voided_at` only.
- **AC-53** Retention job purges old rows and writes a purge audit entry (BR-41).

### Branding & PWA (BRD)
- **AC-60 (E2E)** With `VARCO_BRAND_NAME=Acme Presenze`, `VARCO_BRAND_PRIMARY=#0E7C66` and a custom logo mounted in `branding/`, both the app shell and the Keycloak login page show the name, logo and primary colour — no rebuild required, container restart only.
- **AC-61** Generated colour scale keeps WCAG AA contrast for text on primary (automated check; falls back to a darker/lighter shade if not).
- **AC-62** The manifest uses the brand name, theme colour and icons from `branding/`; Lighthouse marks the app installable.
- **AC-63** App shell loads offline after first visit and shows the last known status with an *Offline* indicator.

### Security (SEC)
- **AC-70** Security matrix test: every endpoint × {anonymous, inactive, user-no-membership, member, referente-own, referente-other, admin} returns the expected status (single parameterised test, table in source).
- **AC-71** Responses carry CSP (no `unsafe-inline` for scripts), HSTS (prod profile), `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy` (geolocation=() etc.).
- **AC-72** No secrets in the repo; `.env.example` only contains placeholders; gitleaks passes in CI.

---

## 6. Non-functional requirements

| ID | Requirement |
|---|---|
| NFR-01 | Mobile first: fully usable at 360×640; primary action reachable by thumb (bottom 40 % of the screen). |
| NFR-02 | Accessibility WCAG 2.2 AA; zero `serious`/`critical` axe violations on all screens (E2E). Status never conveyed by colour alone. |
| NFR-03 | Performance: Lighthouse mobile Performance ≥ 90 on *Oggi*; JS initial bundle ≤ 200 KB gzip; API p95 < 200 ms for `/api/me` and live view with 500 present users (seeded load test, optional). |
| NFR-04 | Italian only UI; all strings in message catalogs; dates/times via `Intl` with `it-IT`, timezone of office. |
| NFR-05 | Runs with `docker compose up` on linux/amd64 and linux/arm64 (Apple Silicon) with no manual steps beyond copying `.env.example`. |
| NFR-06 | Supported browsers: last 2 versions of Safari iOS, Chrome Android, Chrome/Edge/Firefox/Safari desktop. |
| NFR-07 | Observability: structured JSON logs (backend), `/actuator/health` (liveness/readiness), request id propagated from edge. No personal data in logs beyond user id. |
| NFR-09 | Adoption: docs site (GitHub Pages) always matches the released version; README quick starts are executed by CI; images multi-arch, attested, rebuilt for fixable vulnerabilities. |
| NFR-10 | UI catalogue: every component and view has Storybook stories with zero axe violations and visual-regression baselines (ADR-0017). |
| NFR-08 | Privacy: no geolocation, no device fingerprinting, no third-party requests at runtime (fonts self-hosted). Retention configurable (BR-41). |

> **Note on Italian labour law (not legal advice):** systems that record employee presence may fall under art. 4 of the Statuto dei Lavoratori and GDPR. Production use needs review by the employer's DPO / HR. The README must say so.
