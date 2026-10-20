import { afterEach, describe, expect, it, vi } from 'vitest'

import { ApiError, apiPage, apiRequest, configureAuth } from '../http'

function jsonResponse(body: unknown, status: number, headers: Record<string, string> = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...headers },
  })
}

function stubFetch() {
  const fetchMock = vi.fn<typeof fetch>()
  vi.stubGlobal('fetch', fetchMock)
  return fetchMock
}

const invalidToken = { error: { code: 'invalid_token', message: 'The token is invalid or has expired.', details: [] } }

describe('apiRequest', () => {
  afterEach(() => {
    vi.unstubAllGlobals()
    configureAuth(null)
  })

  it('returns the parsed body on success', async () => {
    stubFetch().mockResolvedValue(jsonResponse({ uid: 'proj_1' }, 200))

    await expect(apiRequest('/v1/projects/proj_1')).resolves.toEqual({ uid: 'proj_1' })
  })

  it('throws an ApiError built from the standard error body', async () => {
    const body = {
      error: {
        code: 'validation_failed',
        message: 'One or more fields are invalid.',
        details: [{ field: 'email', message: 'is invalid' }],
      },
    }
    stubFetch().mockResolvedValue(jsonResponse(body, 422))

    await expect(apiRequest('/v1/accounts')).rejects.toMatchObject({
      code: 'validation_failed',
      status: 422,
      details: [{ field: 'email', message: 'is invalid' }],
    })
  })

  it('throws a network_error ApiError when the request cannot be sent', async () => {
    stubFetch().mockRejectedValue(new TypeError('Failed to fetch'))

    const error = await apiRequest('/v1/accounts').catch((caught: unknown) => caught)

    expect(error).toBeInstanceOf(ApiError)
    expect((error as ApiError).code).toBe('network_error')
  })

  it('sends the access token on authenticated requests', async () => {
    const fetchMock = stubFetch().mockResolvedValue(jsonResponse({}, 200))
    configureAuth({ getAccessToken: () => 'token-1', refreshAccessToken: vi.fn<() => Promise<boolean>>() })

    await apiRequest('/v1/accounts/acct_1/me', { authenticated: true })

    const headers = fetchMock.mock.calls[0]?.[1]?.headers as Headers
    expect(headers.get('Authorization')).toBe('Bearer token-1')
  })

  it('refreshes once and retries when the access token is rejected', async () => {
    let token = 'expired'
    stubFetch()
      .mockResolvedValueOnce(jsonResponse(invalidToken, 401))
      .mockResolvedValueOnce(jsonResponse({ uid: 'usr_1' }, 200))
    configureAuth({
      getAccessToken: () => token,
      refreshAccessToken: vi.fn<() => Promise<boolean>>(async () => {
        token = 'fresh'
        return true
      }),
    })

    await expect(apiRequest('/v1/accounts/acct_1/me', { authenticated: true })).resolves.toEqual({ uid: 'usr_1' })
  })

  it('gives up when the refresh fails', async () => {
    stubFetch().mockResolvedValue(jsonResponse(invalidToken, 401))
    configureAuth({ getAccessToken: () => 'expired', refreshAccessToken: vi.fn<() => Promise<boolean>>().mockResolvedValue(false) })

    await expect(apiRequest('/v1/accounts/acct_1/me', { authenticated: true })).rejects.toMatchObject({ code: 'invalid_token' })
  })
})

describe('apiPage', () => {
  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('reads pagination metadata from the response headers', async () => {
    stubFetch().mockResolvedValue(jsonResponse([{ uid: 'usr_1' }], 200, { Total: '30', 'Per-Page': '25' }))

    await expect(apiPage('/v1/accounts/acct_1/users')).resolves.toEqual({ items: [{ uid: 'usr_1' }], total: 30, perPage: 25 })
  })
})
