import { test as base, expect } from '@playwright/test'

import { mockConsole, type ConsoleOptions } from './console'
import * as fixtures from './fixtures'
import { MockApi } from './mockApi'
import type { Me } from '@/types/api'

interface Fixtures {
  api: MockApi
  /** Starts the console signed in, the way a returning user's saved session does, with the console's calls mocked. */
  signIn: (options?: ConsoleOptions) => Promise<{ user: Me; base: string }>
}

export const test = base.extend<Fixtures>({
  api: async ({ page }, use) => {
    const api = new MockApi(page)
    await api.install()
    await use(api)
    expect(api.unhandled, 'API requests without a mock').toEqual([])
  },

  signIn: async ({ page, api }, use) => {
    await use(async (options = {}) => {
      const { uid, name, slug } = (options.user ?? fixtures.me()).account
      // Once per tab, so signing out and reloading stays signed out.
      await page.addInitScript((session) => {
        if (sessionStorage.getItem('e2e.signed-in')) return
        sessionStorage.setItem('e2e.signed-in', 'true')
        localStorage.setItem('x-identity.session', JSON.stringify(session))
        localStorage.setItem('x-identity.last-account', JSON.stringify(session.account.slug))
      }, { account: { uid, name, slug }, refreshToken: 'refresh-token' })
      api.on('POST', `/v1/accounts/${uid}/auth/refresh`, { body: fixtures.tokens() })
      return mockConsole(api, options)
    })
  },
})

export { expect }
