import { describe, expect, it } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import { createMemoryHistory, createRouter } from 'vue-router'
import OpenVue from 'openvue/config'

import CustomDomainSwitch from '../CustomDomainSwitch.vue'

const router = createRouter({
  history: createMemoryHistory(),
  routes: [
    { path: '/', component: { render: () => null } },
    { path: '/projects/:projectUid/domain', name: 'project-domain', component: { render: () => null } },
  ],
})

function mountSwitch(props: Partial<InstanceType<typeof CustomDomainSwitch>['$props']> = {}) {
  return mount(CustomDomainSwitch, {
    props: { kind: 'app', name: 'Wiki', onCustomDomain: false, domain: 'login.acme.com', projectUid: 'proj_1', canChange: true, saving: false, error: null, ...props },
    global: { plugins: [router, [OpenVue, { unstyled: true }]] },
    attachTo: document.body,
  })
}

const button = (wrapper: ReturnType<typeof mountSwitch>, name: string) => wrapper.findAll('button').find((candidate) => candidate.text() === name)

describe('CustomDomainSwitch', () => {
  it('switches to the verified domain after warning what the other side must update', async () => {
    const wrapper = mountSwitch()
    expect(wrapper.text()).toContain("Uses the project's standard URLs.")

    await button(wrapper, 'Switch to login.acme.com')!.trigger('click')
    await flushPromises()
    expect(document.body.textContent).toContain('re-import the metadata in Wiki')

    const confirm = Array.from(document.body.querySelectorAll('button')).find((candidate) => candidate.textContent?.trim() === 'Switch')!
    confirm.click()
    expect(wrapper.emitted('change')).toEqual([[true]])
    wrapper.unmount()
  })

  it('offers switching back, and tells providers to send the new metadata to their admin', async () => {
    const wrapper = mountSwitch({ kind: 'provider', name: 'Acme Okta', onCustomDomain: true })
    expect(wrapper.text()).toContain('login.acme.com')

    await button(wrapper, 'Switch to the standard URLs')!.trigger('click')
    await flushPromises()
    expect(document.body.textContent).toContain('send the new metadata URL to its identity provider admin')
    wrapper.unmount()
  })

  it('points to the custom domain setup when the project has none, and hides the switch without permission', () => {
    const none = mountSwitch({ domain: null })
    expect(none.text()).toContain('Project settings › Custom domain')
    expect(none.findAll('button')).toHaveLength(0)

    expect(mountSwitch({ canChange: false }).findAll('button')).toHaveLength(0)
  })
})
