import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { jsonResponse, stubFetch } from './fetchStub'
import { authService, isChallenge } from '../auth'
import { endUserAuthService } from '../endUserAuth'
import { configureAuth } from '../http'
import { hostedLoginService } from '../hostedLogin'

describe('sign-in services', () => {
  beforeEach(() => {
    vi.stubEnv('VITE_CONSOLE_URL', window.location.origin)
    vi.stubEnv('VITE_API_BASE_URL', 'https://api.test')
    // Signing in must never send an existing console session along.
    configureAuth({ getAccessToken: () => 'console-token', refreshAccessToken: vi.fn<() => Promise<boolean>>() })
  })

  afterEach(() => {
    vi.unstubAllGlobals()
    vi.unstubAllEnvs()
    configureAuth(null)
  })

  it("signs console users in to their account, without any session's token", async () => {
    const { fetchMock, sent } = stubFetch()
    fetchMock.mockResolvedValue(jsonResponse({ access_token: 'at', refresh_token: 'rt', token_type: 'Bearer', expires_in: 900 }))

    await authService.signIn('acc_1', 'olive@acme.test', 'secret')

    expect(sent()).toMatchObject({ url: 'https://api.test/v1/accounts/acc_1/auth/sign-in', method: 'POST', body: { email: 'olive@acme.test', password: 'secret' } })
    expect(sent().headers.get('Authorization')).toBeNull()
  })

  it('looks accounts up by an alias made safe for the URL', async () => {
    const { fetchMock, sent } = stubFetch()
    fetchMock.mockResolvedValue(jsonResponse({ uid: 'acc_1', name: 'Acme', slug: 'acme' }))

    await authService.lookupAccount('acme/../admin')

    expect(sent().url).toBe('https://api.test/v1/account-lookup/acme%2F..%2Fadmin')
  })

  it('tells a challenge from finished tokens', () => {
    expect(isChallenge({ challenge: 'otp', session: 's' })).toBe(true)
    expect(isChallenge({ access_token: 'at', refresh_token: 'rt', token_type: 'Bearer', expires_in: 900 })).toBe(false)
  })

  it("signs end users in through the app's client, sending its credentials", async () => {
    const { fetchMock, sent } = stubFetch()
    fetchMock.mockResolvedValue(jsonResponse({ challenge: 'otp', session: 's' }))

    await endUserAuthService.respondToChallenge({ accountUid: 'acc_1', projectUid: 'prj_1' }, { client_id: 'app_1', client_secret: 'shh' }, { challenge: 'otp', session: 's', code: '123456' })

    expect(sent()).toMatchObject({
      url: 'https://api.test/v1/accounts/acc_1/projects/prj_1/auth/respond-to-challenge',
      body: { client_id: 'app_1', client_secret: 'shh', challenge: 'otp', session: 's', code: '123456' },
    })
    expect(sent().headers.get('Authorization')).toBeNull()
  })

  it('addresses hosted login steps by their interaction, made safe for the URL', async () => {
    const { fetchMock, sent } = stubFetch()
    fetchMock.mockResolvedValue(jsonResponse(undefined, 204))

    await hostedLoginService.confirmSignUp({ accountUid: 'acc_1', projectUid: 'prj_1', interaction: 'int/1' }, 'casey@shop.test', '123456')

    expect(sent()).toMatchObject({
      url: 'https://api.test/v1/accounts/acc_1/projects/prj_1/oauth2/interactions/int%2F1/confirm-sign-up',
      method: 'POST',
      body: { email: 'casey@shop.test', code: '123456' },
    })
    expect(sent().headers.get('Authorization')).toBeNull()
  })
})
