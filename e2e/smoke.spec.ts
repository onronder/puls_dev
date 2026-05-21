import { expect, test } from '@playwright/test'

test('login page renders', async ({ page }) => {
  await page.goto('/login')
  await expect(page.getByRole('heading', { name: /Giriş Yap|Sign in/i })).toBeVisible()
})

test('unauthenticated user redirected to login from dashboard', async ({ page }) => {
  await page.goto('/dashboard')
  await expect(page).toHaveURL(/\/login/)
})

test('unauthenticated user redirected from performans', async ({ page }) => {
  await page.goto('/performans')
  await expect(page).toHaveURL(/\/login/)
})
