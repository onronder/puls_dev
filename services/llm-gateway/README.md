# llm-gateway — Service Boundary

Health-only skeleton for future AI Coach LLM gateway. **Not used by app runtime in PR13.7.**

## Posture

| Property              | Value                                                    |
| --------------------- | -------------------------------------------------------- |
| Version               | `0.1.0-skeleton`                                         |
| Runtime               | Health endpoint only (`GET` → JSON `{ status: "ok" }`)   |
| App integration       | None — `/ai-koc` uses DB context readiness adapters only |
| Production deployment | Not expected in PR13.7                                   |

## What this service is

**llm-gateway is a future service-boundary hint**, not a live PR13.7 runtime.

Future PR will wire tenant-scoped context from PR13.6 read models and enforce PR13.7 action boundaries before any tool invocation.

## What this service is not

- Not a live chat endpoint
- Not an OpenAI/API client in MVP
- No API keys or tokens in this repo
- No autonomous workflow mutations

## AI Coach guardrails (PR13.7)

- AI Coach may suggest, explain, and draft; humans confirm every workflow action
- No live chat in PR13.7 — `/ai-koc` remains context readiness + guardrails teaser
- Source disclosure required for all data references

## Observability

PR14.9 defines the Sentry posture for future backend diagnostics, but this service remains health-only. When runtime begins, telemetry must use scrubbed route/action/status context only; prompts, auth tokens, customer records, API keys, and tool payloads must never be attached raw.

## Local dev (skeleton only)

```bash
cd services/llm-gateway
node --import tsx src/index.ts
# curl http://localhost:8080 → { "service": "llm-gateway", "status": "ok", ... }
```

## References

- [`docs/product/13_ai_coach_action_boundary.md`](../../docs/product/13_ai_coach_action_boundary.md)
- [`docs/product/13_ai_coach_db_context_readiness.md`](../../docs/product/13_ai_coach_db_context_readiness.md)
- [`docs/product/14_error_observability_sentry.md`](../../docs/product/14_error_observability_sentry.md)
