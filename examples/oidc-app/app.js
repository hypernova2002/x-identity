// A minimal OpenID Connect public client: the authorization code flow with PKCE against an
// x-identity project, with no build step and no dependencies. The same files run as two apps,
// told apart by port, so single sign-on between them can be tried.

const APPS = {
  5190: { name: 'Shop', accent: '#185fa5' },
  5191: { name: 'Wiki', accent: '#15803d' },
}
const app = APPS[location.port] ?? { name: 'Example app', accent: '#185fa5' }
const SETTINGS_KEY = 'x-identity-example:settings'
const PENDING_KEY = 'x-identity-example:pending'
const TOKENS_KEY = 'x-identity-example:tokens'
const SCOPE = 'openid email profile groups offline_access'
const redirectUri = `${location.origin}/`

const $ = (id) => document.getElementById(id)

function read(storage, key) {
  try {
    return JSON.parse(storage.getItem(key) ?? 'null')
  } catch {
    return null
  }
}

function write(storage, key, value) {
  if (value === null) storage.removeItem(key)
  else storage.setItem(key, JSON.stringify(value))
}

function base64Url(bytes) {
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

function randomString(byteLength = 32) {
  return base64Url(crypto.getRandomValues(new Uint8Array(byteLength)))
}

async function s256(verifier) {
  return base64Url(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier))))
}

function decodeJwt(token) {
  const payload = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')
  const bytes = Uint8Array.from(atob(payload.padEnd(Math.ceil(payload.length / 4) * 4, '=')), (c) => c.charCodeAt(0))
  return JSON.parse(new TextDecoder().decode(bytes))
}

function showError(message) {
  $('error').textContent = message
  $('error').hidden = !message
}

function show(section) {
  for (const id of ['settings', 'signed-out', 'signed-in']) $(id).hidden = id !== section
}

async function signIn({ forceLogin = false } = {}) {
  const settings = read(localStorage, SETTINGS_KEY)
  const verifier = randomString(48)
  const state = randomString(16)
  write(sessionStorage, PENDING_KEY, { verifier, state })

  const query = new URLSearchParams({
    response_type: 'code',
    client_id: settings.clientId,
    redirect_uri: redirectUri,
    scope: SCOPE,
    state,
    nonce: randomString(16),
    code_challenge: await s256(verifier),
    code_challenge_method: 'S256',
  })
  if (forceLogin) query.set('prompt', 'login')
  location.assign(`${settings.issuer}/oauth2/authorize?${query}`)
}

async function tokenRequest(form) {
  const settings = read(localStorage, SETTINGS_KEY)
  const response = await fetch(`${settings.issuer}/oauth2/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ client_id: settings.clientId, ...form }),
  })
  const body = await response.json()
  if (!response.ok) throw new Error(`${body.error}: ${body.error_description}`)
  return body
}

async function completeSignIn(params) {
  const pending = read(sessionStorage, PENDING_KEY)
  write(sessionStorage, PENDING_KEY, null)
  history.replaceState(null, '', '/')

  if (params.get('error')) throw new Error(`${params.get('error')}: ${params.get('error_description') ?? ''}`)
  if (!pending || params.get('state') !== pending.state) throw new Error("The response doesn't match a sign-in started here.")

  const tokens = await tokenRequest({ grant_type: 'authorization_code', code: params.get('code'), code_verifier: pending.verifier, redirect_uri: redirectUri })
  write(sessionStorage, TOKENS_KEY, tokens)
}

async function renderSignedIn(tokens, status = '') {
  const settings = read(localStorage, SETTINGS_KEY)
  const claims = decodeJwt(tokens.id_token)
  $('who').textContent = claims.email ?? claims.sub
  $('claims').textContent = JSON.stringify(claims, null, 2)
  $('status').textContent = status
  show('signed-in')

  const response = await fetch(`${settings.issuer}/oauth2/userinfo`, { headers: { Authorization: `Bearer ${tokens.access_token}` } })
  $('userinfo').textContent = response.ok ? JSON.stringify(await response.json(), null, 2) : `Userinfo failed (${response.status}).`
}

function logOut() {
  const settings = read(localStorage, SETTINGS_KEY)
  write(sessionStorage, TOKENS_KEY, null)
  const query = new URLSearchParams({ client_id: settings.clientId, post_logout_redirect_uri: redirectUri })
  location.assign(`${settings.issuer}/oauth2/logout?${query}`)
}

function editSettings() {
  const settings = read(localStorage, SETTINGS_KEY) ?? {}
  $('settings-form').issuer.value = settings.issuer ?? ''
  $('settings-form').clientId.value = settings.clientId ?? ''
  show('settings')
}

// The project's built-in app portal; its address comes from the public portal settings.
async function showPortalLink() {
  const settings = read(localStorage, SETTINGS_KEY)
  try {
    const response = await fetch(`${settings.issuer}/portal`)
    if (!response.ok) return
    $('portal-link').href = (await response.json()).redirect_uri
    $('portal').hidden = false
  } catch {
    // The link is a convenience; the app works without it.
  }
}

async function start() {
  document.title = app.name
  document.documentElement.style.setProperty('--accent', app.accent)
  $('app-name').textContent = app.name
  $('origin').textContent = location.origin
  $('redirect-uri').textContent = redirectUri
  $('launch-url').textContent = `${redirectUri}?login=1`

  $('settings-form').addEventListener('submit', (event) => {
    event.preventDefault()
    const form = new FormData(event.target)
    write(localStorage, SETTINGS_KEY, { issuer: form.get('issuer').trim().replace(/\/$/, ''), clientId: form.get('clientId').trim() })
    write(sessionStorage, TOKENS_KEY, null)
    show('signed-out')
  })
  $('sign-in').addEventListener('click', () => signIn())
  $('sign-in-again').addEventListener('click', () => signIn({ forceLogin: true }))
  $('edit-settings').addEventListener('click', editSettings)
  $('log-out').addEventListener('click', logOut)
  $('refresh').addEventListener('click', async () => {
    try {
      const tokens = read(sessionStorage, TOKENS_KEY)
      const refreshed = await tokenRequest({ grant_type: 'refresh_token', refresh_token: tokens.refresh_token })
      write(sessionStorage, TOKENS_KEY, refreshed)
      await renderSignedIn(refreshed, `Refreshed at ${new Date().toLocaleTimeString()}.`)
    } catch (error) {
      showError(error.message)
    }
  })

  if (!read(localStorage, SETTINGS_KEY)) return editSettings()
  showPortalLink()

  const params = new URLSearchParams(location.search)
  try {
    if (params.has('code') || params.has('error')) await completeSignIn(params)
  } catch (error) {
    showError(error.message)
  }

  const tokens = read(sessionStorage, TOKENS_KEY)
  if (tokens) return renderSignedIn(tokens)
  // Opened from the app portal: sign straight in, which the single sign-on session makes seamless.
  if (params.get('login') === '1') return signIn()
  show('signed-out')
}

start()
