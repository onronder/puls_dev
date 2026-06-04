import { expect, test } from '@playwright/test'

const email = process.env.E2E_EMAIL
const password = process.env.E2E_PASSWORD
const hasCredentials = Boolean(email && password)
const requireAuth = process.env.E2E_REQUIRE_AUTH === 'true'
const employeeEmail = process.env.E2E_EMPLOYEE_EMAIL
const employeePassword = process.env.E2E_EMPLOYEE_PASSWORD
const hasEmployeeCredentials = Boolean(employeeEmail && employeePassword)

type Credentials = {
  email: string
  password: string
}

function getCredentials(): Credentials {
  if (!email || !password) {
    throw new Error('Set E2E_EMAIL and E2E_PASSWORD for authenticated e2e')
  }
  return { email, password }
}

function getEmployeeCredentials(): Credentials {
  if (!employeeEmail || !employeePassword) {
    throw new Error('Set E2E_EMPLOYEE_EMAIL and E2E_EMPLOYEE_PASSWORD for employee route e2e')
  }
  return { email: employeeEmail, password: employeePassword }
}

async function login(page: import('@playwright/test').Page, credentials = getCredentials()) {
  await page.goto('/login')
  await page.getByLabel(/E-posta|Email/i).fill(credentials.email)
  await page.getByLabel(/Şifre|Password/i).fill(credentials.password)
  await page.getByRole('button', { name: /Giriş Yap|Sign in/i }).click()
  await expect(page).toHaveURL(/\/dashboard/)
}

test('login page renders', async ({ page }) => {
  await page.goto('/login')
  await expect(page.getByRole('heading', { name: /Giriş Yap|Sign in/i })).toBeVisible()
})

test('unauthenticated user redirected to login from dashboard', async ({ page }) => {
  await page.goto('/dashboard')
  await expect(page).toHaveURL(/\/login/)
})

test('unauthenticated redirect preserves path in query', async ({ page }) => {
  await page.goto('/izin')
  await expect(page).toHaveURL(/\/login/)
  await expect(page).toHaveURL(/redirect=.*izin/)
})

test.describe('@auth authenticated stabilization', () => {
  test.skip(
    !hasCredentials && !requireAuth,
    'Set E2E_EMAIL and E2E_PASSWORD for authenticated flows',
  )
  test.describe.configure({ mode: 'serial' })

  test('login honors redirect query', async ({ page }) => {
    const credentials = getCredentials()
    await page.goto('/login?redirect=%2Fayarlar')
    await page.getByLabel(/E-posta|Email/i).fill(credentials.email)
    await page.getByLabel(/Şifre|Password/i).fill(credentials.password)
    await page.getByRole('button', { name: /Giriş Yap|Sign in/i }).click()
    await expect(page).toHaveURL(/\/ayarlar/)
  })

  test('hard refresh stays on protected routes', async ({ page }) => {
    await login(page)

    for (const path of ['/dashboard', '/izin', '/ayarlar']) {
      await page.goto(path)
      await page.reload()
      await expect(page).toHaveURL(new RegExp(path.replace('/', '\\/')))
      await expect(page).not.toHaveURL(/\/login/)
    }
  })

  test('setup route resolves for authenticated account without login bounce', async ({ page }) => {
    await login(page)

    await page.goto('/erp')
    await expect(page).not.toHaveURL(/\/login/)
    await expect(page).toHaveURL(/\/(erp|ayarlar)/)
  })

  test('erp workbench tabs keep connector details navigable', async ({ page }) => {
    await login(page)

    await page.goto('/erp')
    await expect(
      page.getByRole('heading', { name: /Veri bağlantıları|Data connections/i }),
    ).toBeVisible()

    const tabList = page.getByRole('tablist', {
      name: /Veri bağlantısı çalışma alanı|Data connection workspace/i,
    })
    if ((await tabList.count()) === 0) {
      await expect(
        page.getByRole('heading', { name: /Bir kaynak seçerek başla|Start by choosing a source/i }),
      ).toBeVisible()
      return
    }

    await expect(tabList).toBeVisible()
    await page.getByRole('tab', { name: /Alanlar|Fields/i }).click()
    await expect(
      page.getByRole('heading', { name: /Alan sahipliği|Domain ownership/i }),
    ).toBeVisible()

    await page.getByRole('tab', { name: /Kontrol|Check/i }).click()
    await expect(page.getByRole('heading', { name: /Kurulum kontrolü|Setup check/i })).toBeVisible()

    await page.getByRole('tab', { name: /Aktivite|Activity/i }).click()
    await expect(
      page.getByRole('heading', { name: /Aktivite geçmişi|Activity history/i }),
    ).toBeVisible()
  })

  test('employee account blocks setup route', async ({ page }) => {
    test.skip(
      !hasEmployeeCredentials,
      'Set E2E_EMPLOYEE_EMAIL and E2E_EMPLOYEE_PASSWORD for employee route e2e',
    )

    await login(page, getEmployeeCredentials())

    await page.goto('/erp')
    await expect(page).toHaveURL(/\/ayarlar/)
  })

  test('mobile routes avoid horizontal overflow', async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 })
    await login(page)

    for (const path of ['/dashboard', '/izin', '/masraf', '/menu', '/ayarlar', '/erp']) {
      await page.goto(path)
      const overflow = await page.evaluate(
        () => document.documentElement.scrollWidth > document.documentElement.clientWidth,
      )
      expect(overflow, `${path} should not overflow horizontally`).toBe(false)
    }
  })
})
