# PR14.5 — Remote Tenant Rollout Smoke Results

Status: Passed remote Vercel smoke.

This document records the live remote UI smoke for the two PR14 tenant postures. It intentionally omits secret-bearing material, connection strings, raw auth identifiers, and screenshots.

## Environment

| Field | Value |
|-------|-------|
| App URL | `https://puls-dev.vercel.app` |
| Run date | 2026-06-01 |
| Mode | `VITE_PULS_DEMO_MODE=false` |
| Expected adapter posture | `source: real` |
| Runtime scope | UI smoke only; no connector runtime |

Remote Vercel smoke passed for PULS Connector Lab no-connector posture.

Remote Vercel smoke passed for Puls Teknik seeded connector posture.

connector-admin@puls.demo remained public-tenant linked only during smoke.

No runtime sync, no credentials, and no ERP writes were exercised.

## PULS Connector Lab — No-Connector Posture

| Route | Observed result | Status |
|-------|-----------------|--------|
| `/dashboard` | Tenant label `PULS Connector Lab`; active employees `0`; departments `0`; positions `0`; ERP status `Kaynak yok`; data readiness `0%` | Passed |
| `/erp` | `Kaynak tanımlı değil`; onboarding stepper visible; no provider selected by default; provider options include Canias, Logo, CSV / Excel, and Custom API | Passed |
| `/erp` provider preview | Selecting Canias opens local preview only; no metadata is persisted by the selection | Passed |
| `/erp` draft sheet | `Taslağı incele` opens `Canias kurulum taslağı`; live transfer, credential storage, and ERP write copy remains closed | Passed |
| `/erp` disabled action | `Bağlantı kaydı oluşturma kapalı` was present with DOM `disabled: true` | Passed |

Expected conclusion: a new tenant can enter the product with no connector configured yet and still get a real product onboarding state instead of embedded demo fallback.

## Puls Teknik — Seeded Connector Metadata Posture

| Route | Observed result | Status |
|-------|-----------------|--------|
| `/erp` | `Canias ERP (Pasif)` visible; live connection boundary is inactive | Passed |
| `/erp` preflight | Control `100%`; field mapping `12 / 12`; source namespace `1`; identity reconciliation `13` | Passed |
| `/erp` guardrails | The page states live transfer, credential storage, and ERP writes are not started from the screen | Passed |
| `/dashboard` | Tenant label `Puls Teknik`; active employees `120`; departments `12`; positions `36`; competency templates `10` | Passed |
| `/dashboard` ERP card | ERP status `Canias`; `ERP bağlantısı pasif`; data readiness `100%`; field mapping `12 / 12` | Passed |
| `/dashboard` work queue | Leave and expense approval tasks are visible for the seeded admin path | Passed |

Expected conclusion: the seeded proof tenant still demonstrates inactive connector metadata, mapping readiness, source namespace, and identity reconciliation without enabling runtime sync.

## Safety Checks

| Check | Result |
|-------|--------|
| No demo source pill observed | Passed |
| No connector creation executed | Passed |
| No credential input or storage flow observed | Passed |
| No runtime sync button enabled | Passed |
| No ERP write/export action enabled | Passed |
| Existing no-connector tenant stayed separate from seeded Puls Teknik tenant | Passed |

## Signoff

The remote rollout gate is green for the current PR14 connector onboarding slice:

- PULS Connector Lab proves real no-connector onboarding.
- Puls Teknik proves seeded inactive connector metadata readiness.
- Both routes used live remote UI with `source: real` posture.
- PR14.5 records results only; it adds no app runtime, database mutation, migration, seed CSV/manifest change, credential path, or ERP write path.
