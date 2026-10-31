import { afterEach, describe, expect, it, vi } from 'vitest'

import { useOidcCodeFlow } from '../useOidcCodeFlow'
import { oidcService } from '@/services/oidc'
import { codeChallengeFor } from '@/utils/pkce'

const issuer = 'https://login.shop.test'
const tokens = { access_token: 'at', refresh_token: 'rt', token_type: 'Bearer' as const, expires_in: 900 }

function flow() {
  const navigate = vi.fn<(url: string) => void>()
  return { navigate, codeFlow: useOidcCodeFlow({ storageKey: 'pending', scope: 'openid email', navigate }) }
}

async function startedSignIn() {
  const { navigate, codeFlow } = flow()
  await codeFlow.start.run(issuer, 'app_1', 'https://shop.test/callback')
  const authorize = new URL(navigate.mock.calls[0]![0])
  return { codeFlow, authorize, pending: JSON.parse(sessionStorage.getItem('pending')!) }
}

describe('useOidcCodeFlow', () => {
  afterEach(() => {
    vi.restoreAllMocks()
    sessionStorage.clear()
  })

  it("sends the browser to authorize with a PKCE challenge, keeping the verifier and state for the return", async () => {
    const { authorize, pending } = await startedSignIn()

    expect(authorize.searchParams.get('scope')).toBe('openid email')
    expect(authorize.searchParams.get('state')).toBe(pending.state)
    expect(authorize.searchParams.get('code_challenge')).toBe(await codeChallengeFor(pending.codeVerifier))
    expect(pending).toMatchObject({ issuer, clientId: 'app_1', redirectUri: 'https://shop.test/callback' })
  })

  it('exchanges the returned code with the verifier, once', async () => {
    const exchange = vi.spyOn(oidcService, 'exchangeCode').mockResolvedValue(tokens)
    const { codeFlow, pending } = await startedSignIn()

    await expect(codeFlow.complete.run({ code: 'code-1', state: pending.state })).resolves.toEqual({ clientId: 'app_1', tokens })

    expect(exchange).toHaveBeenCalledWith(issuer, { clientId: 'app_1', code: 'code-1', codeVerifier: pending.codeVerifier, redirectUri: 'https://shop.test/callback' })
    expect(sessionStorage.getItem('pending')).toBeNull()
  })

  it("refuses a return whose state doesn't match, or that this browser didn't start", async () => {
    const exchange = vi.spyOn(oidcService, 'exchangeCode')
    const { codeFlow } = await startedSignIn()

    await codeFlow.complete.run({ code: 'code-1', state: 'forged' })
    expect(codeFlow.complete.error.value).toMatchObject({ code: 'invalid_state', reason: 'unmatched_sign_in' })

    await codeFlow.complete.run({ code: 'code-1', state: 'anything' })
    expect(codeFlow.complete.error.value).toMatchObject({ code: 'invalid_state' })
    expect(exchange).not.toHaveBeenCalled()
  })

  it('reports an error the provider sent back, and forgets the sign-in', async () => {
    const { codeFlow } = await startedSignIn()

    await codeFlow.complete.run({ error: 'access_denied' })

    expect(codeFlow.complete.error.value).toMatchObject({ code: 'access_denied' })
    expect(sessionStorage.getItem('pending')).toBeNull()
  })

  it('asks for a fresh sign-in when told to', async () => {
    const { navigate, codeFlow } = flow()

    await codeFlow.start.run(issuer, 'app_1', 'https://shop.test/callback', 'login')

    expect(new URL(navigate.mock.calls[0]![0]).searchParams.get('prompt')).toBe('login')
  })
})
