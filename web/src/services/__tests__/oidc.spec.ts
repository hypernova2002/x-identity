import { afterEach, describe, expect, it, vi } from 'vitest'

import { jsonResponse, stubFetch } from './fetchStub'
import { ApiError } from '../http'
import { oidcService } from '../oidc'

const issuer = 'https://login.shop.test'

describe('oidcService', () => {
  afterEach(() => vi.unstubAllGlobals())

  it('builds an authorization request with PKCE, asking for a fresh sign-in only when told to', () => {
    const request = { clientId: 'app_1', redirectUri: 'https://shop.test/callback', scope: 'openid email', state: 'st', nonce: 'nn', codeChallenge: 'cc' }

    const url = new URL(oidcService.authorizeUrl(issuer, request))

    expect(`${url.origin}${url.pathname}`).toBe(`${issuer}/oauth2/authorize`)
    expect(Object.fromEntries(url.searchParams)).toEqual({
      response_type: 'code',
      client_id: 'app_1',
      redirect_uri: 'https://shop.test/callback',
      scope: 'openid email',
      state: 'st',
      nonce: 'nn',
      code_challenge: 'cc',
      code_challenge_method: 'S256',
    })
    expect(new URL(oidcService.authorizeUrl(issuer, { ...request, prompt: 'login' })).searchParams.get('prompt')).toBe('login')
  })

  it('logs out, returning to the app when one is given', () => {
    expect(oidcService.logoutUrl(issuer)).toBe(`${issuer}/oauth2/logout`)
    expect(oidcService.logoutUrl(issuer, { clientId: 'app_1', postLogoutRedirectUri: 'https://shop.test/bye' })).toBe(
      `${issuer}/oauth2/logout?client_id=app_1&post_logout_redirect_uri=https%3A%2F%2Fshop.test%2Fbye`,
    )
  })

  describe('exchanging a code', () => {
    const exchange = { clientId: 'app_1', code: 'code-1', codeVerifier: 'verifier-1', redirectUri: 'https://shop.test/callback' }

    it('posts the code and verifier as a form, as a public client', async () => {
      const { fetchMock, sent } = stubFetch()
      fetchMock.mockResolvedValue(jsonResponse({ access_token: 'at', refresh_token: 'rt', token_type: 'Bearer', expires_in: 900 }))

      await expect(oidcService.exchangeCode(issuer, exchange)).resolves.toMatchObject({ access_token: 'at' })

      expect(sent()).toMatchObject({
        url: `${issuer}/oauth2/token`,
        method: 'POST',
        body: { grant_type: 'authorization_code', client_id: 'app_1', code: 'code-1', code_verifier: 'verifier-1', redirect_uri: 'https://shop.test/callback' },
      })
      expect(sent().headers.get('Authorization')).toBeNull()
    })

    it('turns an OAuth error into an ApiError with its code', async () => {
      stubFetch().fetchMock.mockResolvedValue(jsonResponse({ error: 'invalid_grant', error_description: 'expired' }, 400))

      await expect(oidcService.exchangeCode(issuer, exchange)).rejects.toMatchObject({ code: 'invalid_grant', status: 400 })
    })

    it("reports a response it can't read, and a network failure", async () => {
      const { fetchMock } = stubFetch()
      fetchMock.mockResolvedValueOnce(new Response('<html>Bad gateway</html>', { status: 502 }))
      fetchMock.mockRejectedValueOnce(new TypeError('Failed to fetch'))

      await expect(oidcService.exchangeCode(issuer, exchange)).rejects.toMatchObject({ code: 'internal_error', status: 502 })
      const offline = await oidcService.exchangeCode(issuer, exchange).catch((caught: unknown) => caught)
      expect(offline).toBeInstanceOf(ApiError)
      expect(offline).toMatchObject({ code: 'network_error' })
    })
  })
})
