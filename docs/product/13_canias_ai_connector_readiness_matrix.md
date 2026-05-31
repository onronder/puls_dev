# PR13.7 — Canias AI Connector Readiness Matrix

Maps Canias connector readiness to AI Coach touchpoints across PULS routes. **Documentation-only** — defines allowed/forbidden AI actions per surface.

**PR13.7 is connector discovery and action-boundary readiness, not runtime integration.**

## Executive summary

This matrix ties PR13.4–13.6 seeded Canias metadata and PR13.6 DB context readiness to PR13.7 action boundaries. AI Coach may explain and draft; humans confirm every workflow action. No sync, no ERP writes, no live chat.

## Touchpoint matrix

| Touchpoint | Route | Canias context used | AI Coach allowed | AI Coach forbidden |
|------------|-------|---------------------|------------------|-------------------|
| ERP readiness | `/erp` | connection, mappings, namespace | explain mapping gaps | sync/write |
| Setup coach | `/sirket-kurulum` | setup readiness + Canias metadata | summarize gaps | mutate setup |
| Org data quality | `/departmanlar`, `/pozisyonlar`, `/calisanlar` | imported source labels | explain read-only rows | edit imported rows |
| Leave helper | `/izin` | optional export candidate | explain export readiness | auto-submit/export |
| Expense helper | `/masraf` | optional export candidate | explain export readiness | auto-submit/export |
| Dashboard insight | `/dashboard` | Canias inactive readiness | summarize posture | trigger sync |
| AI Coach home | `/ai-koc` | all context readiness | show guardrails | live chat/action |
| Admin/settings | `/ayarlar` | future connector config | explain boundary | store credentials |

## Route notes

### `/erp`

- Reads inactive Canias connection + sample field mappings (read-only)
- AI may explain mapping coverage gaps and inactive posture
- Forbidden: `sync_canias_now`, `write_to_canias`, credential storage

### `/ai-koc`

- PR13.6 DB context readiness (8 domains) + guardrails
- PR13.7 action boundary documented — no live chat, no autonomous actions
- Forbidden: positive chat-enablement patterns, workflow mutation RPCs, auto-approvals

### Org routes

- Imported rows (`external_source=canias`) are read-only per PR11.2
- AI may explain why a row cannot be edited
- Forbidden: AI-initiated edits to imported departments/positions

## Guardrails (all touchpoints)

- **Source disclosure is required**
- **no autonomous mutations**
- **no auto-approvals**
- **no ERP writes**
- **no credentials** in repo or AI responses

## References

- [`13_canias_connector_discovery.md`](./13_canias_connector_discovery.md)
- [`13_ai_coach_action_boundary.md`](./13_ai_coach_action_boundary.md)
- [`13_route_packaging_proof_matrix.md`](./13_route_packaging_proof_matrix.md)
