import { beforeEach, describe, expect, it } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import { createPinia, setActivePinia, type Pinia } from 'pinia'
import { createMemoryHistory, createRouter, type RouteRecordRaw } from 'vue-router'

import ConsoleSidebar from '../ConsoleSidebar.vue'
import { useProjectStore } from '@/stores/project'
import { useSessionStore } from '@/stores/session'
import type { Me, Project, ProjectMember } from '@/types/api'

const Empty = { template: '<div />' }
const page = (path: string, name: string, meta: RouteRecordRaw['meta'] = {}): RouteRecordRaw => ({ path, name, component: Empty, meta })
const projectPages = [
  ['', 'project', 'overview'],
  ['applications', 'project-applications', 'applications'],
  ['apis', 'project-apis', 'apis'],
  ['end-users', 'project-end-users', 'end-users'],
  ['end-users/:endUserUid', 'project-end-user', 'end-users'],
  ['groups', 'project-groups', 'groups'],
  ['attributes', 'project-attributes', 'attributes'],
  ['authentication', 'project-authentication', 'authentication'],
  ['identity-providers', 'project-identity-providers', 'identity-providers'],
  ['test-sign-in', 'project-test-sign-in', 'test-sign-in'],
  ['audit-log', 'project-audit-log', 'audit-log'],
  ['settings', 'project-settings', 'settings'],
  ['domain', 'project-domain', 'domain'],
  ['members', 'project-members', 'members'],
] as const

const routes: RouteRecordRaw[] = [
  ...projectPages.map(([path, name, navItem]) => page(`/projects/:projectUid/${path}`, name, { navItem })),
  page('/projects', 'projects', { navItem: 'account-projects', context: 'account' }),
  page('/account/users', 'users', { navItem: 'account-users', context: 'account' }),
  page('/account/authentication', 'auth-settings', { navItem: 'account-authentication', context: 'account' }),
  page('/account/audit-log', 'audit-log', { navItem: 'account-audit-log', context: 'account' }),
]

const shop = { uid: 'prj_1', name: 'Shop' } as Project

describe('ConsoleSidebar', () => {
  let pinia: Pinia

  beforeEach(() => {
    pinia = createPinia()
    setActivePinia(pinia)
  })

  async function render(path: string, { role = 'member', projectRole }: { role?: Me['role']; projectRole?: ProjectMember['role'] } = {}) {
    useSessionStore().me = { uid: 'usr_1', role, account: { name: 'Acme' } } as Me
    const projectStore = useProjectStore()
    projectStore.projects = [shop]
    projectStore.project = shop
    projectStore.members = projectRole ? [{ user_uid: 'usr_1', role: projectRole } as ProjectMember] : []
    const router = createRouter({ history: createMemoryHistory(), routes })
    await router.push(path)
    const wrapper = mount(ConsoleSidebar, {
      props: { currentProjectUid: 'prj_1' },
      global: { plugins: [pinia, router], stubs: { ProjectSwitcher: true } },
    })
    await flushPromises()
    return wrapper
  }

  const links = (wrapper: Awaited<ReturnType<typeof render>>) => wrapper.findAll('nav a').map((link) => link.text())
  const current = (wrapper: Awaited<ReturnType<typeof render>>) => wrapper.findAll('[aria-current="page"]').map((link) => link.text())

  it("groups a project's pages, keeping a list current on its detail pages", async () => {
    const wrapper = await render('/projects/prj_1/end-users/eu_1', { projectRole: 'developer' })

    expect(wrapper.text()).toContain('Directory')
    expect(links(wrapper)).toEqual([
      'Overview',
      'Applications',
      'APIs',
      'End users',
      'Groups',
      'Attributes',
      'Settings',
      'Identity providers',
      'Test sign-in',
      'Audit log',
      'General',
      'Custom domain',
      'Members',
    ])
    expect(current(wrapper)).toEqual(['End users'])
  })

  it("shows the project's audit log only to those who can read it", async () => {
    const viewer = await render('/projects/prj_1/', { projectRole: 'viewer' })

    expect(links(viewer)).not.toContain('Audit log')
  })

  it('swaps in the account navigation on account pages, with only what the user can open', async () => {
    const member = await render('/projects')
    expect(links(member)).toEqual(['Projects'])
    expect(member.text()).toContain('Back to Shop')
    expect(member.text()).not.toContain('End users')

    const admin = await render('/account/users', { role: 'admin' })
    expect(links(admin)).toEqual(['Projects', 'Console users and roles', 'Console sign-in', 'Audit log'])
    expect(current(admin)).toEqual(['Console users and roles'])
  })
})
