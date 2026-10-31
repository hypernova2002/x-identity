import { defineConfig, devices } from '@playwright/test'

import { API_ORIGIN, APP_ORIGIN, APP_PORT } from './e2e/support/origins'

// Browser tests run the production build against a mocked API (see e2e/support/mockApi.ts).
export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [['list'], ['html', { open: 'never' }]] : 'list',
  use: {
    baseURL: APP_ORIGIN,
    locale: 'en-GB',
    trace: 'retain-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: {
    command: `vite build --outDir dist-e2e && vite preview --outDir dist-e2e --port ${APP_PORT} --strictPort`,
    url: APP_ORIGIN,
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    env: { VITE_API_BASE_URL: API_ORIGIN, VITE_CONSOLE_URL: APP_ORIGIN },
  },
})
