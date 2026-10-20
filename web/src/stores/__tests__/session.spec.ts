import { beforeEach, describe, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'

import { useSessionStore } from '../session'
import { authService } from '@/services/auth'
import type { TokenSet } from '@/types/api'

vi.mock('@/services/auth', () => ({
  authService: {
    refresh: vi.fn<(accountUid: string, refreshToken: string) => Promise<TokenSet>>(),
    signOut: vi.fn<(accountUid: string, refreshToken: string) => Promise<null>>(),
  },
}))

const account = { uid: 'acct_1', name: 'Acme', slug: 'acme' }

function tokens(suffix: string): TokenSet {
  return { access_token: `access-${suffix}`, refresh_token: `refresh-${suffix}`, token_type: 'Bearer', expires_in: 900 }
}

describe('useSessionStore', () => {
  beforeEach(() => {
    localStorage.clear()
    vi.mocked(authService.refresh).mockReset()
    setActivePinia(createPinia())
  })

  it('is authenticated after a session starts', () => {
    const session = useSessionStore()

    session.start(account, tokens('1'))

    expect(session.isAuthenticated).toBe(true)
  })

  it('remembers the account alias for the next sign-in', () => {
    useSessionStore().start(account, tokens('1'))

    expect(useSessionStore().lastAccountSlug()).toBe('acme')
  })

  it('restores a persisted session by refreshing its tokens', async () => {
    useSessionStore().start(account, tokens('1'))
    setActivePinia(createPinia())
    vi.mocked(authService.refresh).mockResolvedValue(tokens('2'))

    const restored = await useSessionStore().restore()

    expect([restored, vi.mocked(authService.refresh).mock.calls[0]]).toEqual([true, ['acct_1', 'refresh-1']])
  })

  it('shares one refresh between concurrent callers', async () => {
    useSessionStore().start(account, tokens('1'))
    setActivePinia(createPinia())
    vi.mocked(authService.refresh).mockResolvedValue(tokens('2'))
    const session = useSessionStore()

    await Promise.all([session.restore(), session.restore()])

    expect(authService.refresh).toHaveBeenCalledTimes(1)
  })

  it('clears the session when the refresh token is rejected', async () => {
    useSessionStore().start(account, tokens('1'))
    setActivePinia(createPinia())
    vi.mocked(authService.refresh).mockRejectedValue(new Error('invalid_token'))
    const session = useSessionStore()

    await session.restore()

    expect([session.isAuthenticated, localStorage.getItem('x-identity.session')]).toEqual([false, null])
  })
})
