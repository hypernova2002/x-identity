import { beforeEach, describe, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'

import { useProjectStore } from '../project'
import { useSessionStore } from '../session'
import { projectService } from '@/services/account'
import type { Me, Project, ProjectMember } from '@/types/api'

vi.mock('@/services/account', () => ({
  meService: { get: vi.fn<() => Promise<Me>>() },
  projectService: {
    list: vi.fn<(accountUid: string, page: number) => Promise<{ items: Project[]; total: number; perPage: number }>>(),
    get: vi.fn<(accountUid: string, projectUid: string) => Promise<Project>>(),
    listMembers: vi.fn<(accountUid: string, projectUid: string) => Promise<{ items: ProjectMember[]; total: number; perPage: number }>>(),
  },
}))

function project(uid: string): Project {
  return {
    uid,
    name: uid,
    allow_self_sign_up: true,
    confirm_sign_up_url: null,
    reset_password_url: null,
    accept_invitation_url: null,
    token_issuer: `https://api.test/${uid}`,
    created_at: '2026-10-21T00:00:00Z',
    updated_at: '2026-10-21T00:00:00Z',
  }
}

function signInAs(role: Me['role']) {
  const session = useSessionStore()
  session.start({ uid: 'acct_1', name: 'Acme', slug: 'acme' }, { access_token: 'a', refresh_token: 'r', token_type: 'Bearer', expires_in: 900 })
  session.me = { uid: 'usr_1', role } as Me
}

describe('useProjectStore', () => {
  beforeEach(() => {
    localStorage.clear()
    setActivePinia(createPinia())
    vi.mocked(projectService.list).mockResolvedValue({ items: [project('proj_a'), project('proj_b')], total: 2, perPage: 25 })
    vi.mocked(projectService.get).mockImplementation(async (_account, uid) => project(uid))
    vi.mocked(projectService.listMembers).mockResolvedValue({ items: [], total: 0, perPage: 25 })
  })

  it('opens the first project when none has been used yet', async () => {
    signInAs('owner')
    const store = useProjectStore()

    await store.loadProjects()

    expect(store.defaultProjectUid()).toBe('proj_a')
  })

  it('opens the last project used', async () => {
    signInAs('owner')
    const store = useProjectStore()
    await store.loadProjects()

    await store.select('proj_b')
    setActivePinia(createPinia())
    signInAs('owner')
    const reloaded = useProjectStore()
    await reloaded.loadProjects()

    expect(reloaded.defaultProjectUid()).toBe('proj_b')
  })

  it('keeps the list in step when a project is renamed or deleted', async () => {
    signInAs('owner')
    const store = useProjectStore()
    await store.loadProjects()

    store.upsert({ ...project('proj_a'), name: 'Production' })
    store.remove('proj_b')

    expect(store.projects.map((existing) => existing.name)).toEqual(['Production'])
  })

  it('gives project developers developer access only', async () => {
    signInAs('member')
    vi.mocked(projectService.listMembers).mockResolvedValue({
      items: [{ user_uid: 'usr_1', name: 'Mia', email: 'mia@acme.test', role: 'developer', created_at: '' }],
      total: 1,
      perPage: 25,
    })
    const store = useProjectStore()

    await store.select('proj_a')

    expect(store.access).toEqual({ admin: false, developer: true, accountAdmin: false })
  })
})
