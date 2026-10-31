import { expect, test } from './support/test'
import * as fixtures from './support/fixtures'
import { listPage } from './support/mockApi'

const shop = fixtures.project()

test.describe('A list view', () => {
  test('searches, filters and pages on the server, and keeps rows per page in the URL', async ({ page, api, signIn }) => {
    const { base } = await signIn({ projects: [shop] })
    const projectBase = `${base}/projects/${shop.uid}`
    api.on('GET', `${projectBase}/end-users`, (request) => {
      const perPage = Number(request.query.get('per_page') ?? 25)
      const first = (Number(request.query.get('page') ?? 1) - 1) * perPage
      const rows = Array.from({ length: perPage }, (_, index) => fixtures.endUser({ uid: `eu_${first + index}`, email: `user${first + index}@shop.test` }))
      return listPage(rows, { total: 60, perPage })
    })
    api.on('GET', `${projectBase}/end-users/stats`, { body: { total: 60, active: 60, disabled: 0, invitation_pending: 0, signed_in_recently: 0 } })
    api.on('GET', `${projectBase}/attributes`, listPage([]))
    api.on('GET', `${projectBase}/groups`, listPage([]))
    const lastQuery = async (count: number) => (await api.lastCall('GET', `${projectBase}/end-users`, count)).query

    await page.goto(`/console/projects/${shop.uid}/end-users`)
    await expect(page.getByText('1–25 of 60').first()).toBeVisible()

    await page.getByRole('searchbox', { name: 'Search by email, name or ID' }).fill('casey')
    await expect.poll(async () => (await lastQuery(2)).get('q[search]')).toBe('casey')

    await page.getByRole('combobox', { name: 'Status' }).click()
    await page.getByRole('option', { name: 'Disabled' }).click()
    await expect.poll(async () => (await lastQuery(3)).get('q[status_eq]')).toBe('disabled')
    await expect(page.getByRole('button', { name: 'Remove Status: Disabled' })).toBeVisible()

    await page.getByRole('button', { name: 'Next page' }).first().click()
    await expect.poll(async () => (await lastQuery(4)).get('page')).toBe('2')
    await expect(page.getByText('26–50 of 60').first()).toBeVisible()

    await page.getByRole('combobox', { name: 'Rows per page' }).first().click()
    await page.getByRole('option', { name: '50' }).click()
    const query = await lastQuery(5)
    expect(query.get('per_page')).toBe('50')
    expect(query.get('page')).toBeNull()
    expect(query.get('q[search]')).toBe('casey')
    await expect(page).toHaveURL(/per_page=50/)

    await page.getByRole('button', { name: 'Clear all' }).click()
    await expect.poll(async () => Object.fromEntries(await lastQuery(6))).toEqual({ per_page: '50', sort: expect.any(String) })
  })
})
