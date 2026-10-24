import { ApiError, apiPage, apiRequest } from './http'
import { listQuery, type ListParams } from './list'
import { deviceSessionSchema } from './schemas'
import type { PortalApp, PortalConfig } from '@/types/api'

const portalPath = (accountUid: string, projectUid: string) => `/v1/accounts/${accountUid}/projects/${projectUid}/portal`
const mePath = (accountUid: string, projectUid: string) => `/v1/accounts/${accountUid}/projects/${projectUid}/me`

/** The app portal: its own OpenID Connect client, and the apps a signed-in end user can open. */
export const portalService = {
  config: (accountUid: string, projectUid: string) => apiRequest<PortalConfig>(portalPath(accountUid, projectUid)),

  /** Called with the portal's own access token, not the console session. An expired token is `invalid_token`. */
  async apps(accountUid: string, projectUid: string, accessToken: string): Promise<PortalApp[]> {
    let response: Response
    try {
      response = await fetch(`${import.meta.env.VITE_API_BASE_URL}${portalPath(accountUid, projectUid)}/apps`, {
        headers: { Accept: 'application/json', Authorization: `Bearer ${accessToken}` },
      })
    } catch {
      throw new ApiError('network_error', "We couldn't reach the server. Check your connection and try again.", 0)
    }
    if (response.status === 401) throw new ApiError('invalid_token', 'Your portal session has expired.', 401)
    if (!response.ok) throw new ApiError('internal_error', "We couldn't load your apps. Try again.", response.status)
    return (await response.json()) as PortalApp[]
  },

  /** The end user's signed-in devices, with the portal's access token. */
  sessions: (accountUid: string, projectUid: string, accessToken: string, params: ListParams) =>
    apiPage(`${mePath(accountUid, projectUid)}/sessions`, deviceSessionSchema, { accessToken, query: listQuery(params) }),

  signOutSession: (accountUid: string, projectUid: string, accessToken: string, sessionUid: string) =>
    apiRequest<null>(`${mePath(accountUid, projectUid)}/sessions/${sessionUid}`, { accessToken, method: 'DELETE' }),

  signOutOtherSessions: (accountUid: string, projectUid: string, accessToken: string) =>
    apiRequest<null>(`${mePath(accountUid, projectUid)}/sessions`, { accessToken, method: 'DELETE' }),
}
