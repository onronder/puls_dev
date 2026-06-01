import { expect, test, type Page } from '@playwright/test'

const requireAuth = process.env.E2E_REQUIRE_AUTH === 'true'

type RoleKey = 'admin' | 'hr' | 'manager' | 'employee' | 'connectorAdmin'
type Credentials = {
  email: string
  password: string
}

const ROLE_ENV: Record<RoleKey, { email: string; password: string; label: string }> = {
  admin: {
    email: 'E2E_ADMIN_EMAIL',
    password: 'E2E_ADMIN_PASSWORD',
    label: 'admin',
  },
  hr: {
    email: 'E2E_HR_EMAIL',
    password: 'E2E_HR_PASSWORD',
    label: 'HR admin',
  },
  manager: {
    email: 'E2E_MANAGER_EMAIL',
    password: 'E2E_MANAGER_PASSWORD',
    label: 'manager',
  },
  employee: {
    email: 'E2E_EMPLOYEE_EMAIL',
    password: 'E2E_EMPLOYEE_PASSWORD',
    label: 'employee',
  },
  connectorAdmin: {
    email: 'E2E_CONNECTOR_ADMIN_EMAIL',
    password: 'E2E_CONNECTOR_ADMIN_PASSWORD',
    label: 'connector admin',
  },
}

function readEnv(name: string) {
  return process.env[name]?.trim() || undefined
}

function getRoleCredentials(role: RoleKey): Credentials {
  const config = ROLE_ENV[role]
  const fallbackEmail = role === 'admin' ? readEnv('E2E_EMAIL') : undefined
  const fallbackPassword = role === 'admin' ? readEnv('E2E_PASSWORD') : undefined
  const email = readEnv(config.email) ?? fallbackEmail
  const password = readEnv(config.password) ?? fallbackPassword

  if (!email || !password) {
    throw new Error(`Set ${config.email} and ${config.password} for ${config.label} e2e`)
  }

  return { email, password }
}

function hasAdminCredentials() {
  return Boolean((readEnv('E2E_ADMIN_EMAIL') && readEnv('E2E_ADMIN_PASSWORD')) || (readEnv('E2E_EMAIL') && readEnv('E2E_PASSWORD')))
}

async function login(page: Page, credentials: Credentials) {
  await page.goto('/login')
  await page.getByLabel(/E-posta|Email/i).fill(credentials.email)
  await page.getByLabel(/Şifre|Password/i).fill(credentials.password)
  await page.getByRole('button', { name: /Giriş Yap|Sign in/i }).click()
  await expect(page).toHaveURL(/\/dashboard/)
}

test.describe('@auth role and tenant posture matrix', () => {
  test.skip(!hasAdminCredentials() && !requireAuth, 'Set e2e role credentials for live auth matrix')
  test.describe.configure({ mode: 'serial' })

  test('seeded admin sees operational Puls Teknik posture', async ({ page }) => {
    await login(page, getRoleCredentials('admin'))

    await expect(page.getByText(/Puls Teknik/i)).toBeVisible()
    await expect(page.getByText(/Canias/i).first()).toBeVisible()
    await expect(page.getByText(/100%|%100/).first()).toBeVisible()

    await page.goto('/erp')
    await expect(page).not.toHaveURL(/\/login/)
    await expect(page.getByText(/Canias/i).first()).toBeVisible()
    await expect(page.getByText(/12\s*\/\s*12/).first()).toBeVisible()
  })

  test('connector admin sees first-run empty dashboard and setup wizard', async ({ page }) => {
    await login(page, getRoleCredentials('connectorAdmin'))

    await expect(page.getByText(/PULS Connector Lab/i)).toBeVisible()
    await expect(page.getByText(/Kurulum bekliyor|Setup pending/i)).toBeVisible()
    await expect(page.getByRole('link', { name: /Veri kaynağını seç|Choose data source/i })).toBeVisible()
    await expect(page.getByText(/Kaynak yok|No source/i).first()).toBeVisible()

    await page.goto('/erp')
    await expect(page).not.toHaveURL(/\/login/)
    await expect(page.getByRole('heading', { name: /Bağlantı kurulumu|Connection setup/i })).toBeVisible()
    await expect(page.getByText(/Kaynak tanımlı değil|Source not selected/i).first()).toBeVisible()
    await expect(page.getByText(/1\. Veri kaynağını seç|1\. Choose data source/i)).toBeVisible()
    await expect(page.getByText(/Canias/i).first()).toBeVisible()
    await expect(page.getByText(/Logo/i).first()).toBeVisible()
    await expect(page.getByText(/CSV \/ Excel/i).first()).toBeVisible()
  })

  test('HR admin reaches people operations without setup bounce', async ({ page }) => {
    await login(page, getRoleCredentials('hr'))

    await page.goto('/calisanlar')
    await expect(page).not.toHaveURL(/\/login/)
    await expect(page.getByRole('heading', { name: /Çalışanlar|Employees/i })).toBeVisible()
  })

  test('manager can switch to manager performance scope', async ({ page }) => {
    await login(page, getRoleCredentials('manager'))

    await page.goto('/performans')
    const managerToggle = page.getByRole('button', { name: /Yönetici Modu|Manager mode/i })
    if (await managerToggle.isVisible()) {
      await managerToggle.click()
    }

    await expect(page.getByRole('button', { name: /Yönetici Modu|Manager mode/i })).toBeVisible()
    await expect(page.getByText(/Kapsam|Scope/i).first()).toBeVisible()
    await expect(page.getByText(/^16$/).first()).toBeVisible()
  })

  test('employee remains self-scoped and cannot access setup routes', async ({ page }) => {
    await login(page, getRoleCredentials('employee'))

    await page.goto('/performans')
    await expect(page.getByRole('button', { name: /Çalışan Modu|Employee mode/i })).toBeVisible()
    await expect(page.getByText(/Kapsam|Scope/i).first()).toBeVisible()
    await expect(page.getByText(/^1$/).first()).toBeVisible()

    await page.goto('/erp')
    await expect(page).toHaveURL(/\/ayarlar/)
  })
})
