import { expect, test } from './support/test'
import * as fixtures from './support/fixtures'
import { apiError, listPage, type MockApi } from './support/mockApi'
import { API_ORIGIN, APP_ORIGIN } from './support/origins'
import type { HostedLoginDetails, PortalConfig } from '@/types/api'

const acme = fixtures.accountSummary()
const shop = fixtures.project()
const projectBase = `/v1/accounts/${acme.uid}/projects/${shop.uid}`
const portalUrl = `/auth/${acme.slug}/${shop.uid}/apps`
const loginUrl = `/auth/${acme.slug}/${shop.uid}/login?interaction=int_signup`

const portalConfig: PortalConfig = {
  issuer: `${API_ORIGIN}${projectBase}`,
  client_id: 'app_portal',
  redirect_uri: `${APP_ORIGIN}${portalUrl}`,
  post_logout_redirect_uri: `${APP_ORIGIN}/auth/${acme.slug}/${shop.uid}/signed-out`,
  passkeys_available: false,
}

const loginDetails: HostedLoginDetails = {
  account_name: 'Acme',
  project_name: 'Shop',
  app_name: 'App portal',
  allow_self_sign_up: true,
  login_hint: null,
  passkeys: false,
  home_realm_discovery: false,
  identity_providers: [],
}

/** An unsigned ID token: the portal only reads its claims. */
function idToken(claims: object): string {
  const part = (value: object) => Buffer.from(JSON.stringify(value)).toString('base64url')
  return `${part({ alg: 'none' })}.${part(claims)}.`
}

function mockHostedLogin(api: MockApi) {
  api.on('GET', `/v1/account-lookup/${acme.slug}`, { body: acme })
  api.on('GET', `${projectBase}/oauth2/interactions/:interaction`, { body: loginDetails })
}

test.describe('Hosted login and the app portal', () => {
  test('an end user signs up, comes back to the portal signed in, and signs out an old device', async ({ page, api }) => {
    mockHostedLogin(api)
    api.on('GET', `${projectBase}/portal`, { body: portalConfig })

    // The backend's side of the code flow: authorize starts the hosted login, and finishing it
    // returns to the portal with a code for the state the portal sent.
    let state = ''
    api.on('GET', `${projectBase}/oauth2/authorize`, (request) => {
      state = request.query.get('state') ?? ''
      return { status: 302, headers: { location: `${APP_ORIGIN}${loginUrl}` } }
    })
    api.on('GET', `${projectBase}/oauth2/authorize/resume`, () => ({ status: 302, headers: { location: `${portalConfig.redirect_uri}?code=auth-code&state=${state}` } }))

    api.on('POST', `${projectBase}/oauth2/interactions/:interaction/sign-up`, {})
    api.on('POST', `${projectBase}/oauth2/interactions/:interaction/confirm-sign-up`, {})
    api.on('POST', `${projectBase}/oauth2/interactions/:interaction/sign-in`, { body: { redirect_to: `${API_ORIGIN}${projectBase}/oauth2/authorize/resume` } })
    api.on('POST', `${projectBase}/oauth2/token`, { body: fixtures.tokens({ access_token: 'portal-token', id_token: idToken({ email: 'casey@shop.test' }) }) })
    api.on('GET', `${projectBase}/portal/apps`, { body: [{ uid: 'app_web', kind: 'oidc', name: 'Web shop', launch_url: 'https://shop.test' }] })
    api.on('GET', `${projectBase}/me`, { body: fixtures.endUser() })
    api.on('GET', `${projectBase}/me/sessions`, listPage([
      fixtures.deviceSession({ uid: 'dev_this', current: true }),
      fixtures.deviceSession({ uid: 'dev_old', device_name: 'Firefox on Windows', location: { city: 'Lisbon', region: null, country_code: 'PT' } }),
    ]))
    api.on('GET', `${projectBase}/me/passkeys`, { body: [] })
    api.on('DELETE', `${projectBase}/me/sessions/:session`, {})

    await page.goto(portalUrl)

    await expect(page.getByText('Sign in to Shop')).toBeVisible()
    await page.getByRole('button', { name: 'Create an account' }).click()
    await page.getByRole('textbox', { name: /^Email/ }).fill('casey@shop.test')
    await page.getByRole('textbox', { name: /^Name/ }).fill('Casey Customer')
    await page.getByLabel(/^Password/).fill('correct horse battery staple')
    await page.getByRole('button', { name: 'Create account' }).click()

    await page.getByRole('textbox', { name: /^Code/ }).fill('123456')
    await page.getByRole('button', { name: 'Confirm' }).click()

    await expect(page.getByText('Signed in as casey@shop.test')).toBeVisible()
    await expect(page.getByText('Web shop')).toBeVisible()
    await expect(page).toHaveURL(portalUrl)

    expect((await api.lastCall('POST', `${projectBase}/oauth2/interactions/:interaction/sign-up`)).body).toEqual({
      email: 'casey@shop.test',
      password: 'correct horse battery staple',
      name: 'Casey Customer',
    })
    expect((await api.lastCall('POST', `${projectBase}/oauth2/interactions/:interaction/confirm-sign-up`)).body).toEqual({ email: 'casey@shop.test', code: '123456' })
    const exchange = await api.lastCall('POST', `${projectBase}/oauth2/token`)
    expect(exchange.body).toMatchObject({ grant_type: 'authorization_code', client_id: 'app_portal', code: 'auth-code', redirect_uri: portalConfig.redirect_uri })
    expect((await api.lastCall('GET', `${projectBase}/portal/apps`)).headers.authorization).toBe('Bearer portal-token')

    await page.getByRole('button', { name: 'Sign out Firefox on Windows' }).click()
    await page.getByRole('dialog', { name: 'Sign out this device?' }).getByRole('button', { name: 'Sign out device' }).click()

    await expect(page.getByText('Firefox on Windows was signed out.')).toBeVisible()
    expect((await api.lastCall('DELETE', `${projectBase}/me/sessions/:session`)).path).toBe(`${projectBase}/me/sessions/dev_old`)
  })

  test('says when the emailed code is wrong', async ({ page, api }) => {
    mockHostedLogin(api)
    api.on('POST', `${projectBase}/oauth2/interactions/:interaction/sign-up`, {})
    api.on('POST', `${projectBase}/oauth2/interactions/:interaction/confirm-sign-up`, apiError(400, 'invalid_otp'))

    await page.goto(loginUrl)
    await page.getByRole('button', { name: 'Create an account' }).click()
    await page.getByRole('textbox', { name: /^Email/ }).fill('casey@shop.test')
    await page.getByLabel(/^Password/).fill('correct horse battery staple')
    await page.getByRole('button', { name: 'Create account' }).click()
    await page.getByRole('textbox', { name: /^Code/ }).fill('000000')
    await page.getByRole('button', { name: 'Confirm' }).click()

    await expect(page.getByRole('alert')).toContainText('The verification code is incorrect.')
  })

  test('explains when the sign-in has expired', async ({ page, api }) => {
    api.on('GET', `/v1/account-lookup/${acme.slug}`, { body: acme })
    api.on('GET', `${projectBase}/oauth2/interactions/:interaction`, apiError(400, 'invalid_interaction'))

    await page.goto(loginUrl)

    await expect(page.getByText('This sign-in has expired')).toBeVisible()
  })
})
