import { ApiError } from './http'
import type { TokenSet } from '@/types/api'

export interface AuthorizeRequest {
  clientId: string
  redirectUri: string
  scope: string
  state: string
  nonce: string
  codeChallenge: string
}

export interface CodeExchange {
  clientId: string
  code: string
  codeVerifier: string
  redirectUri: string
}

function isOauthError(value: unknown): value is { error: string; error_description?: string } {
  return typeof value === 'object' && value !== null && typeof (value as { error?: unknown }).error === 'string'
}

/** A project's OpenID Connect endpoints, used the way any OIDC client would. */
export const oidcService = {
  authorizeUrl(issuer: string, request: AuthorizeRequest): string {
    const query = new URLSearchParams({
      response_type: 'code',
      client_id: request.clientId,
      redirect_uri: request.redirectUri,
      scope: request.scope,
      state: request.state,
      nonce: request.nonce,
      code_challenge: request.codeChallenge,
      code_challenge_method: 'S256',
    })
    return `${issuer}/oauth2/authorize?${query.toString()}`
  },

  /** Ends the hosted login session, and with it every app the session signed in to. */
  logoutUrl(issuer: string, request?: { clientId: string; postLogoutRedirectUri: string }): string {
    if (!request) return `${issuer}/oauth2/logout`

    const query = new URLSearchParams({ client_id: request.clientId, post_logout_redirect_uri: request.postLogoutRedirectUri })
    return `${issuer}/oauth2/logout?${query.toString()}`
  },

  /** Redeems an authorization code at the token endpoint, as a public client. OAuth errors become ApiErrors. */
  async exchangeCode(issuer: string, exchange: CodeExchange): Promise<TokenSet> {
    let response: Response
    try {
      response = await fetch(`${issuer}/oauth2/token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json' },
        body: new URLSearchParams({
          grant_type: 'authorization_code',
          client_id: exchange.clientId,
          code: exchange.code,
          code_verifier: exchange.codeVerifier,
          redirect_uri: exchange.redirectUri,
        }),
      })
    } catch {
      throw new ApiError('network_error', "We couldn't reach the server. Check your connection and try again.", 0)
    }

    const body: unknown = await response.json().catch(() => null)
    if (response.ok && body) return body as TokenSet
    if (isOauthError(body)) throw new ApiError(body.error, body.error_description ?? body.error, response.status)
    throw new ApiError('internal_error', 'An unexpected error occurred.', response.status)
  },
}
