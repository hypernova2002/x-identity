import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useEndUserActions, type EndUserActionResult } from '../useEndUserActions'
import { projectAdminService } from '@/services/project'
import type { EndUser } from '@/types/api'

type Service = typeof projectAdminService

vi.mock('@/services/project', () => ({
  projectAdminService: {
    updateEndUser: vi.fn<Service['updateEndUser']>(),
    resetEndUserMfa: vi.fn<Service['resetEndUserMfa']>(),
    signOutEndUser: vi.fn<Service['signOutEndUser']>(),
    resendInvitation: vi.fn<Service['resendInvitation']>(),
    deleteEndUser: vi.fn<Service['deleteEndUser']>(),
  },
}))

const ids = { accountUid: 'acct_1', projectUid: 'proj_1' }
const endUser = { uid: 'eu_1', email: 'pat@example.com', status: 'active', mfa_enabled: true } as EndUser

describe('useEndUserActions', () => {
  beforeEach(() => {
    vi.resetAllMocks()
  })

  it('asks for confirmation before disabling, and disables once confirmed', async () => {
    const onDone = vi.fn<(result: EndUserActionResult) => void>()
    vi.mocked(projectAdminService.updateEndUser).mockResolvedValue({ ...endUser, status: 'disabled' })
    const actions = useEndUserActions(() => ids, onDone)

    actions.request('disable', endUser)

    expect(actions.pending.value).toEqual({ action: 'disable', endUser })
    expect(projectAdminService.updateEndUser).not.toHaveBeenCalled()

    await actions.confirm()

    expect(projectAdminService.updateEndUser).toHaveBeenCalledWith('acct_1', 'proj_1', 'eu_1', { status: 'disabled' })
    expect(actions.pending.value).toBeNull()
    expect(onDone).toHaveBeenCalledWith(expect.objectContaining({ action: 'disable', updated: { ...endUser, status: 'disabled' } }))
  })

  it('resends an invitation without confirmation', async () => {
    const onDone = vi.fn<(result: EndUserActionResult) => void>()
    vi.mocked(projectAdminService.resendInvitation).mockResolvedValue(null)
    const actions = useEndUserActions(() => ids, onDone)

    actions.request('resend_invitation', endUser)
    await vi.waitFor(() => expect(onDone).toHaveBeenCalled())

    expect(actions.pending.value).toBeNull()
    expect(projectAdminService.resendInvitation).toHaveBeenCalledWith('acct_1', 'proj_1', 'eu_1')
  })

  it('reports a deleted user as gone', async () => {
    const onDone = vi.fn<(result: EndUserActionResult) => void>()
    vi.mocked(projectAdminService.deleteEndUser).mockResolvedValue(null)
    const actions = useEndUserActions(() => ids, onDone)

    actions.request('delete', endUser)
    await actions.confirm()

    expect(onDone).toHaveBeenCalledWith(expect.objectContaining({ action: 'delete', updated: null }))
  })

  it('keeps the confirmation open when the action fails', async () => {
    const onDone = vi.fn<(result: EndUserActionResult) => void>()
    vi.mocked(projectAdminService.signOutEndUser).mockRejectedValue(new Error('offline'))
    const actions = useEndUserActions(() => ids, onDone)

    actions.request('sign_out', endUser)
    await actions.confirm()

    expect(actions.pending.value).not.toBeNull()
    expect(actions.perform.error.value).not.toBeNull()
    expect(onDone).not.toHaveBeenCalled()
  })
})
