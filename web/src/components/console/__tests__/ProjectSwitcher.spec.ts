import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import { createPinia, setActivePinia, type Pinia } from 'pinia'
import { createMemoryHistory, createRouter } from 'vue-router'
import OpenVue from 'openvue/config'

import ProjectSwitcher from '../ProjectSwitcher.vue'
import { useProjectStore } from '@/stores/project'
import { useSessionStore } from '@/stores/session'
import type { Me, Project } from '@/types/api'

const Empty = { template: '<div />' }

function project(uid: string, name: string): Project {
  return { uid, name, token_issuer: `https://api.test/${uid}` } as Project
}

describe('ProjectSwitcher', () => {
  let pinia: Pinia

  beforeEach(() => {
    pinia = createPinia()
    setActivePinia(pinia)
    useProjectStore().projects = [project('prj_1', 'Production'), project('prj_2', 'Staging')]
  })

  afterEach(() => {
    document.body.innerHTML = ''
  })

  async function mountSwitcher(role: Me['role']) {
    useSessionStore().me = { uid: 'usr_1', role } as Me
    const router = createRouter({
      history: createMemoryHistory(),
      routes: [
        { path: '/projects', name: 'projects', component: Empty },
        { path: '/projects/:projectUid', name: 'project', component: Empty },
        { path: '/projects/:projectUid/end-users', name: 'project-end-users', component: Empty },
      ],
    })
    await router.push('/projects/prj_1/end-users')
    const wrapper = mount(ProjectSwitcher, {
      props: { currentProjectUid: 'prj_1' },
      attachTo: document.body,
      global: { plugins: [pinia, router, [OpenVue, { unstyled: true }]] },
    })
    await wrapper.get('button[aria-haspopup="menu"]').trigger('click')
    await flushPromises()
    return { wrapper, router }
  }

  it('shows the open project and lists the others', async () => {
    const { wrapper } = await mountSwitcher('member')

    expect(wrapper.get('button[aria-haspopup="menu"]').text()).toContain('Production')
    expect(document.body.textContent).toContain('Staging')
    expect(document.body.textContent).toContain('(current)')
  })

  it('offers project creation to account admins only', async () => {
    await mountSwitcher('member')
    expect(document.body.textContent).not.toContain('Create project')

    document.body.innerHTML = ''
    await mountSwitcher('admin')
    expect(document.body.textContent).toContain('Create project')
  })

  it('keeps the current section when switching project', async () => {
    const { router } = await mountSwitcher('member')

    const staging = [...document.body.querySelectorAll('a')].find((link) => link.textContent?.includes('Staging'))
    staging!.click()
    await flushPromises()

    expect(router.currentRoute.value.fullPath).toBe('/projects/prj_2/end-users')
  })
})
