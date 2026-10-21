import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useHostedLogin } from '../useHostedLogin'
import { hostedLoginService } from '@/services/hostedLogin'
import type { HostedLoginDetails, MfaEnrollment } from '@/types/api'

type Service = typeof hostedLoginService

vi.mock('@/services/hostedLogin', () => ({
  hostedLoginService: {
    details: vi.fn<Service['details']>(),
    signIn: vi.fn<Service['signIn']>(),
    respondToChallenge: vi.fn<Service['respondToChallenge']>(),
    startMfaSetup: vi.fn<Service['startMfaSetup']>(),
    signUp: vi.fn<Service['signUp']>(),
    confirmSignUp: vi.fn<Service['confirmSignUp']>(),
    resendConfirmation: vi.fn<Service['resendConfirmation']>(),
    forgotPassword: vi.fn<Service['forgotPassword']>(),
    confirmForgotPassword: vi.fn<Service['confirmForgotPassword']>(),
    providerUrl: vi.fn<Service['providerUrl']>(),
  },
}))

const interaction = { accountUid: 'acct_1', projectUid: 'proj_1', interaction: 'int_1' }
const details: HostedLoginDetails = {
  account_name: 'Acme',
  project_name: 'Shop',
  app_name: 'Web shop',
  allow_self_sign_up: true,
  login_hint: 'casey@shop.test',
  identity_providers: [],
}

describe('useHostedLogin', () => {
  const navigate = vi.fn<(url: string) => void>()

  beforeEach(() => {
    vi.resetAllMocks()
    vi.mocked(hostedLoginService.details).mockResolvedValue(details)
  })

  async function loaded() {
    const login = useHostedLogin({ navigate })
    await login.load.run(interaction)
    return login
  }

  it('fills in the email from the login hint', async () => {
    const login = await loaded()

    expect(login.email.value).toBe('casey@shop.test')
  })

  it('sends the browser on once signed in', async () => {
    vi.mocked(hostedLoginService.signIn).mockResolvedValue({ redirect_to: 'http://api.test/resume?ticket=t' })
    const login = await loaded()

    await login.signIn.run('secret-password')

    expect(hostedLoginService.signIn).toHaveBeenCalledWith(interaction, 'casey@shop.test', 'secret-password')
    expect(navigate).toHaveBeenCalledWith('http://api.test/resume?ticket=t')
  })

  it('answers a challenge before sending the browser on', async () => {
    vi.mocked(hostedLoginService.signIn).mockResolvedValue({ challenge: 'otp', session: 'sess_1' })
    vi.mocked(hostedLoginService.respondToChallenge).mockResolvedValue({ redirect_to: 'http://api.test/resume' })
    const login = await loaded()

    await login.signIn.run('secret-password')
    const stepDuringChallenge = login.step.value
    await login.answer.run({ code: '123456' })

    expect(stepDuringChallenge).toBe('challenge')
    expect(hostedLoginService.respondToChallenge).toHaveBeenCalledWith(interaction, {
      challenge: 'otp',
      session: 'sess_1',
      code: '123456',
      new_password: undefined,
    })
    expect(navigate).toHaveBeenCalledWith('http://api.test/resume')
  })

  it('shows recovery codes after MFA setup, then continues', async () => {
    vi.mocked(hostedLoginService.startMfaSetup).mockResolvedValue({ otp_type: 'totp' } as MfaEnrollment)
    vi.mocked(hostedLoginService.respondToChallenge).mockResolvedValue({ redirect_to: 'http://api.test/resume', recovery_codes: ['aaaaa-bbbbb'] })
    const login = useHostedLogin({ navigate })
    await login.load.run(interaction, { challenge: 'mfa_setup', session: 'sess_1' })

    await login.answer.run({ code: '123456' })

    expect(login.enrollment.value).not.toBeNull()
    expect(login.step.value).toBe('recovery-codes')
    expect(navigate).not.toHaveBeenCalled()
    login.continueAfterRecoveryCodes()
    expect(navigate).toHaveBeenCalledWith('http://api.test/resume')
  })

  it('signs in with the new password once the sign-up is confirmed', async () => {
    vi.mocked(hostedLoginService.signIn).mockResolvedValue({ redirect_to: 'http://api.test/resume' })
    const login = await loaded()
    login.email.value = 'new@shop.test'

    await login.signUp.run({ name: ' New ', password: 'brand-new-password' })
    const stepAfterSignUp = login.step.value
    await login.confirmSignUp.run('123456')

    expect(hostedLoginService.signUp).toHaveBeenCalledWith(interaction, { email: 'new@shop.test', password: 'brand-new-password', name: 'New' })
    expect(stepAfterSignUp).toBe('confirm-sign-up')
    expect(hostedLoginService.confirmSignUp).toHaveBeenCalledWith(interaction, 'new@shop.test', '123456')
    expect(hostedLoginService.signIn).toHaveBeenCalledWith(interaction, 'new@shop.test', 'brand-new-password')
  })

  it('returns to sign-in after a password reset', async () => {
    const login = await loaded()

    await login.forgotPassword.run()
    await login.resetPassword.run({ code: '123456', password: 'a-new-password' })

    expect(hostedLoginService.confirmForgotPassword).toHaveBeenCalledWith(interaction, 'casey@shop.test', '123456', 'a-new-password')
    expect(login.step.value).toBe('sign-in')
    expect(login.notice.value).toContain('password was changed')
  })
})
