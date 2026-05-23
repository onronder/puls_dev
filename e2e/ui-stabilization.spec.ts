import { expect, test } from '@playwright/test'

const email = process.env.E2E_EMAIL
const password = process.env.E2E_PASSWORD
const hasCredentials = Boolean(email && password)

async function login(page: import('@playwright/test').Page) {
  await page.goto('/login')
  await page.getByLabel(/E-posta|Email/i).fill(email!)
  await page.getByLabel(/Şifre|Password/i).fill(password!)
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

test.describe('authenticated stabilization', () => {
  test.skip(!hasCredentials, 'Set E2E_EMAIL and E2E_PASSWORD for authenticated flows')

  test('login honors redirect query', async ({ page }) => {
    await page.goto('/login?redirect=%2Fayarlar')
    await page.getByLabel(/E-posta|Email/i).fill(email!)
    await page.getByLabel(/Şifre|Password/i).fill(password!)
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

  test('employee mode blocks setup route', async ({ page }) => {
    await login(page)

    const employeeToggle = page.getByRole('button', { name: /Çalışan Modu|Employee mode/i })
    if (await employeeToggle.isVisible()) {
      await employeeToggle.click()
    }

    await page.goto('/erp')
    await expect(page).toHaveURL(/\/ayarlar/)
  })

  test('mobile routes avoid horizontal overflow', async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 })
    await login(page)

    for (const path of ['/dashboard', '/izin', '/masraf', '/menu', '/ayarlar']) {
      await page.goto(path)
      const overflow = await page.evaluate(
        () => document.documentElement.scrollWidth > document.documentElement.clientWidth,
      )
      expect(overflow, `${path} should not overflow horizontally`).toBe(false)
    }
  })
})
