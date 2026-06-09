# PR16.10.15 Route Boundary & HR Cache Hardening

## Goal

Close two pre-PR17 product reliability debts without changing HR domain behavior:

- a single app route error must not take down the authenticated shell;
- department and position mutations must refresh the HR views that depend on org structure.

## Scope

- Keep the root app error boundary for provider/layout failures.
- Add an `_app` route-level boundary around the route outlet so header, sidebar, bottom navigation, and the AI button remain available after a page-level render crash.
- Reset the route boundary on pathname change.
- Add a shared org-structure query invalidation helper.
- Use the helper after department and position create/update mutations.
- Add unit coverage for the invalidation contract.

## Safety Boundary

This PR does not change:

- database schema or Supabase migrations;
- connector runtime, DataSource Manager, canonical apply, notification, or worker behavior;
- department or position mutation payloads;
- visible product copy.

## Acceptance

- `src/routes/_app.tsx` wraps only the route `<Outlet />` in `AppErrorBoundary`.
- `src/routes/__root.tsx` keeps the root boundary.
- Department and position save success paths call `invalidateOrgStructureQueries`.
- The helper invalidates departments, positions, employee assignment readiness, employee leave overview, dashboard overview, and setup readiness.
- Typecheck, tests, lint, i18n, build, and the PR16.10.15 verify gate pass.
