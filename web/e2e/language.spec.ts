import { expect, test } from './support/test'
import * as fixtures from './support/fixtures'
import type { Me } from '@/types/api'

const acme = fixtures.accountSummary()

test.describe('Choosing a language', () => {
  test('a console user switches to Japanese, which is saved to them and used for later requests', async ({ page, api, signIn }) => {
    const { base, user } = await signIn()
    let saved: Me = user
    api.on('GET', `${base}/me`, () => ({ body: saved }))
    api.on('PATCH', `${base}/me`, (request) => {
      saved = { ...saved, ...(request.body as Partial<Me>) }
      return { body: saved }
    })

    await page.goto('/console/welcome')
    await expect(page.getByRole('heading', { name: 'Welcome, Olive Owner' })).toBeVisible()

    await page.getByRole('button', { name: 'Language: English. Choose a language' }).click()
    await page.getByRole('menuitem', { name: '日本語' }).click()

    await expect(page.getByRole('heading', { name: 'ようこそ、Olive Owner さん' })).toBeVisible()
    await expect(page.getByRole('button', { name: '言語: 日本語。言語を選択' })).toBeVisible()
    expect((await api.lastCall('PATCH', `${base}/me`)).body).toEqual({ locale: 'ja' })

    await page.reload()

    await expect(page.getByRole('heading', { name: 'ようこそ、Olive Owner さん' })).toBeVisible()
    expect((await api.lastCall('GET', `${base}/me`, 2)).headers['accept-language']).toBe('ja')
  })

  test("a console user's saved language wins over the browser's", async ({ page, signIn }) => {
    await signIn({ user: fixtures.me({ locale: 'ja' }) })

    await page.goto('/console/welcome')

    await expect(page.getByRole('heading', { name: 'ようこそ、Olive Owner さん' })).toBeVisible()
  })

  test("a signed-out visitor's choice is remembered in the browser, without saving it anywhere", async ({ page, api }) => {
    api.on('GET', `/v1/account-lookup/${acme.slug}`, { body: acme })

    await page.goto(`/${acme.slug}/sign-in`)
    await expect(page.getByText('Sign in to Acme')).toBeVisible()

    await page.getByRole('button', { name: 'Language: English. Choose a language' }).click()
    await page.getByRole('menuitem', { name: '日本語' }).click()
    await expect(page.getByText('Acme にサインイン')).toBeVisible()

    await page.reload()

    await expect(page.getByText('Acme にサインイン')).toBeVisible()
    expect((await api.lastCall('GET', `/v1/account-lookup/${acme.slug}`, 2)).headers['accept-language']).toBe('ja')
  })

  test.describe('with a Japanese browser', () => {
    test.use({ locale: 'ja-JP' })

    test("a visitor who hasn't chosen sees the browser's language", async ({ page, api }) => {
      api.on('GET', `/v1/account-lookup/${acme.slug}`, { body: acme })

      await page.goto(`/${acme.slug}/sign-in`)

      await expect(page.getByText('Acme にサインイン')).toBeVisible()
    })

    test('a console user who chose English keeps English', async ({ page, signIn }) => {
      await signIn({ user: fixtures.me({ locale: 'en' }) })

      await page.goto('/console/welcome')

      await expect(page.getByRole('heading', { name: 'Welcome, Olive Owner' })).toBeVisible()
    })
  })
})
