# 07 Demo Auth & Org Bootstrap

Repeatable live smoke setup for Mert Teknik demo tenant after `supabase db push` applies migrations through `20260524150000`.

## Demo org chart (single root)

```text
Demo Genel Müdür (44444444-4444-4444-4444-444444444402) — no manager
  ├─ Demo İK Yöneticisi (44444444-4444-4444-4444-444444444401)
  │   └─ Demo İK Uzmanı (44444444-4444-4444-4444-444444444405)
  └─ Demo Yönetici (44444444-4444-4444-4444-444444444404)
      └─ Demo Çalışan (44444444-4444-4444-4444-444444444403)
```

Reporting lines are backfilled by migration `20260524140000`. GM does not require an auth user.

## Step A — Create auth users (Supabase Dashboard)

Do **not** store passwords in the repo. Create users under Authentication → Users:

| Email | Persona | Notes |
|---|---|---|
| `demo@mertteknik.local` | Demo İK Yöneticisi (hr_admin) | Primary demo admin |
| `yonetici@mertteknik.demo` | Demo Yönetici (manager) | Approval smoke |
| `calisan@mertteknik.demo` | Demo Çalışan (employee) | Requester smoke |
| `o.onder@fittechs.com` | Live operator | Staging smoke |

## Step B — Link auth users to employees

Replace `<AUTH_USER_UUID>` placeholders with IDs from the Dashboard, then run in SQL Editor:

```sql
-- Demo Yönetici
UPDATE public.employees
SET user_id = '<YONETICI_AUTH_UUID>'
WHERE anonymous_id = '44444444-4444-4444-4444-444444444404';

UPDATE puls_core.employees
SET user_id = '<YONETICI_AUTH_UUID>', updated_at = NOW()
WHERE legacy_public_employee_id = '44444444-4444-4444-4444-444444444404';

-- Demo Çalışan
UPDATE public.employees
SET user_id = '<CALISAN_AUTH_UUID>'
WHERE anonymous_id = '44444444-4444-4444-4444-444444444403';

UPDATE puls_core.employees
SET user_id = '<CALISAN_AUTH_UUID>', updated_at = NOW()
WHERE legacy_public_employee_id = '44444444-4444-4444-4444-444444444403';

-- Tenant + role (example: yonetici)
INSERT INTO public.user_tenants (user_id, tenant_id, is_default)
VALUES ('<YONETICI_AUTH_UUID>', '11111111-1111-1111-1111-111111111111', TRUE)
ON CONFLICT DO NOTHING;

INSERT INTO public.user_roles (user_id, tenant_id, role)
VALUES ('<YONETICI_AUTH_UUID>', '11111111-1111-1111-1111-111111111111', 'yonetici')
ON CONFLICT DO NOTHING;
```

Repeat `user_tenants` / `user_roles` for each linked user with the appropriate role.

## Step C — Verify org authority

```sql
SELECT e.full_name, e.manager_employee_id, rl.manager_employee_id AS line_manager
FROM puls_core.employees e
LEFT JOIN puls_core.employee_reporting_lines rl
  ON rl.employee_id = e.id
 AND rl.is_active = TRUE
 AND rl.relationship_type = 'primary_manager'
WHERE e.legacy_public_employee_id IN (
  '44444444-4444-4444-4444-444444444402',
  '44444444-4444-4444-4444-444444444401',
  '44444444-4444-4444-4444-444444444405',
  '44444444-4444-4444-4444-444444444404',
  '44444444-4444-4444-4444-444444444403'
)
ORDER BY e.full_name;
```

GM should have `manager_employee_id IS NULL`. All other rows should have matching cache and reporting line.

## Live smoke checklist

1. Log in as `yonetici@mertteknik.demo` → `/izin` approval tab shows requester **name** (not `—`).
2. Log in as `calisan@mertteknik.demo` → create leave → approver resolves to org manager (Demo Genel Müdür or chain per policy), not persona lottery.
3. Log in as `o.onder@fittechs.com` → admin paths unchanged.

See also [`07_org_authority_smoke.sql`](07_org_authority_smoke.sql).
