import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useAppAccess } from '../useAppAccess'
import { projectAdminService } from '@/services/project'
import type { AppAssignment, Group } from '@/types/api'

type Service = typeof projectAdminService

vi.mock('@/services/project', () => ({
  projectAdminService: {
    listAssignments: vi.fn<Service['listAssignments']>(),
    listGroups: vi.fn<Service['listGroups']>(),
    listEndUsers: vi.fn<Service['listEndUsers']>(),
    assign: vi.fn<Service['assign']>(),
    unassign: vi.fn<Service['unassign']>(),
  },
}))

const service = vi.mocked(projectAdminService)
const app = { kind: 'app_client' as const, uid: 'app_1', name: 'Web shop' }

function assignment(uid: string, principal_type: AppAssignment['principal_type'], principal_uid: string): AppAssignment {
  return { uid, principal_type, principal_uid, principal_label: principal_uid, created_at: '2026-10-01T09:00:00Z' }
}

function group(uid: string, name: string, member_count = 2): Group {
  return { uid, name, member_count, description: null, default_for_new_users: false, created_at: '', updated_at: '' }
}

async function loaded(assignments: AppAssignment[]) {
  service.listAssignments.mockResolvedValue({ items: assignments, total: assignments.length, perPage: 100 })
  const access = useAppAccess()
  await access.load.run('acc_1', 'prj_1', app)
  return access
}

describe('useAppAccess', () => {
  beforeEach(() => {
    vi.resetAllMocks()
  })

  it("loads the app's assignments", async () => {
    const access = await loaded([assignment('asg_1', 'group', 'grp_staff')])

    expect(service.listAssignments).toHaveBeenCalledWith('acc_1', 'prj_1', 'app_client', 'app_1')
    expect(access.isAssigned('group', 'grp_staff')).toBe(true)
    expect(access.isAssigned('end_user', 'grp_staff')).toBe(false)
  })

  it('offers only groups not assigned yet, with their member counts, and counts accordingly', async () => {
    const access = await loaded([assignment('asg_1', 'group', 'grp_staff')])
    service.listGroups.mockResolvedValue({ items: [group('grp_staff', 'Staff'), group('grp_beta', 'Beta testers', 5)], total: 30, perPage: 20 })

    await expect(access.searchUnassignedGroups('t')).resolves.toEqual({ items: [{ label: 'Beta testers (5)', value: 'grp_beta' }], total: 29 })
    expect(service.listGroups).toHaveBeenCalledWith('acc_1', 'prj_1', expect.objectContaining({ search: 't' }))
  })

  it('adds and removes assignments', async () => {
    const access = await loaded([assignment('asg_1', 'group', 'grp_staff')])
    service.assign.mockResolvedValue(assignment('asg_2', 'end_user', 'eu_casey'))

    await access.assign.run('end_user', 'eu_casey')
    expect(service.assign).toHaveBeenCalledWith('acc_1', 'prj_1', 'app_client', 'app_1', 'end_user', 'eu_casey')
    expect(access.isAssigned('end_user', 'eu_casey')).toBe(true)

    await access.unassign.run(access.assignments.value[0]!)
    expect(service.unassign).toHaveBeenCalledWith('acc_1', 'prj_1', 'app_client', 'app_1', 'asg_1')
    expect(access.assignments.value.map((existing) => existing.uid)).toEqual(['asg_2'])
  })

  it('keeps the assignments when removing one fails', async () => {
    const access = await loaded([assignment('asg_1', 'group', 'grp_staff')])
    service.unassign.mockRejectedValue(new Error('offline'))

    await access.unassign.run(access.assignments.value[0]!)

    expect(access.assignments.value).toHaveLength(1)
    expect(access.unassign.error.value).toBeTruthy()
  })
})
