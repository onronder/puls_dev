# PR14.9A Sentry Source Maps And Setup Check

PR14.9A completes the frontend Sentry setup posture after PR14.9 and the SSR hotfix. It adds build-time source map upload and a guarded setup-check event so Sentry can verify the project without adding a visible production error button.

## What PR14.9A Proves

- Source maps can be generated only when explicitly enabled for a CI or Vercel build.
- Source maps are uploaded through the Sentry Vite plugin and deleted from the public asset folder after upload.
- Runtime Sentry remains optional and disabled without `VITE_SENTRY_DSN`.
- The setup-check event is disabled by default and requires both `VITE_SENTRY_ALLOW_TEST_EVENT=true` and `?sentry_setup_check=1`.
- No Sentry DSN, auth token, API key, connector credential, service-role key, or customer payload is committed.

## What PR14.9A Does Not Prove

- No backend Sentry runtime.
- No connector runtime.
- No mapping discovery.
- No import/export execution.
- No ERP write or sync action.

## Build-Time Source Map Contract

Sentry source map upload is build-time only. It runs when all required conditions are present:

| Environment variable | Purpose |
| -------------------- | ------- |
| `SENTRY_SOURCE_MAPS=true` | Explicit opt-in switch for upload. |
| `SENTRY_AUTH_TOKEN` | Sentry build token. Secret; never committed. |
| `SENTRY_ORG` | Sentry organization slug. |
| `SENTRY_PROJECT` | Sentry project slug. |
| `SENTRY_RELEASE` or `VERCEL_GIT_COMMIT_SHA` | Release id used to connect events to artifacts. |

The Vite config sets `build.sourcemap` only when this upload gate is complete. The Sentry plugin uploads `.output/public/assets/**` and then removes `.output/public/assets/**/*.map`, so readable maps are not left as public deploy artifacts.

If source map upload is enabled and Sentry upload fails, the build should fail instead of deploying public `.map` files.

## Setup-Check Event Contract

Sentry's onboarding screen needs at least one captured event. PULS does not add a visible "break the app" button. Instead, a temporary, explicit setup-check path is available:

1. Set `VITE_SENTRY_ALLOW_TEST_EVENT=true` in the target Vercel environment.
2. Redeploy.
3. Visit `/dashboard?sentry_setup_check=1` once.
4. Confirm `PULS Sentry setup check` appears in Sentry.
5. Set `VITE_SENTRY_ALLOW_TEST_EVENT=false` or remove it.
6. Redeploy.

The event uses safe tags only: operation, area, and route. It does not include user identity, tenant UUID, auth token, connector payload, or credentials.

## Acceptance Criteria

- `@sentry/vite-plugin` is installed as a dev dependency.
- `vite.config.ts` gates source map upload behind `SENTRY_SOURCE_MAPS=true` and required Sentry build env.
- Source map files are deleted from public assets after upload.
- `.env.example` documents placeholders only.
- Setup-check capture is disabled by default and requires env plus query param.
- No migrations, seed CSV, manifest, connector runtime, credential storage, or ERP writes are added.
