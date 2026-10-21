import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useTestSignIn } from '../useTestSignIn'
import { endUserAuthService } from '@/services/endUserAuth'
import { ApiError } from '@/services/http'
import type { MfaEnrollment, TokenSet } from '@/types/api'

type Service = typeof endUserAuthService

vi.mock('@/services/endUserAuth', () => ({
  endUserAuthService: {
    signIn: vi.fn<Service['signIn']>(),
    respondToChallenge: vi.fn<Service['respondToChallenge']>(),
    startMfaSetup: vi.fn<Service['startMfaSetup']>(),
    refresh: vi.fn<Service['refresh']>(),
    signOut: vi.fn<Service['signOut']>(),
  },
}))

const project = { accountUid: 'acct_1', projectUid: 'proj_1' }
const client = { client_id: 'cl_1' }

function tokenSet(refreshToken: string): TokenSet {
  return { access_token: 'access', id_token: 'id', refresh_token: refreshToken, token_type: 'Bearer', expires_in: 900 }
}

describe('useTestSignIn', () => {
  beforeEach(() => {
    vi.resetAllMocks()
  })

  it('keeps the tokens when sign-in succeeds straight away', async () => {
    vi.mocked(endUserAuthService.signIn).mockResolvedValue(tokenSet('rt_1'))
    const flow = useTestSignIn()

    await flow.signIn.run(project, client, 'pat@example.com', 'secret-password')

    expect(endUserAuthService.signIn).toHaveBeenCalledWith(project, client, 'pat@example.com', 'secret-password')
    expect(flow.tokens.value?.refresh_token).toBe('rt_1')
    expect(flow.challenge.value).toBeNull()
  })

  it('answers an OTP challenge with the same app client', async () => {
    vi.mocked(endUserAuthService.signIn).mockResolvedValue({ challenge: 'otp', session: 'sess_1' })
    vi.mocked(endUserAuthService.respondToChallenge).mockResolvedValue(tokenSet('rt_1'))
    const flow = useTestSignIn()

    await flow.signIn.run(project, client, 'tess@example.com', 'secret-password')
    await flow.answer.run({ code: '123456' })

    expect(endUserAuthService.respondToChallenge).toHaveBeenCalledWith(project, client, {
      challenge: 'otp',
      session: 'sess_1',
      code: '123456',
      new_password: undefined,
    })
    expect(flow.tokens.value).not.toBeNull()
  })

  it('starts MFA setup and shows the recovery codes once it is confirmed', async () => {
    const enrollment = { otp_type: 'totp', secret: 'ABC' } as MfaEnrollment
    vi.mocked(endUserAuthService.signIn).mockResolvedValue({ challenge: 'mfa_setup', session: 'sess_1' })
    vi.mocked(endUserAuthService.startMfaSetup).mockResolvedValue(enrollment)
    vi.mocked(endUserAuthService.respondToChallenge).mockResolvedValue({ ...tokenSet('rt_1'), recovery_codes: ['aaaaa-bbbbb'] })
    const flow = useTestSignIn()

    await flow.signIn.run(project, client, 'new@example.com', 'secret-password')
    const enrollmentShown = flow.enrollment.value
    await flow.answer.run({ code: '123456' })

    expect(endUserAuthService.startMfaSetup).toHaveBeenCalledWith(project, client, 'sess_1')
    expect(enrollmentShown).toEqual(enrollment)
    expect(flow.recoveryCodes.value).toEqual(['aaaaa-bbbbb'])
    expect(flow.tokens.value).not.toBeNull()
  })

  it('sends only the new password for a new_password challenge', async () => {
    vi.mocked(endUserAuthService.signIn).mockResolvedValue({ challenge: 'new_password', session: 'sess_1' })
    vi.mocked(endUserAuthService.respondToChallenge).mockResolvedValue(tokenSet('rt_1'))
    const flow = useTestSignIn()

    await flow.signIn.run(project, client, 'old@example.com', 'secret-password')
    await flow.answer.run({ code: 'ignored', newPassword: 'a-brand-new-password' })

    expect(endUserAuthService.respondToChallenge).toHaveBeenCalledWith(project, client, {
      challenge: 'new_password',
      session: 'sess_1',
      code: undefined,
      new_password: 'a-brand-new-password',
    })
  })

  it('rotates the refresh token, then revokes it on sign-out', async () => {
    vi.mocked(endUserAuthService.signIn).mockResolvedValue(tokenSet('rt_1'))
    vi.mocked(endUserAuthService.refresh).mockResolvedValue(tokenSet('rt_2'))
    const flow = useTestSignIn()

    await flow.signIn.run(project, client, 'pat@example.com', 'secret-password')
    await flow.refresh.run()
    await flow.signOut.run()

    expect(endUserAuthService.refresh).toHaveBeenCalledWith(project, client, 'rt_1')
    expect(endUserAuthService.signOut).toHaveBeenCalledWith(project, client, 'rt_2')
    expect(flow.refreshedAt.value).not.toBeNull()
    expect(flow.signedOut.value).toBe(true)
  })

  it('reports the API error code when sign-in is refused', async () => {
    vi.mocked(endUserAuthService.signIn).mockRejectedValue(new ApiError('user_disabled', 'This user is disabled.', 403))
    const flow = useTestSignIn()

    await flow.signIn.run(project, client, 'dee@example.com', 'secret-password')

    expect(flow.signIn.error.value?.code).toBe('user_disabled')
    expect(flow.tokens.value).toBeNull()
  })
})
