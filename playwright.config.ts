import { defineConfig, devices } from '@playwright/test'

const baseURL = process.env.E2E_BASE_URL ?? 'http://localhost:3000'
const useExternalServer = Boolean(process.env.E2E_BASE_URL)

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  workers: process.env.E2E_REQUIRE_AUTH === 'true' ? 1 : undefined,
  retries: process.env.CI ? 1 : 0,
  use: {
    baseURL,
    trace: 'on-first-retry',
  },
  ...(useExternalServer
    ? {}
    : {
        webServer: {
          command: 'pnpm dev',
          url: baseURL,
          reuseExistingServer: !process.env.CI,
        },
      }),
  projects: [
    {
      name: 'mobile',
      use: { ...devices['Pixel 5'] },
    },
    { name: 'tablet', use: { viewport: { width: 768, height: 1024 } } },
    { name: 'desktop', use: { viewport: { width: 1280, height: 800 } } },
  ],
})
