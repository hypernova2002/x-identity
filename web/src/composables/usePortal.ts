import { ref } from 'vue'

import { useAsyncAction } from './useAsyncAction'
import { useOidcCodeFlow, type CodeFlowReturn } from './useOidcCodeFlow'
import { ApiError } from '@/services/http'
import { oidcService } from '@/services/oidc'
import { portalService } from '@/services/portal'
import type { PortalApp, PortalConfig } from '@/types/api'
import { decodeJwt } from '@/utils/jwt'

interface StoredSession {
  accessToken: string
  email: string | null
}

/**
 * The app portal for one project. The portal is an OpenID Connect client of the project: it signs
 * in with the code flow (straight through when the hosted login session is still valid) and keeps
 * only its own access token, in session storage, to list the user's apps.
 */
export function usePortal(projectUid: string, navigate: (url: string) => void = (url) => window.location.assign(url)) {
  const storageKey = `x-identity:portal:${projectUid}`
  const codeFlow = useOidcCodeFlow({ storageKey: `${storageKey}:pending`, scope: 'openid email profile', navigate })

  const config = ref<PortalConfig | null>(null)
  const apps = ref<PortalApp[]>([])
  const email = ref<string | null>(null)
  let accountUid = ''

  function storedSession(): StoredSession | null {
    try {
      const value = sessionStorage.getItem(storageKey)
      return value ? (JSON.parse(value) as StoredSession) : null
    } catch {
      return null
    }
  }

  function storeSession(session: StoredSession | null) {
    try {
      if (session) sessionStorage.setItem(storageKey, JSON.stringify(session))
      else sessionStorage.removeItem(storageKey)
    } catch {
      // The portal then signs in again on the next visit.
    }
  }

  async function signIn() {
    if (!config.value) return
    await codeFlow.start.run(config.value.issuer, config.value.client_id, config.value.redirect_uri)
  }

  async function loadApps(session: StoredSession) {
    email.value = session.email
    try {
      apps.value = await portalService.apps(accountUid, projectUid, session.accessToken)
    } catch (caught) {
      if (caught instanceof ApiError && caught.code === 'invalid_token') {
        storeSession(null)
        return signIn()
      }
      throw caught
    }
  }

  /** Opens the portal; `returned` carries the code (or error) when the browser comes back from signing in. */
  const open = useAsyncAction(async (account: string, returned: CodeFlowReturn | null) => {
    accountUid = account
    config.value = await portalService.config(accountUid, projectUid)

    if (returned) {
      const result = await codeFlow.complete.run(returned)
      if (codeFlow.complete.error.value) throw codeFlow.complete.error.value
      if (!result) return

      const claims = result.tokens.id_token ? decodeJwt(result.tokens.id_token)?.payload : undefined
      const session = { accessToken: result.tokens.access_token, email: typeof claims?.email === 'string' ? claims.email : null }
      storeSession(session)
      return loadApps(session)
    }

    const session = storedSession()
    return session ? loadApps(session) : signIn()
  })

  function launch(app: PortalApp) {
    navigate(app.launch_url)
  }

  /** Ends the hosted login session, which logs the user out of their SAML apps too. */
  function logOut() {
    if (!config.value) return
    storeSession(null)
    navigate(oidcService.logoutUrl(config.value.issuer, { clientId: config.value.client_id, postLogoutRedirectUri: config.value.post_logout_redirect_uri }))
  }

  return { config, apps, email, open, launch, logOut }
}
