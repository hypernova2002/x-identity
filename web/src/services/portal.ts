import { ApiError, apiPage, apiRequest } from './http'
import { listQuery, type ListParams } from './list'
import { deviceSessionSchema } from './schemas'
import type { Passkey, PasskeyRegistrationOptions, PortalApp, PortalConfig } from '@/types/api'
import { apiBaseUrl, projectPath } from '@/utils/customDomain'
import type { PasskeyRegistrationJSON } from '@/utils/webauthn'

const portalPath = (accountUid: string, projectUid: string) => `${projectPath(accountUid, projectUid)}/portal`
const mePath = (accountUid: string, projectUid: string) => `${projectPath(accountUid, projectUid)}/me`

/** The app portal: its own OpenID Connect client, and the apps a signed-in end user can open. */
export const portalService = {
  config: (accountUid: string, projectUid: string) => apiRequest<PortalConfig>(portalPath(accountUid, projectUid)),

  /** Called with the portal's own access token, not the console session. An expired token is `invalid_token`. */
  async apps(accountUid: string, projectUid: string, accessToken: string): Promise<PortalApp[]> {
    let response: Response
    try {
      response = await fetch(`${apiBaseUrl()}${portalPath(accountUid, projectUid)}/apps`, {
        headers: { Accept: 'application/json', Authorization: `Bearer ${accessToken}` },
      })
    } catch {
      throw new ApiError('network_error', 0)
    }
    if (response.status === 401) throw new ApiError('invalid_token', 401, { reason: 'portal_session_expired' })
    if (!response.ok) throw new ApiError('internal_error', response.status, { reason: 'apps_unavailable' })
    return (await response.json()) as PortalApp[]
  },

  /** The end user's signed-in devices, with the portal's access token. */
  sessions: (accountUid: string, projectUid: string, accessToken: string, params: ListParams) =>
    apiPage(`${mePath(accountUid, projectUid)}/sessions`, deviceSessionSchema, { accessToken, query: listQuery(params) }),

  signOutSession: (accountUid: string, projectUid: string, accessToken: string, sessionUid: string) =>
    apiRequest<null>(`${mePath(accountUid, projectUid)}/sessions/${sessionUid}`, { accessToken, method: 'DELETE' }),

  listPasskeys: (accountUid: string, projectUid: string, accessToken: string) => apiRequest<Passkey[]>(`${mePath(accountUid, projectUid)}/passkeys`, { accessToken }),

  passkeyOptions: (accountUid: string, projectUid: string, accessToken: string) =>
    apiRequest<PasskeyRegistrationOptions>(`${mePath(accountUid, projectUid)}/passkeys/options`, { accessToken, method: 'POST' }),

  addPasskey: (accountUid: string, projectUid: string, accessToken: string, registrationId: string, credential: PasskeyRegistrationJSON) =>
    apiRequest<Passkey>(`${mePath(accountUid, projectUid)}/passkeys`, { accessToken, method: 'POST', body: { registration_id: registrationId, credential } }),

  renamePasskey: (accountUid: string, projectUid: string, accessToken: string, passkeyUid: string, name: string) =>
    apiRequest<Passkey>(`${mePath(accountUid, projectUid)}/passkeys/${passkeyUid}`, { accessToken, method: 'PATCH', body: { name } }),

  removePasskey: (accountUid: string, projectUid: string, accessToken: string, passkeyUid: string) =>
    apiRequest<null>(`${mePath(accountUid, projectUid)}/passkeys/${passkeyUid}`, { accessToken, method: 'DELETE' }),

  signOutOtherSessions: (accountUid: string, projectUid: string, accessToken: string) =>
    apiRequest<null>(`${mePath(accountUid, projectUid)}/sessions`, { accessToken, method: 'DELETE' }),
}
