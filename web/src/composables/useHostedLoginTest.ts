import { useAsyncAction } from './useAsyncAction'
import { ApiError } from '@/services/http'
import { oidcService } from '@/services/oidc'
import type { TokenSet } from '@/types/api'
import { codeChallengeFor, randomUrlSafe } from '@/utils/pkce'

const STORAGE_KEY = 'x-identity:test-hosted-login'

interface PendingSignIn {
  issuer: string
  clientId: string
  redirectUri: string
  state: string
  codeVerifier: string
}

export interface HostedLoginReturn {
  code?: string
  state?: string
  error?: string
  errorDescription?: string
}

function remember(pending: PendingSignIn) {
  try {
    sessionStorage.setItem(STORAGE_KEY, JSON.stringify(pending))
  } catch {
    // Without storage the sign-in can't be completed; completing it reports that.
  }
}

function recall(): PendingSignIn | null {
  try {
    const value = sessionStorage.getItem(STORAGE_KEY)
    sessionStorage.removeItem(STORAGE_KEY)
    return value ? (JSON.parse(value) as PendingSignIn) : null
  } catch {
    return null
  }
}

/**
 * Signs in through a project's hosted login like an OpenID Connect app would: the authorization
 * code flow with PKCE, with the console as a public client. The verifier and state wait in session
 * storage while the browser is away.
 */
export function useHostedLoginTest(navigate: (url: string) => void = (url) => window.location.assign(url)) {
  const start = useAsyncAction(async (issuer: string, clientId: string, redirectUri: string) => {
    const codeVerifier = randomUrlSafe(48)
    const state = randomUrlSafe(16)
    remember({ issuer, clientId, redirectUri, state, codeVerifier })
    navigate(
      oidcService.authorizeUrl(issuer, {
        clientId,
        redirectUri,
        scope: 'openid email profile offline_access',
        state,
        nonce: randomUrlSafe(16),
        codeChallenge: await codeChallengeFor(codeVerifier),
      }),
    )
  })

  /** Finishes the sign-in when the browser comes back with a code or an error. */
  const complete = useAsyncAction(async (returned: HostedLoginReturn): Promise<{ clientId: string; tokens: TokenSet }> => {
    const pending = recall()
    if (returned.error) throw new ApiError(returned.error, returned.errorDescription || returned.error, 0)
    if (!pending || !returned.code || returned.state !== pending.state) {
      throw new ApiError('invalid_state', "This response doesn't match a sign-in started here. Start again.", 0)
    }

    const tokens = await oidcService.exchangeCode(pending.issuer, {
      clientId: pending.clientId,
      code: returned.code,
      codeVerifier: pending.codeVerifier,
      redirectUri: pending.redirectUri,
    })
    return { clientId: pending.clientId, tokens }
  })

  return { start, complete }
}
