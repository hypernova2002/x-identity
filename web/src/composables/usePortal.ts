import { ref } from 'vue'

import { useAsyncAction } from './useAsyncAction'
import { useOidcCodeFlow, type CodeFlowReturn } from './useOidcCodeFlow'
import { ApiError } from '@/services/http'
import type { ListParams } from '@/services/list'
import { oidcService } from '@/services/oidc'
import { portalService } from '@/services/portal'
import { useLocaleStore } from '@/stores/locale'
import type { DeviceSession, PortalApp, PortalConfig } from '@/types/api'
import { decodeJwt } from '@/utils/jwt'
import type { PasskeyRegistrationJSON } from '@/utils/webauthn'

interface StoredSession {
  accessToken: string
  email: string | null
}

/**
 * The app portal for one project. The portal is an OpenID Connect client of the project: it signs
 * in with the code flow (straight through when the hosted login session is still valid) and keeps
 * only its own access token, in session storage, to list the user's apps and signed-in devices.
 */
export function usePortal(projectUid: string, navigate: (url: string) => void = (url) => window.location.assign(url)) {
  const storageKey = `x-identity:portal:${projectUid}`
  const localeStore = useLocaleStore()
  const codeFlow = useOidcCodeFlow({ storageKey: `${storageKey}:pending`, scope: 'openid email profile', navigate })

  const config = ref<PortalConfig | null>(null)
  const apps = ref<PortalApp[]>([])
  const email = ref<string | null>(null)
  const accessToken = ref<string | null>(null)
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

  /** @param prompt login signs the user in again even with a valid session, e.g. before adding a passkey */
  async function signIn(prompt?: 'login') {
    if (!config.value) return
    await codeFlow.start.run(config.value.issuer, config.value.client_id, config.value.redirect_uri, prompt)
  }

  async function loadApps(session: StoredSession) {
    email.value = session.email
    accessToken.value = session.accessToken
    try {
      apps.value = await portalService.apps(accountUid, projectUid, session.accessToken)
      await showEndUserLocale(session.accessToken)
    } catch (caught) {
      if (caught instanceof ApiError && caught.code === 'invalid_token') {
        storeSession(null)
        accessToken.value = null
        return signIn()
      }
      throw caught
    }
  }

  /** Shows the end user's chosen language, and saves their choices to them. Without it, the portal still works. */
  async function showEndUserLocale(token: string) {
    const profile = await portalService.me(accountUid, projectUid, token).catch(() => null)
    if (!profile) return
    localeStore.signedIn(profile.locale, (locale) => portalService.updateLocale(accountUid, projectUid, token, locale))
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

  const fetchSessions = (params: ListParams) => portalService.sessions(accountUid, projectUid, accessToken.value ?? '', params)
  const signOutSession = (session: DeviceSession) => portalService.signOutSession(accountUid, projectUid, accessToken.value ?? '', session.uid)
  const signOutOtherSessions = () => portalService.signOutOtherSessions(accountUid, projectUid, accessToken.value ?? '')

  function launch(app: PortalApp) {
    navigate(app.launch_url)
  }

  /** Ends the hosted login session, which logs the user out of their SAML apps too. */
  function logOut() {
    if (!config.value) return
    storeSession(null)
    accessToken.value = null
    localeStore.signedOut()
    navigate(oidcService.logoutUrl(config.value.issuer, { clientId: config.value.client_id, postLogoutRedirectUri: config.value.post_logout_redirect_uri }))
  }

  const passkeys = {
    list: () => portalService.listPasskeys(accountUid, projectUid, accessToken.value ?? ''),
    options: () => portalService.passkeyOptions(accountUid, projectUid, accessToken.value ?? ''),
    add: (registrationId: string, credential: PasskeyRegistrationJSON) => portalService.addPasskey(accountUid, projectUid, accessToken.value ?? '', registrationId, credential),
    rename: (passkeyUid: string, name: string) => portalService.renamePasskey(accountUid, projectUid, accessToken.value ?? '', passkeyUid, name),
    remove: (passkeyUid: string) => portalService.removePasskey(accountUid, projectUid, accessToken.value ?? '', passkeyUid),
  }

  /** Adding a passkey needs a recent sign-in: sign in again, then come back here. */
  function signInAgain() {
    return signIn('login')
  }

  return { config, apps, email, accessToken, open, launch, logOut, fetchSessions, signOutSession, signOutOtherSessions, passkeys, signInAgain }
}
