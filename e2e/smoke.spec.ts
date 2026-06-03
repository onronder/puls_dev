import { expect, test } from '@playwright/test'

async function expectRedirectToLogin(page: import('@playwright/test').Page) {
  await expect(page).toHaveURL(/\/login/, { timeout: 10000 })
}

test('login page renders', async ({ page }) => {
  await page.goto('/login')
  await expect(page.getByRole('heading', { name: /Giriş Yap|Sign in/i })).toBeVisible()
})

test('unauthenticated user redirected to login from dashboard', async ({ page }) => {
  await page.goto('/dashboard')
  await expectRedirectToLogin(page)
})

test('unauthenticated user redirected from performans', async ({ page }) => {
  await page.goto('/performans')
  await expectRedirectToLogin(page)
})
