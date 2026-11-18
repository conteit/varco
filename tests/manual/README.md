# Manual test scripts (release baptism)

Automated tests (requirement, integration, E2E) gate every PR. These scripts cover what automation can't judge reliably — real phones, PWA install, offline on a device, screen readers, real directories, upgrades with real data, visual quality — and gate **releases** (ADR-0016 § 7).

- `core: true` scripts run for every release; others run when files matching their `triggers` changed since the last release (the RC workflow computes the list).
- Each script lists the ACs/NFRs it covers; `make trace` reports manual coverage alongside automated coverage.
- Results are recorded in the **Release candidate** issue, never committed. A release is baptised by merging the release-please PR once the RC issue is labelled `rc:passed`.
- Scripts are durable test procedures: update them in the same PR that changes the behaviour they test (owner-gated path is not required; reviewer checks it).
