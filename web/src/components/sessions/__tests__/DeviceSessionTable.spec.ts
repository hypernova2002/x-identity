import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import { createMemoryHistory, createRouter } from 'vue-router'
import OpenVue from 'openvue/config'

import DeviceSessionTable from '../DeviceSessionTable.vue'
import type { Page } from '@/services/http'
import type { ListParams } from '@/services/list'
import type { DeviceSession } from '@/types/api'

function device(uid: string, overrides: Partial<DeviceSession> = {}): DeviceSession {
  return {
    uid,
    device_name: 'Chrome on Mac',
    device_type: 'desktop',
    ip: '203.0.113.10',
    user_agent: null,
    location: { city: 'Dublin', region: 'Leinster', country_code: 'IE' },
    amr: ['pwd'],
    created_at: '2026-10-20T09:00:00Z',
    last_seen_at: '2026-10-23T09:00:00Z',
    current: false,
    ...overrides,
  }
}

async function mountTable(props: Partial<InstanceType<typeof DeviceSessionTable>['$props']> = {}) {
  const fetchPage = vi.fn<(params: ListParams) => Promise<Page<DeviceSession>>>().mockResolvedValue({
    items: [device('ses_this', { current: true }), device('ses_phone', { device_name: 'Mobile Safari on iPhone' })],
    total: 2,
    perPage: 25,
  })
  const router = createRouter({ history: createMemoryHistory(), routes: [{ path: '/', component: { render: () => null } }] })
  const wrapper = mount(DeviceSessionTable, {
    props: { fetchPage, ...props },
    attachTo: document.body,
    global: { plugins: [router, [OpenVue, { unstyled: true }]] },
  })
  await flushPromises()
  return { wrapper, fetchPage }
}

const buttonNamed = (name: string) => [...document.body.querySelectorAll('button')].find((button) => button.textContent?.trim() === name)

describe('DeviceSessionTable', () => {
  // OpenVue's Select, used for sorting the stacked rows, asks for matchMedia, which jsdom lacks.
  beforeEach(() => {
    vi.stubGlobal('matchMedia', (query: string) => ({ matches: false, media: query, addEventListener() {}, removeEventListener() {} }))
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('lists devices with their approximate location, marking this one', async () => {
    const { wrapper, fetchPage } = await mountTable()

    expect(wrapper.find('ul[aria-label="Signed-in devices"]').exists()).toBe(true)

    expect(fetchPage).toHaveBeenCalledWith(expect.objectContaining({ sort: '-last_seen_at', page: 1 }))
    expect(wrapper.text()).toContain('This device')
    expect(wrapper.text()).toContain('Dublin, Leinster, Ireland')
    expect(wrapper.text()).toContain('DB-IP')
    wrapper.unmount()
  })

  it('signs another device out after confirmation, but offers no sign-out for this one', async () => {
    const signOut = vi.fn<(session: DeviceSession) => Promise<unknown>>().mockResolvedValue(null)
    const { wrapper, fetchPage } = await mountTable({ signOut })

    expect(wrapper.find('button[aria-label="Sign out Chrome on Mac"]').exists()).toBe(false)
    await wrapper.get('button[aria-label="Sign out Mobile Safari on iPhone"]').trigger('click')
    expect(signOut).not.toHaveBeenCalled()

    buttonNamed('Sign out device')!.click()
    await flushPromises()

    expect(signOut).toHaveBeenCalledWith(expect.objectContaining({ uid: 'ses_phone' }))
    expect(fetchPage).toHaveBeenCalledTimes(2)
    wrapper.unmount()
  })

  it('signs out every other device when offered', async () => {
    const signOutOthers = vi.fn<() => Promise<unknown>>().mockResolvedValue(null)
    const { wrapper } = await mountTable({ signOutOthers })

    buttonNamed('Sign out all other devices')!.click()
    await flushPromises()
    buttonNamed('Sign out other devices')!.click()
    await flushPromises()

    expect(signOutOthers).toHaveBeenCalledOnce()
    wrapper.unmount()
  })
})
