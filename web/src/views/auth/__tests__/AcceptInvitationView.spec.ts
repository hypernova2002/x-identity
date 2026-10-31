import { beforeEach, describe, expect, it, vi } from 'vitest'

import { field, mountAuthView, submit } from './authViewHelpers'
import AcceptInvitationView from '../AcceptInvitationView.vue'
import { authService } from '@/services/auth'
import { ApiError } from '@/services/http'
import type { User } from '@/types/api'

type Service = typeof authService

vi.mock('@/services/auth', () => ({
  authService: { lookupAccount: vi.fn<Service['lookupAccount']>(), acceptInvitation: vi.fn<Service['acceptInvitation']>() },
}))

const service = vi.mocked(authService)

async function accept() {
  const mounted = await mountAuthView(AcceptInvitationView, '/acme/accept-invitation?token=invite-token')
  await field(mounted.wrapper, 'Your name').setValue('Nia New')
  await field(mounted.wrapper, 'Password').setValue('correct horse battery staple')
  await submit(mounted.wrapper, 'Accept invitation')
  return mounted
}

describe('AcceptInvitationView', () => {
  beforeEach(() => {
    vi.resetAllMocks()
    service.lookupAccount.mockResolvedValue({ uid: 'acc_1', name: 'Acme', slug: 'acme' })
  })

  it("creates the user from the invitation's link, then points them to sign in", async () => {
    service.acceptInvitation.mockResolvedValue({ email: 'nia@acme.test' } as User)
    const { wrapper } = await accept()

    expect(service.acceptInvitation).toHaveBeenCalledWith('acc_1', 'invite-token', 'Nia New', 'correct horse battery staple')
    expect(wrapper.text()).toContain('Join Acme')
    expect(wrapper.text()).toContain('Your user nia@acme.test has been created.')
    expect(wrapper.get('a').attributes('href')).toBe('/acme/sign-in')
  })

  it("explains an invitation that doesn't work any more", async () => {
    service.acceptInvitation.mockRejectedValue(new ApiError('invalid_token', 400))
    const { wrapper } = await accept()

    expect(wrapper.text()).toContain("This invitation doesn't work")
    expect(wrapper.text()).toContain('Ask an administrator to invite you again.')
  })

  it('shows what was wrong with a field', async () => {
    service.acceptInvitation.mockRejectedValue(new ApiError('validation_failed', 422, { details: [{ field: 'password', code: 'too_short', params: { count: 12 } }] }))
    const { wrapper } = await accept()

    expect(wrapper.text()).toContain('12')
    expect(wrapper.find('[role="alert"]').exists()).toBe(false)
  })
})
