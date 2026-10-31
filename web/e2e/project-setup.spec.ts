import { expect, test } from './support/test'
import * as fixtures from './support/fixtures'
import { listPage } from './support/mockApi'

const shop = fixtures.project()

test.describe('Setting up a project', () => {
  test('an owner without projects creates one and opens it', async ({ page, api, signIn }) => {
    const { base } = await signIn()
    api.on('POST', `${base}/projects`, { status: 201, body: shop })
    api.on('GET', `${base}/projects/${shop.uid}`, { body: shop })

    await page.goto('/console')
    await expect(page).toHaveURL('/console/welcome')
    await page.getByLabel('Project name').fill('Shop')
    await page.getByRole('main').getByRole('button', { name: 'Create project' }).click()

    await expect(page).toHaveURL(`/console/projects/${shop.uid}`)
    expect((await api.lastCall('POST', `${base}/projects`)).body).toEqual({ name: 'Shop' })
  })

  test('adds a confidential application and shows its secret once', async ({ page, api, signIn }) => {
    const { base } = await signIn({ projects: [shop] })
    const projectBase = `${base}/projects/${shop.uid}`
    const client = fixtures.appClient({ uid: 'app_backend', name: 'Back office', client_type: 'confidential', client_secret: 'shown-once-secret' })
    api.on('GET', `${projectBase}/applications`, listPage([]))
    api.on('GET', `${projectBase}/applications/stats`, { body: { total: 0, oidc: 0, machine: 0, saml: 0 } })
    api.on('POST', `${projectBase}/app-clients`, { status: 201, body: client })
    api.on('GET', `${projectBase}/app-clients/${client.uid}`, { body: { ...client, client_secret: null } })
    api.on('GET', `${projectBase}/app-clients/${client.uid}/assignments`, listPage([]))

    await page.goto(`/console/projects/${shop.uid}/applications`)
    await page.getByRole('button', { name: 'Add application' }).click()
    const addDialog = page.getByRole('dialog', { name: 'Add application' })
    await addDialog.getByRole('button', { name: 'Continue' }).click()
    await addDialog.getByRole('textbox', { name: /^Name/ }).fill('Back office')
    await addDialog.getByRole('combobox', { name: 'Client type' }).click()
    await page.getByRole('option', { name: /Confidential/ }).click()
    await addDialog.getByRole('button', { name: 'Create client' }).click()

    const secretDialog = page.getByRole('dialog', { name: 'Copy the client secret' })
    await expect(secretDialog).toContainText('shown-once-secret')
    expect((await api.lastCall('POST', `${projectBase}/app-clients`)).body).toMatchObject({ name: 'Back office', client_type: 'confidential', machine: false })

    await secretDialog.getByRole('button', { name: "I've copied it" }).click()
    await expect(page).toHaveURL(`/console/projects/${shop.uid}/applications/clients/${client.uid}`)
    await expect(page.getByRole('heading', { name: 'Back office' })).toBeVisible()
  })

  test('creates an end user and opens their page', async ({ page, api, signIn }) => {
    const { base } = await signIn({ projects: [shop] })
    const projectBase = `${base}/projects/${shop.uid}`
    const casey = fixtures.endUser({ invitation_pending: true, email_verified: false })
    api.on('GET', `${projectBase}/end-users`, listPage([]))
    api.on('GET', `${projectBase}/end-users/stats`, { body: { total: 0, active: 0, disabled: 0, invitation_pending: 0, signed_in_recently: 0 } })
    api.on('GET', `${projectBase}/attributes`, listPage([]))
    api.on('POST', `${projectBase}/end-users`, { status: 201, body: casey })
    api.on('GET', `${projectBase}/end-users/${casey.uid}`, { body: casey })
    for (const part of ['identities', 'access', 'passkeys']) api.on('GET', `${projectBase}/end-users/${casey.uid}/${part}`, { body: [] })
    api.on('GET', `${projectBase}/end-users/${casey.uid}/sessions`, listPage([]))
    api.on('GET', `${projectBase}/audit-events`, listPage([]))

    await page.goto(`/console/projects/${shop.uid}/end-users`)
    await page.getByRole('button', { name: 'Create end user' }).click()
    const dialog = page.getByRole('dialog', { name: 'Create end user' })
    await dialog.getByRole('textbox', { name: /^Email/ }).fill('casey@shop.test')
    await dialog.getByRole('textbox', { name: /^Name/ }).fill('Casey Customer')
    await dialog.getByRole('button', { name: 'Create', exact: true }).click()

    await expect(page).toHaveURL(`/console/projects/${shop.uid}/end-users/${casey.uid}`)
    await expect(page.getByRole('heading', { name: 'casey@shop.test' })).toBeVisible()
    expect((await api.lastCall('POST', `${projectBase}/end-users`)).body).toEqual({
      email: 'casey@shop.test',
      name: 'Casey Customer',
      custom_attributes: {},
      send_invitation: true,
    })
  })
})
