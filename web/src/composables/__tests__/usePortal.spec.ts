import { beforeEach, describe, expect, it, vi } from 'vitest'

import { usePortal } from '../usePortal'
import { ApiError } from '@/services/http'
import { oidcService } from '@/services/oidc'
import { portalService } from '@/services/portal'
import type { PortalConfig } from '@/types/api'

type Portal = typeof portalService

vi.mock('@/services/portal', () => ({
  portalService: { config: vi.fn<Portal['config']>(), apps: vi.fn<Portal['apps']>() },
}))
vi.mock('@/services/oidc', async (importOriginal) => {
  const original = await importOriginal<typeof import('@/services/oidc')>()
  return { oidcService: { ...original.oidcService, exchangeCode: vi.fn<typeof original.oidcService.exchangeCode>() } }
})

const config: PortalConfig = {
  issuer: 'http://api.test/v1/accounts/acct_1/projects/proj_1',
  client_id: 'cl_portal',
  redirect_uri: 'http://console.test/auth/acme/proj_1/apps',
  post_logout_redirect_uri: 'http://console.test/auth/acme/proj_1/signed-out',
  passkeys_available: false,
}

describe('usePortal', () => {
  const navigate = vi.fn<(url: string) => void>()

  beforeEach(() => {
    vi.resetAllMocks()
    sessionStorage.clear()
    vi.mocked(portalService.config).mockResolvedValue(config)
  })

  it('signs in with the code flow when there is no portal session', async () => {
    await usePortal('proj_1', navigate).open.run('acct_1', null)

    expect(navigate).toHaveBeenCalledWith(expect.stringContaining(`${config.issuer}/oauth2/authorize?`))
    expect(navigate.mock.calls[0]?.[0]).toContain('client_id=cl_portal')
  })

  it('lists the apps once the sign-in comes back with a code', async () => {
    await usePortal('proj_1', navigate).open.run('acct_1', null)
    const state = new URL(navigate.mock.calls[0]![0]).searchParams.get('state') ?? ''
    vi.mocked(oidcService.exchangeCode).mockResolvedValue({ access_token: 'portal-token', refresh_token: '', token_type: 'Bearer', expires_in: 900 })
    vi.mocked(portalService.apps).mockResolvedValue([{ uid: 'saml_1', kind: 'saml', name: 'Wiki', launch_url: 'http://api.test/launch' }])

    const portal = usePortal('proj_1', navigate)
    await portal.open.run('acct_1', { code: 'code-1', state })

    expect(portalService.apps).toHaveBeenCalledWith('acct_1', 'proj_1', 'portal-token')
    expect(portal.apps.value.map((app) => app.name)).toEqual(['Wiki'])
  })

  it('signs in again when the stored token has expired', async () => {
    sessionStorage.setItem('x-identity:portal:proj_1', JSON.stringify({ accessToken: 'old', email: 'casey@shop.test' }))
    vi.mocked(portalService.apps).mockRejectedValue(new ApiError('invalid_token', 'Expired.', 401))

    await usePortal('proj_1', navigate).open.run('acct_1', null)

    expect(navigate).toHaveBeenCalledWith(expect.stringContaining('/oauth2/authorize?'))
    expect(sessionStorage.getItem('x-identity:portal:proj_1')).toBeNull()
  })

  it('logs out through hosted logout, back to the signed-out page', async () => {
    sessionStorage.setItem('x-identity:portal:proj_1', JSON.stringify({ accessToken: 'token', email: null }))
    vi.mocked(portalService.apps).mockResolvedValue([])
    const portal = usePortal('proj_1', navigate)
    await portal.open.run('acct_1', null)

    portal.logOut()

    expect(navigate).toHaveBeenLastCalledWith(expect.stringContaining(`${config.issuer}/oauth2/logout?client_id=cl_portal`))
  })
})
