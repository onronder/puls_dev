# PR16.9.7x Settings Notification Status Hotfix

PR16.9.7x aligns `/ayarlar` with the app-wide Notification Center preference UI shipped in
PR16.9.7.

## Problem

Live smoke on `/ayarlar` showed:

- `Bildirim tercihleri`
- status `Kapalı`
- value `Kural seti bekliyor`

That state was stale. PR16.9.7 made source-scoped in-app notification preferences usable
from the Notification Center, while email, mobile push, and external delivery intentionally
remain closed.

## Fix

- Tenant-scoped settings overview now marks the notification preferences section as
  `ready`.
- The card value is `settingsSetup.values.enabled`.
- The helper copy points to the Notification Center as the active preference surface.
- The no-tenant path remains `locked`, because notification scope cannot be resolved
  without tenant context.

## Safety

- No database schema, RLS, grants, or RPC contract changes.
- No external delivery, email, push, provider call, credential readback, or source writeback.
- No direct authenticated table writes.
- This is a settings overview state alignment only.

## Verification

```bash
scripts/verify-16-9-7x-settings-notification-status-hotfix.sh WORKTREE
pnpm test -- src/lib/data/settings/overview.test.ts
pnpm check-i18n
pnpm typecheck
pnpm build
```

Browser smoke:

- `/ayarlar` loads for an authenticated tenant user.
- `Bildirim tercihleri` shows `Hazır`.
- The notification card value shows `Açık`.
- No-tenant adapter coverage keeps the notification card `locked`.
- No notification-related console errors are introduced.
