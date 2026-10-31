import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount, type VueWrapper } from '@vue/test-utils'
import { createPinia, setActivePinia, type Pinia } from 'pinia'
import { createMemoryHistory, createRouter } from 'vue-router'
import OpenVue from 'openvue/config'

import UserMenu from '../UserMenu.vue'
import { useProjectStore } from '@/stores/project'
import { useSessionStore } from '@/stores/session'
import type { Me, Project } from '@/types/api'

const Empty = { template: '<div />' }

describe('UserMenu', () => {
  let pinia: Pinia
  let wrapper: VueWrapper | null = null

  beforeEach(() => {
    pinia = createPinia()
    setActivePinia(pinia)
  })

  afterEach(() => {
    wrapper?.unmount()
    document.body.innerHTML = ''
  })

  async function open() {
    const session = useSessionStore()
    session.account = { uid: 'acc_1', name: 'Acme', slug: 'acme' }
    session.me = { name: 'Olive Owner', email: 'olive@acme.test', role: 'owner', account: { name: 'Acme' } } as Me
    const router = createRouter({
      history: createMemoryHistory(),
      routes: [
        { path: '/console', component: Empty },
        { path: '/console/security', name: 'security', component: Empty },
        { path: '/:slug/sign-in', component: Empty },
      ],
    })
    await router.push('/console')
    wrapper = mount(UserMenu, { attachTo: document.body, global: { plugins: [pinia, router, [OpenVue, { unstyled: true }]] } })
    await wrapper.get('button').trigger('click')
    await flushPromises()
    return { router, session }
  }

  const item = (name: string) => [...document.body.querySelectorAll<HTMLElement>('[role="menuitem"] a')].find((link) => link.textContent?.includes(name))!

  it("shows the user's initials, and who they are in which account", async () => {
    await open()

    expect(wrapper!.get('button').attributes('aria-label')).toBe('Your profile: Olive Owner')
    expect(wrapper!.get('button').text()).toBe('OO')
    expect(document.body.textContent).toContain('olive@acme.test')
    expect(document.body.textContent).toContain('Account owner of Acme')
  })

  it('opens the profile page', async () => {
    const { router } = await open()

    item('Profile and security').click()
    await flushPromises()

    expect(router.currentRoute.value.name).toBe('security')
  })

  it("signs out, forgets the account's projects, and goes to the account's sign-in", async () => {
    const { router, session } = await open()
    const signOut = vi.spyOn(session, 'signOut').mockResolvedValue()
    useProjectStore().projects = [{ uid: 'prj_1' } as Project]

    item('Sign out').click()
    await flushPromises()

    expect(signOut).toHaveBeenCalled()
    expect(useProjectStore().projects).toEqual([])
    expect(router.currentRoute.value.fullPath).toBe('/acme/sign-in')
  })
})
