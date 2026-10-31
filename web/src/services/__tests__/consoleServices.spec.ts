import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { jsonResponse, stubFetch } from './fetchStub'
import { meService, projectService, userService } from '../account'
import { configureAuth } from '../http'
import { projectAdminService } from '../project'

const endUser = {
  uid: 'eu_1',
  email: 'casey@shop.test',
  name: null,
  status: 'active',
  email_verified: true,
  mfa_enabled: false,
  invitation_pending: false,
  groups: [],
  custom_attributes: { plan: 'pro', seats: 3, beta: true },
  locale: null,
  last_sign_in_at: null,
  created_at: '2026-10-01T09:00:00Z',
  updated_at: '2026-10-01T09:00:00Z',
}

describe('console services', () => {
  beforeEach(() => {
    vi.stubEnv('VITE_CONSOLE_URL', window.location.origin)
    vi.stubEnv('VITE_API_BASE_URL', 'https://api.test')
    configureAuth({ getAccessToken: () => 'console-token', refreshAccessToken: vi.fn<() => Promise<boolean>>() })
  })

  afterEach(() => {
    vi.unstubAllGlobals()
    vi.unstubAllEnvs()
    configureAuth(null)
  })

  it("sends the console session's token", async () => {
    const { fetchMock, sent } = stubFetch()
    fetchMock.mockResolvedValue(jsonResponse({}))

    await meService.get('acc_1')

    expect(sent().headers.get('Authorization')).toBe('Bearer console-token')
  })

  it('saves only the profile fields given', async () => {
    const { fetchMock, sent } = stubFetch()
    fetchMock.mockResolvedValue(jsonResponse({}))

    await meService.update('acc_1', { locale: null })

    expect(sent()).toMatchObject({ url: 'https://api.test/v1/accounts/acc_1/me', method: 'PATCH', body: { locale: null } })
  })

  it('pages lists with the shared query, and reads the totals from the headers', async () => {
    const { fetchMock, sent } = stubFetch()
    fetchMock.mockResolvedValue(jsonResponse([endUser], 200, { Total: '10001', 'Per-Page': '25', 'Total-Capped': 'true' }))

    const page = await projectAdminService.listEndUsers('acc_1', 'prj_1', { page: 2, search: 'casey', filters: { status_eq: 'active' }, sort: '-created_at' })

    expect(page).toEqual({ items: [endUser], total: 10001, perPage: 25, capped: true })
    const url = new URL(sent().url)
    expect(url.pathname).toBe('/v1/accounts/acc_1/projects/prj_1/end-users')
    expect(Object.fromEntries(url.searchParams)).toEqual({ page: '2', sort: '-created_at', 'q[search]': 'casey', 'q[status_eq]': 'active' })
  })

  it('fetches the largest page for lookups by default', async () => {
    const { fetchMock, sent } = stubFetch()
    fetchMock.mockResolvedValue(jsonResponse([]))

    await userService.list('acc_1')

    expect(new URL(sent().url).searchParams.get('per_page')).toBe('100')
  })

  it('rejects list items that no longer match what the console expects', async () => {
    stubFetch().fetchMock.mockResolvedValue(jsonResponse([{ ...endUser, status: 'archived' }]))

    await expect(projectAdminService.listEndUsers('acc_1', 'prj_1', {})).rejects.toMatchObject({ code: 'invalid_response' })
  })

  it('rejects a list of projects missing a field', async () => {
    stubFetch().fetchMock.mockResolvedValue(jsonResponse([{ uid: 'prj_1', name: 'Shop' }]))

    await expect(projectService.list('acc_1')).rejects.toMatchObject({ code: 'invalid_response' })
  })
})
