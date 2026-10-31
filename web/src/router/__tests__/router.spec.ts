import { beforeEach, describe, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'

import { meService } from '@/services/account'
import { authService } from '@/services/auth'
import type { Me, TokenSet } from '@/types/api'

// The router picks its routes when it loads, so this must be the console's origin by then.
vi.hoisted(() => vi.stubEnv('VITE_CONSOLE_URL', window.location.origin))

vi.mock('@/services/auth', () => ({
  authService: {
    refresh: vi.fn<(accountUid: string, refreshToken: string) => Promise<TokenSet>>(),
    signOut: vi.fn<(accountUid: string, refreshToken: string) => Promise<null>>(),
  },
}))
vi.mock('@/services/account', () => ({
  meService: { get: vi.fn<(accountUid: string) => Promise<Me>>(), update: vi.fn<(accountUid: string) => Promise<Me>>() },
}))

const { default: router, safeRedirect } = await import('@/router')

const account = { uid: 'acc_1', name: 'Acme', slug: 'acme' }
const tokens: TokenSet = { access_token: 'at', refresh_token: 'rt', token_type: 'Bearer', expires_in: 900 }

function savedSession() {
  localStorage.setItem('x-identity.session', JSON.stringify({ account, refreshToken: 'rt' }))
  localStorage.setItem('x-identity.last-account', JSON.stringify('acme'))
}

function signedInAs(role: Me['role']) {
  savedSession()
  vi.mocked(authService.refresh).mockResolvedValue(tokens)
  vi.mocked(meService.get).mockResolvedValue({ uid: 'usr_1', role, locale: null } as Me)
}

async function visit(path: string) {
  await router.push(path)
  return router.currentRoute.value
}

describe('router', () => {
  beforeEach(async () => {
    vi.resetAllMocks()
    localStorage.clear()
    setActivePinia(createPinia())
    await router.push('/sign-up')
  })

  it('lets anyone open the sign-in pages', async () => {
    expect((await visit('/acme/sign-in')).name).toBe('sign-in')
    expect(authService.refresh).not.toHaveBeenCalled()
  })

  it('sends signed-out visitors to sign in, keeping where they were going', async () => {
    const route = await visit('/console/security?tab=devices')

    expect(route.path).toBe('/sign-in')
    expect(route.query.redirect).toBe('/console/security?tab=devices')
  })

  it('sends them to their own account when this browser has signed in before', async () => {
    localStorage.setItem('x-identity.last-account', JSON.stringify('acme'))

    expect((await visit('/console/security')).fullPath).toBe('/acme/sign-in?redirect=/console/security')
  })

  it('restores a saved session, then loads who is signed in', async () => {
    signedInAs('member')

    expect((await visit('/console/security')).name).toBe('security')
    expect(authService.refresh).toHaveBeenCalledWith('acc_1', 'rt')
    expect(meService.get).toHaveBeenCalledWith('acc_1')
  })

  it('signs out when the saved session has ended', async () => {
    savedSession()
    vi.mocked(authService.refresh).mockRejectedValue(new Error('invalid_token'))

    expect((await visit('/console/security')).name).toBe('sign-in')
    expect(localStorage.getItem('x-identity.session')).toBeNull()
  })

  it("signs out when who's signed in can't be loaded", async () => {
    signedInAs('member')
    vi.mocked(meService.get).mockRejectedValue(new Error('user_disabled'))

    expect((await visit('/console/security')).name).toBe('sign-in')
    expect(localStorage.getItem('x-identity.session')).toBeNull()
  })

  it('keeps account administration to owners and admins, sending members to the projects', async () => {
    signedInAs('member')
    expect((await visit('/console/account/users')).name).toBe('projects')

    setActivePinia(createPinia())
    await router.push('/sign-up')
    signedInAs('admin')
    expect((await visit('/console/account/users')).name).toBe('users')
  })

  it('redirects pages from before the sidebar was regrouped, keeping their query', async () => {
    signedInAs('member')

    expect((await visit('/console/projects/prj_1/app-clients?search=web')).fullPath).toBe('/console/projects/prj_1/applications?search=web&kind_eq=oidc')
    expect((await visit('/console/projects/prj_1/authentication')).name).toBe('project-auth-sign-in')
  })

  it("shows the not-found page for paths that don't exist", async () => {
    expect((await visit('/nowhere/at/all')).name).toBe('not-found')
  })
})

describe('safeRedirect', () => {
  it('follows paths inside the app', () => {
    expect(safeRedirect('/console/security?tab=devices')).toBe('/console/security?tab=devices')
  })

  it('never follows a redirect to another site', () => {
    expect(safeRedirect('https://evil.test/console')).toBe('/console')
    expect(safeRedirect('//evil.test/console')).toBe('/console')
    expect(safeRedirect(['/console/security'])).toBe('/console')
    expect(safeRedirect(undefined, '/welcome')).toBe('/welcome')
  })
})
