import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { jsonResponse, stubFetch } from './fetchStub'
import { configureAuth } from '../http'
import { portalService } from '../portal'

const apps = [{ uid: 'app_1', kind: 'oidc', name: 'Web shop', launch_url: 'https://shop.test' }]

describe('portalService', () => {
  beforeEach(() => {
    vi.stubEnv('VITE_CONSOLE_URL', window.location.origin)
    vi.stubEnv('VITE_API_BASE_URL', 'https://api.test')
  })

  afterEach(() => {
    vi.unstubAllGlobals()
    vi.unstubAllEnvs()
    configureAuth(null)
  })

  it("lists the end user's apps with the portal's own token", async () => {
    const { fetchMock, sent } = stubFetch()
    fetchMock.mockResolvedValue(jsonResponse(apps))

    await expect(portalService.apps('acc_1', 'prj_1', 'portal-token')).resolves.toEqual(apps)

    expect(sent().url).toBe('https://api.test/v1/accounts/acc_1/projects/prj_1/portal/apps')
    expect(sent().headers.get('Authorization')).toBe('Bearer portal-token')
  })

  it('says when the portal session has expired, or the apps are unavailable', async () => {
    const { fetchMock } = stubFetch()
    fetchMock.mockResolvedValueOnce(jsonResponse({ error: { code: 'invalid_token' } }, 401))
    fetchMock.mockResolvedValueOnce(jsonResponse({ error: { code: 'internal_error' } }, 500))
    fetchMock.mockRejectedValueOnce(new TypeError('Failed to fetch'))

    await expect(portalService.apps('acc_1', 'prj_1', 'old-token')).rejects.toMatchObject({ code: 'invalid_token', reason: 'portal_session_expired' })
    await expect(portalService.apps('acc_1', 'prj_1', 'portal-token')).rejects.toMatchObject({ code: 'internal_error', reason: 'apps_unavailable' })
    await expect(portalService.apps('acc_1', 'prj_1', 'portal-token')).rejects.toMatchObject({ code: 'network_error' })
  })

  it("uses the portal's token, never the console session's, for the end user's own data", async () => {
    configureAuth({ getAccessToken: () => 'console-token', refreshAccessToken: vi.fn<() => Promise<boolean>>() })
    const { fetchMock, sent } = stubFetch()
    fetchMock.mockImplementation(async () => jsonResponse([], 200, { Total: '0', 'Per-Page': '25' }))

    await portalService.sessions('acc_1', 'prj_1', 'portal-token', { page: 2 })
    expect(sent().url).toBe('https://api.test/v1/accounts/acc_1/projects/prj_1/me/sessions?page=2')
    expect(sent().headers.get('Authorization')).toBe('Bearer portal-token')

    await portalService.updateLocale('acc_1', 'prj_1', 'portal-token', 'ja')
    expect(sent()).toMatchObject({ method: 'PATCH', body: { locale: 'ja' } })
    expect(sent().headers.get('Authorization')).toBe('Bearer portal-token')
  })

  it('calls the endpoints at the root of a custom domain', async () => {
    vi.stubEnv('VITE_CONSOLE_URL', 'https://console.example.test')
    const { fetchMock, sent } = stubFetch()
    fetchMock.mockResolvedValue(jsonResponse({}))

    await portalService.config('acc_1', 'prj_1')

    expect(sent().url).toBe('/portal')
  })
})
