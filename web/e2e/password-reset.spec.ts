import { expect, test } from './support/test'
import * as fixtures from './support/fixtures'
import { apiError } from './support/mockApi'
import type { HostedLoginDetails } from '@/types/api'

const acme = fixtures.accountSummary()
const shop = fixtures.project()
const authBase = `/v1/accounts/${acme.uid}/auth`

test.describe('Resetting a password', () => {
  test.beforeEach(({ api }) => {
    api.on('GET', `/v1/account-lookup/${acme.slug}`, { body: acme })
  })

  test('a console user asks for a link without learning whether the address has a user', async ({ page, api }) => {
    api.on('POST', `${authBase}/forgot-password`, {})

    await page.goto(`/${acme.slug}/forgot-password`)
    await page.getByRole('textbox', { name: /^Email/ }).fill('olive@acme.test')
    await page.getByRole('button', { name: 'Send reset link' }).click()

    await expect(page.getByText("If olive@acme.test belongs to a user in Acme, we've sent a link to reset the password.")).toBeVisible()
    expect((await api.lastCall('POST', `${authBase}/forgot-password`)).body).toEqual({ email: 'olive@acme.test' })
  })

  test('a console user chooses a new password from the emailed link', async ({ page, api }) => {
    api.on('POST', `${authBase}/reset-password`, {})

    await page.goto(`/${acme.slug}/reset-password?token=emailed-token`)
    await page.getByLabel(/^New password/).fill('a much better passphrase')
    await page.getByRole('button', { name: 'Change password' }).click()

    await expect(page.getByText('Password changed')).toBeVisible()
    expect((await api.lastCall('POST', `${authBase}/reset-password`)).body).toEqual({ token: 'emailed-token', password: 'a much better passphrase' })
  })

  test('a console user is told when the link no longer works', async ({ page, api }) => {
    api.on('POST', `${authBase}/reset-password`, apiError(400, 'invalid_token'))

    await page.goto(`/${acme.slug}/reset-password?token=used-token`)
    await page.getByLabel(/^New password/).fill('a much better passphrase')
    await page.getByRole('button', { name: 'Change password' }).click()

    await expect(page.getByText("This link doesn't work")).toBeVisible()
    await expect(page.getByRole('link', { name: 'Request a new link' })).toBeVisible()
  })

  test('an end user resets their password with an emailed code on the hosted login page', async ({ page, api }) => {
    const interactionBase = `/v1/accounts/${acme.uid}/projects/${shop.uid}/oauth2/interactions/int_reset`
    const details: HostedLoginDetails = {
      account_name: 'Acme',
      project_name: 'Shop',
      app_name: 'Web shop',
      allow_self_sign_up: false,
      login_hint: null,
      passkeys: false,
      home_realm_discovery: false,
      identity_providers: [],
    }
    api.on('GET', interactionBase, { body: details })
    api.on('POST', `${interactionBase}/forgot-password`, {})
    api.on('POST', `${interactionBase}/confirm-forgot-password`, {})

    await page.goto(`/auth/${acme.slug}/${shop.uid}/login?interaction=int_reset`)
    await page.getByRole('button', { name: 'Forgot your password?' }).click()
    await page.getByRole('textbox', { name: /^Email/ }).fill('casey@shop.test')
    await page.getByRole('button', { name: 'Send code' }).click()

    await expect(page.getByText("If casey@shop.test has an account, we've sent it a 6-digit code.")).toBeVisible()
    await page.getByRole('textbox', { name: /^Code/ }).fill('654321')
    await page.getByLabel(/^New password/).fill('a much better passphrase')
    await page.getByRole('button', { name: 'Change password' }).click()

    await expect(page.getByText('Your password was changed. Sign in with the new one.')).toBeVisible()
    await expect(page.getByText('Sign in to Shop')).toBeVisible()
    expect((await api.lastCall('POST', `${interactionBase}/confirm-forgot-password`)).body).toEqual({
      email: 'casey@shop.test',
      code: '654321',
      password: 'a much better passphrase',
    })
  })
})
