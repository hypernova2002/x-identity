import { expect, test } from './support/test'
import * as fixtures from './support/fixtures'
import { mockConsole } from './support/console'
import { apiError, listPage } from './support/mockApi'

const acme = fixtures.accountSummary()
const olive = fixtures.me()

test.describe('Console sign-up and sign-in', () => {
  test('signs up a new account and signs its owner straight in', async ({ page, api }) => {
    api.on('POST', '/v1/sign-up', { status: 201, body: { account: acme, user: olive } })
    api.on('POST', '/v1/accounts/:account/auth/sign-in', { body: fixtures.tokens() })
    mockConsole(api, { user: olive })

    await page.goto('/sign-up')
    await page.getByLabel('Organisation name').fill('Acme')
    await expect(page.getByLabel('Account alias')).toHaveValue('acme')
    await page.getByLabel('Your name').fill('Olive Owner')
    await page.getByLabel('Email').fill('olive@acme.test')
    await page.getByLabel('Password').fill('correct horse battery staple')
    await page.getByRole('button', { name: 'Create account' }).click()

    await expect(page).toHaveURL('/console/welcome')
    expect((await api.lastCall('POST', '/v1/sign-up')).body).toEqual({
      account_name: 'Acme',
      slug: 'acme',
      name: 'Olive Owner',
      email: 'olive@acme.test',
      password: 'correct horse battery staple',
    })
  })

  test('shows the problem with each field the API rejects', async ({ page, api }) => {
    api.on('POST', '/v1/sign-up', apiError(422, 'validation_failed', { details: [{ field: 'slug', code: 'taken', params: {} }] }))

    await page.goto('/sign-up')
    await page.getByLabel('Organisation name').fill('Acme')
    await page.getByLabel('Your name').fill('Olive Owner')
    await page.getByLabel('Email').fill('olive@acme.test')
    await page.getByLabel('Password').fill('correct horse battery staple')
    await page.getByRole('button', { name: 'Create account' }).click()

    await expect(page.getByLabel('Account alias')).toHaveAccessibleDescription(/already taken/)
  })

  test('verifies an email address from the emailed link', async ({ page, api }) => {
    api.on('GET', '/v1/account-lookup/acme', { body: acme })
    api.on('POST', `/v1/accounts/${acme.uid}/auth/confirm-email`, {})

    await page.goto('/acme/verify-email?token=emailed-token')

    await expect(page.getByText('Email verified')).toBeVisible()
    expect((await api.lastCall('POST', `/v1/accounts/${acme.uid}/auth/confirm-email`)).body).toEqual({ token: 'emailed-token' })
  })

  test('explains when the emailed link has expired', async ({ page, api }) => {
    api.on('GET', '/v1/account-lookup/acme', { body: acme })
    api.on('POST', `/v1/accounts/${acme.uid}/auth/confirm-email`, apiError(400, 'invalid_token'))

    await page.goto('/acme/verify-email?token=old-token')

    await expect(page.getByText("This link doesn't work")).toBeVisible()
    await expect(page.getByText('It may have expired or already been used.')).toBeVisible()
  })

  test('signs in, returns to the page asked for, and signs out', async ({ page, api }) => {
    api.on('GET', '/v1/account-lookup/acme', { body: acme })
    api.on('POST', `/v1/accounts/${acme.uid}/auth/sign-in`, { body: fixtures.tokens() })
    const { base } = mockConsole(api, { user: olive })
    api.on('GET', `${base}/me/sessions`, listPage([fixtures.deviceSession({ current: true })]))
    api.on('GET', `${base}/me/passkeys`, { body: [] })
    api.on('POST', `${base}/auth/sign-out`, {})

    await page.goto('/acme/sign-in?redirect=/console/security')
    await page.getByLabel('Email').fill('olive@acme.test')
    await page.getByLabel('Password').fill('correct horse battery staple')
    await page.getByRole('button', { name: 'Sign in' }).click()

    await expect(page).toHaveURL('/console/security')
    expect((await api.lastCall('POST', `/v1/accounts/${acme.uid}/auth/sign-in`)).body).toEqual({ email: 'olive@acme.test', password: 'correct horse battery staple' })

    await page.getByRole('button', { name: /Olive Owner/ }).click()
    await page.getByRole('menuitem', { name: 'Sign out' }).click()

    await expect(page).toHaveURL(/\/acme\/sign-in/)
    expect((await api.lastCall('POST', `${base}/auth/sign-out`)).body).toEqual({ refresh_token: 'refresh-token' })
  })

  test('shows why a sign-in failed', async ({ page, api }) => {
    api.on('GET', '/v1/account-lookup/acme', { body: acme })
    api.on('POST', `/v1/accounts/${acme.uid}/auth/sign-in`, apiError(401, 'invalid_credentials'))

    await page.goto('/acme/sign-in')
    await page.getByLabel('Email').fill('olive@acme.test')
    await page.getByLabel('Password').fill('wrong password')
    await page.getByRole('button', { name: 'Sign in' }).click()

    await expect(page.getByRole('alert')).toContainText('The email or password is incorrect.')
  })

  test('sends signed-out visitors to sign in, remembering where they were going', async ({ page }) => {
    await page.goto('/console/security')

    await expect(page).toHaveURL('/sign-in?redirect=/console/security')
  })
})
