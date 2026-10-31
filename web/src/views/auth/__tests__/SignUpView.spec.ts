import { beforeEach, describe, expect, it, vi } from 'vitest'

import { field, mountAuthView, submit } from './authViewHelpers'
import SignUpView from '../SignUpView.vue'
import { authService } from '@/services/auth'
import { useSessionStore } from '@/stores/session'
import type { User } from '@/types/api'

type Service = typeof authService

vi.mock('@/services/auth', async (importOriginal) => ({
  ...(await importOriginal<typeof import('@/services/auth')>()),
  authService: { signUp: vi.fn<Service['signUp']>(), signIn: vi.fn<Service['signIn']>() },
}))

const service = vi.mocked(authService)
const acme = { uid: 'acc_1', name: 'Acme Ltd', slug: 'acme-ltd' }

async function signUp() {
  const mounted = await mountAuthView(SignUpView, '/sign-up')
  await field(mounted.wrapper, 'Organisation name').setValue('Acme Ltd')
  await field(mounted.wrapper, 'Your name').setValue('Olive Owner')
  await field(mounted.wrapper, 'Email').setValue('olive@acme.test')
  await field(mounted.wrapper, 'Password').setValue('correct horse battery staple')
  await submit(mounted.wrapper, 'Create account')
  return mounted
}

describe('SignUpView', () => {
  beforeEach(() => {
    vi.resetAllMocks()
    localStorage.clear()
    service.signUp.mockResolvedValue({ account: acme, user: {} as User })
  })

  it('suggests the alias from the organisation name, until it is edited', async () => {
    const { wrapper } = await mountAuthView(SignUpView, '/sign-up')

    await field(wrapper, 'Organisation name').setValue('Acme Ltd')
    expect(field(wrapper, 'Account alias').element).toHaveProperty('value', 'acme-ltd')

    await field(wrapper, 'Account alias').setValue('acme')
    await field(wrapper, 'Organisation name').setValue('Acme Limited')
    expect(field(wrapper, 'Account alias').element).toHaveProperty('value', 'acme')
  })

  it('sends the owner to sign in themselves when signing in needs another step', async () => {
    service.signIn.mockResolvedValue({ challenge: 'mfa_setup', session: 'sess_1' })
    const { router } = await signUp()

    expect(router.currentRoute.value.fullPath).toBe('/acme-ltd/sign-in')
    expect(useSessionStore().isAuthenticated).toBe(false)
    expect(useSessionStore().lastAccountSlug()).toBe('acme-ltd')
  })

  it('also sends them to sign in when signing in straight away fails', async () => {
    service.signIn.mockRejectedValue(new Error('email_not_verified'))
    const { router } = await signUp()

    expect(router.currentRoute.value.fullPath).toBe('/acme-ltd/sign-in')
  })
})
