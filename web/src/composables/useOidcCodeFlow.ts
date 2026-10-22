import { useAsyncAction } from './useAsyncAction'
import { ApiError } from '@/services/http'
import { oidcService } from '@/services/oidc'
import type { TokenSet } from '@/types/api'
import { codeChallengeFor, randomUrlSafe } from '@/utils/pkce'

interface PendingSignIn {
  issuer: string
  clientId: string
  redirectUri: string
  state: string
  codeVerifier: string
}

export interface CodeFlowReturn {
  code?: string
  state?: string
  error?: string
  errorDescription?: string
}

export interface CodeFlowOptions {
  /** Where the code verifier and state wait while the browser is away. */
  storageKey: string
  scope: string
  navigate?: (url: string) => void
}

/**
 * Signs in like an OpenID Connect public client: the authorization code flow with PKCE. Used by
 * the console's test sign-in and by the app portal, which is a client of its own project.
 */
export function useOidcCodeFlow(options: CodeFlowOptions) {
  const navigate = options.navigate ?? ((url: string) => window.location.assign(url))

  function remember(pending: PendingSignIn) {
    try {
      sessionStorage.setItem(options.storageKey, JSON.stringify(pending))
    } catch {
      // Without storage the sign-in can't be completed; completing it reports that.
    }
  }

  function recall(): PendingSignIn | null {
    try {
      const value = sessionStorage.getItem(options.storageKey)
      sessionStorage.removeItem(options.storageKey)
      return value ? (JSON.parse(value) as PendingSignIn) : null
    } catch {
      return null
    }
  }

  const start = useAsyncAction(async (issuer: string, clientId: string, redirectUri: string) => {
    const codeVerifier = randomUrlSafe(48)
    const state = randomUrlSafe(16)
    remember({ issuer, clientId, redirectUri, state, codeVerifier })
    navigate(
      oidcService.authorizeUrl(issuer, {
        clientId,
        redirectUri,
        scope: options.scope,
        state,
        nonce: randomUrlSafe(16),
        codeChallenge: await codeChallengeFor(codeVerifier),
      }),
    )
  })

  /** Finishes the sign-in when the browser comes back with a code or an error. */
  const complete = useAsyncAction(async (returned: CodeFlowReturn): Promise<{ clientId: string; tokens: TokenSet }> => {
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
