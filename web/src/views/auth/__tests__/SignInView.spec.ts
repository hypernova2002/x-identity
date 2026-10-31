import { beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises } from '@vue/test-utils'

import { button, field, mountAuthView, submit } from './authViewHelpers'
import SignInView from '../SignInView.vue'
import { authService } from '@/services/auth'
import { ApiError } from '@/services/http'
import { useSessionStore } from '@/stores/session'
import type { MfaEnrollment, TokenSet } from '@/types/api'

type Service = typeof authService

vi.mock('@/services/auth', async (importOriginal) => ({
  ...(await importOriginal<typeof import('@/services/auth')>()),
  authService: {
    lookupAccount: vi.fn<Service['lookupAccount']>(),
    signIn: vi.fn<Service['signIn']>(),
    respondToChallenge: vi.fn<Service['respondToChallenge']>(),
    startMfaSetup: vi.fn<Service['startMfaSetup']>(),
  },
}))

const service = vi.mocked(authService)
const acme = { uid: 'acc_1', name: 'Acme', slug: 'acme', passkeys: false }
const tokens: TokenSet = { access_token: 'at', refresh_token: 'rt', token_type: 'Bearer', expires_in: 900 }

async function signInWithPassword() {
  const mounted = await mountAuthView(SignInView, '/acme/sign-in?redirect=/console/security')
  await field(mounted.wrapper, 'Email').setValue('olive@acme.test')
  await field(mounted.wrapper, 'Password').setValue('secret')
  await submit(mounted.wrapper, 'Sign in')
  return mounted
}

describe('SignInView', () => {
  beforeEach(() => {
    vi.resetAllMocks()
    localStorage.clear()
    service.lookupAccount.mockResolvedValue(acme)
  })

  it('asks for the verification code, then finishes signing in', async () => {
    service.signIn.mockResolvedValue({ challenge: 'otp', session: 'sess_1', mfa_methods: ['otp'] })
    service.respondToChallenge.mockResolvedValue(tokens)
    const { wrapper, router } = await signInWithPassword()

    expect(wrapper.text()).toContain('Enter your verification code')
    await field(wrapper, 'Verification code').setValue('123456')
    await submit(wrapper, 'Continue')

    expect(service.respondToChallenge).toHaveBeenCalledWith('acc_1', { challenge: 'otp', session: 'sess_1', code: '123456', new_password: undefined })
    expect(router.currentRoute.value.fullPath).toBe('/console/security')
    expect(useSessionStore().isAuthenticated).toBe(true)
  })

  it('asks for a new password when the old one has expired, showing what was wrong with it', async () => {
    service.signIn.mockResolvedValue({ challenge: 'new_password', session: 'sess_1' })
    service.respondToChallenge.mockRejectedValue(
      new ApiError('validation_failed', 422, { details: [{ field: 'new_password', code: 'needs_number' }] }),
    )
    const { wrapper } = await signInWithPassword()

    expect(wrapper.text()).toContain('Choose a new password')
    await field(wrapper, 'New password').setValue('no digits here')
    await submit(wrapper, 'Continue')

    expect(service.respondToChallenge).toHaveBeenCalledWith('acc_1', { challenge: 'new_password', session: 'sess_1', code: undefined, new_password: 'no digits here' })
    expect(field(wrapper, 'New password').attributes('aria-describedby')).toBeTruthy()
    expect(wrapper.text()).toContain('number')
  })

  it('sets up MFA, then shows the recovery codes before going on', async () => {
    const enrollment: MfaEnrollment = { otp_type: 'totp', digits: 6, step_seconds: 30, secret: 'ABCDEFGH', provisioning_uri: 'otpauth://x', qr_code_svg: '<svg/>' }
    service.signIn.mockResolvedValue({ challenge: 'mfa_setup', session: 'sess_1' })
    service.startMfaSetup.mockResolvedValue(enrollment)
    service.respondToChallenge.mockResolvedValue({ ...tokens, recovery_codes: ['aaaa-bbbb', 'cccc-dddd'] })
    const { wrapper, router } = await signInWithPassword()

    expect(service.startMfaSetup).toHaveBeenCalledWith('acc_1', 'sess_1')
    expect(wrapper.get('img').attributes('alt')).toBe('QR code for your authenticator app')
    await field(wrapper, 'Verification code').setValue('123456')
    await submit(wrapper, 'Continue')

    expect(wrapper.text()).toContain('Multi-factor authentication is on')
    expect(wrapper.text()).toContain('aaaa-bbbb')
    expect(router.currentRoute.value.path).toBe('/acme/sign-in')

    await button(wrapper, "I've saved my codes").trigger('click')
    await flushPromises()
    expect(router.currentRoute.value.fullPath).toBe('/console/security')
  })

  it('offers to start over when the challenge has expired', async () => {
    service.signIn.mockResolvedValue({ challenge: 'otp', session: 'sess_1' })
    service.respondToChallenge.mockRejectedValue(new ApiError('invalid_challenge', 400))
    const { wrapper } = await signInWithPassword()

    await field(wrapper, 'Verification code').setValue('123456')
    await submit(wrapper, 'Continue')

    expect(wrapper.findAll('button').map((candidate) => candidate.text())).toEqual(['Start over'])

    await button(wrapper, 'Start over').trigger('click')
    expect(field(wrapper, 'Password').element).toHaveProperty('value', '')
    expect(wrapper.text()).toContain('Sign in to Acme')
  })

  it("never follows a redirect to another site", async () => {
    service.signIn.mockResolvedValue(tokens)
    const { wrapper, router } = await mountAuthView(SignInView, '/acme/sign-in?redirect=https://evil.test')

    await field(wrapper, 'Email').setValue('olive@acme.test')
    await field(wrapper, 'Password').setValue('secret')
    await submit(wrapper, 'Sign in')

    expect(router.currentRoute.value.fullPath).toBe('/console')
  })
})
