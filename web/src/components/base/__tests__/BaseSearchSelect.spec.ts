import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import { createMemoryHistory, createRouter } from 'vue-router'
import OpenVue from 'openvue/config'

import BaseSearchSelect from '../BaseSearchSelect.vue'
import type { LookupPage } from '@/services/list'

const router = createRouter({ history: createMemoryHistory(), routes: [{ path: '/', component: { render: () => null } }, { path: '/groups', name: 'groups', component: { render: () => null } }] })

function mountSelect(props: Partial<InstanceType<typeof BaseSearchSelect>['$props']> = {}) {
  const search = vi.fn<(term: string) => Promise<LookupPage>>(async (term) =>
    term
      ? { items: [{ label: 'Support', value: 'grp_support' }], total: 1 }
      : { items: [{ label: 'Admins', value: 'grp_admins' }, { label: 'Staff', value: 'grp_staff' }], total: 57 },
  )
  const wrapper = mount(BaseSearchSelect, {
    props: { label: 'Group', modelValue: '', search, seeAll: { name: 'groups' }, ...props },
    attachTo: document.body,
    global: { plugins: [router, [OpenVue, { unstyled: true }]] },
  })
  return { wrapper, search }
}

describe('BaseSearchSelect', () => {
  beforeEach(() => {
    vi.useFakeTimers()
    vi.stubGlobal('matchMedia', (query: string) => ({ matches: false, media: query, addEventListener() {}, removeEventListener() {} }))
  })

  afterEach(() => {
    vi.useRealTimers()
    vi.unstubAllGlobals()
    document.body.innerHTML = ''
  })

  it('shows the first page, and says when there are more, linking to them all', async () => {
    const { search } = mountSelect()

    document.body.querySelector<HTMLButtonElement>('button')!.click()
    await vi.runAllTimersAsync()
    await flushPromises()

    expect(search).toHaveBeenCalledWith('')
    expect(document.body.textContent).toContain('Admins')
    expect(document.body.textContent).toContain('Showing 2 of 57')
    expect(document.body.querySelector('a')?.textContent).toContain('see them all')
  })

  it('searches the server with what was typed, after a pause', async () => {
    const { wrapper, search } = mountSelect()

    await wrapper.get('input').setValue('sup')
    expect(search).not.toHaveBeenCalledWith('sup')
    await vi.advanceTimersByTimeAsync(300)
    await flushPromises()

    expect(search).toHaveBeenLastCalledWith('sup')
    expect(document.body.textContent).toContain('Support')
  })

  it('names a value it was given, and reports the value picked', async () => {
    const resolveLabel = vi.fn<(value: string) => Promise<string | null>>(async () => 'Staff')
    const { wrapper } = mountSelect({ modelValue: 'grp_staff', resolveLabel })
    await flushPromises()

    expect(resolveLabel).toHaveBeenCalledWith('grp_staff')
    expect((wrapper.get('input').element as HTMLInputElement).value).toBe('Staff')

    await wrapper.get('input').setValue('sup')
    await vi.advanceTimersByTimeAsync(300)
    await flushPromises()
    document.body.querySelector<HTMLElement>('[role="option"]')!.click()
    await flushPromises()

    const emitted = wrapper.emitted('update:modelValue')!
    expect(emitted[emitted.length - 1]).toEqual(['grp_support'])
  })
})
