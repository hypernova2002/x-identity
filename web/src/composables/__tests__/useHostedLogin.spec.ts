import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useHostedLogin } from '../useHostedLogin'
import { hostedLoginService } from '@/services/hostedLogin'
import type { HostedLoginDetails, MfaEnrollment } from '@/types/api'
import { getPasskey } from '@/utils/webauthn'

type Service = typeof hostedLoginService

vi.mock('@/utils/webauthn', async (original) => ({
  ...(await original<typeof import('@/utils/webauthn')>()),
  passkeyAutofillAvailable: async () => false,
  getPasskey: vi.fn<typeof import('@/utils/webauthn').getPasskey>(),
}))

vi.mock('@/services/hostedLogin', () => ({
  hostedLoginService: {
    details: vi.fn<Service['details']>(),
    signIn: vi.fn<Service['signIn']>(),
    discover: vi.fn<Service['discover']>(),
    respondToChallenge: vi.fn<Service['respondToChallenge']>(),
    startMfaSetup: vi.fn<Service['startMfaSetup']>(),
    signUp: vi.fn<Service['signUp']>(),
    confirmSignUp: vi.fn<Service['confirmSignUp']>(),
    resendConfirmation: vi.fn<Service['resendConfirmation']>(),
    forgotPassword: vi.fn<Service['forgotPassword']>(),
    confirmForgotPassword: vi.fn<Service['confirmForgotPassword']>(),
    passkeyOptions: vi.fn<Service['passkeyOptions']>(),
    passkeySignIn: vi.fn<Service['passkeySignIn']>(),
    passkeyChallengeOptions: vi.fn<Service['passkeyChallengeOptions']>(),
    providerUrl: vi.fn<Service['providerUrl']>(),
  },
}))

const interaction = { accountUid: 'acct_1', projectUid: 'proj_1', interaction: 'int_1' }
const details: HostedLoginDetails = {
  account_name: 'Acme',
  project_name: 'Shop',
  app_name: 'Web shop',
  allow_self_sign_up: true,
  passkeys: false,
  login_hint: 'casey@shop.test',
  home_realm_discovery: false,
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

  it('sends company emails to their identity provider, and asks everyone else for a password', async () => {
    vi.mocked(hostedLoginService.details).mockResolvedValue({ ...details, home_realm_discovery: true, login_hint: null })
    vi.mocked(hostedLoginService.providerUrl).mockReturnValue('http://api.test/providers/idp_acme')
    const login = await loaded()
    expect(login.passwordStep.value).toBe(false)

    vi.mocked(hostedLoginService.discover).mockResolvedValueOnce({ identity_provider_uid: 'idp_acme' })
    login.email.value = 'jane@acme.com'
    await login.discover.run()
    expect(navigate).toHaveBeenCalledWith('http://api.test/providers/idp_acme')

    vi.mocked(hostedLoginService.discover).mockResolvedValueOnce({ identity_provider_uid: null })
    login.email.value = 'casey@shop.test'
    await login.discover.run()
    expect(login.passwordStep.value).toBe(true)
  })

  it('returns to sign-in after a password reset', async () => {
    const login = await loaded()

    await login.forgotPassword.run()
    await login.resetPassword.run({ code: '123456', password: 'a-new-password' })

    expect(hostedLoginService.confirmForgotPassword).toHaveBeenCalledWith(interaction, 'casey@shop.test', '123456', 'a-new-password')
    expect(login.step.value).toBe('sign-in')
    expect(login.notice.value).toContain('password was changed')
  })

  describe('passkeys', () => {
    const assertion = { id: 'cred' } as Awaited<ReturnType<typeof getPasskey>>

    beforeEach(() => {
      vi.mocked(hostedLoginService.passkeyOptions).mockResolvedValue({ authentication_id: 'auth_1', public_key: { challenge: 'AQID' } })
      vi.mocked(hostedLoginService.passkeyChallengeOptions).mockResolvedValue({ authentication_id: 'auth_2', public_key: { challenge: 'BAU' } })
      vi.mocked(getPasskey).mockResolvedValue(assertion)
    })

    it('signs in with a passkey and sends the browser on', async () => {
      vi.mocked(hostedLoginService.passkeySignIn).mockResolvedValue({ redirect_to: 'http://api.test/resume?ticket=p' })
      const login = await loaded()

      await login.signInWithPasskey.run()

      expect(getPasskey).toHaveBeenCalledWith({ challenge: 'AQID' }, expect.objectContaining({ autofill: false }))
      expect(hostedLoginService.passkeySignIn).toHaveBeenCalledWith(interaction, 'auth_1', assertion)
      expect(navigate).toHaveBeenCalledWith('http://api.test/resume?ticket=p')
    })

    it('stays put without an error when the user cancels the prompt', async () => {
      vi.mocked(getPasskey).mockRejectedValue(new DOMException('cancelled', 'NotAllowedError'))
      const login = await loaded()

      await login.signInWithPasskey.run()

      expect(hostedLoginService.passkeySignIn).not.toHaveBeenCalled()
      expect(login.passkeyError.value).toBeNull()
      expect(login.signInWithPasskey.error.value).toBeNull()
    })

    it('answers a second-factor challenge with a passkey', async () => {
      vi.mocked(hostedLoginService.signIn).mockResolvedValue({ challenge: 'otp', session: 'sess_1', mfa_methods: ['otp', 'passkey'] })
      vi.mocked(hostedLoginService.respondToChallenge).mockResolvedValue({ redirect_to: 'http://api.test/resume' })
      const login = await loaded()
      await login.signIn.run('secret-password')

      await login.answerWithPasskey.run()

      expect(hostedLoginService.passkeyChallengeOptions).toHaveBeenCalledWith(interaction, 'sess_1')
      expect(hostedLoginService.respondToChallenge).toHaveBeenCalledWith(interaction, {
        challenge: 'passkey',
        session: 'sess_1',
        authentication_id: 'auth_2',
        credential: assertion,
      })
      expect(navigate).toHaveBeenCalledWith('http://api.test/resume')
    })
  })
})
