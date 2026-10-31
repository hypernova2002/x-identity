import { afterEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount, type VueWrapper } from '@vue/test-utils'
import OpenVue from 'openvue/config'

import BaseActionMenu, { type ActionMenuItem } from '../BaseActionMenu.vue'

describe('BaseActionMenu', () => {
  let wrapper: VueWrapper | null = null

  afterEach(() => {
    wrapper?.unmount()
    document.body.innerHTML = ''
  })

  async function open(items: ActionMenuItem[]) {
    wrapper = mount(BaseActionMenu, { props: { items, label: 'More actions for casey@shop.test' }, attachTo: document.body, global: { plugins: [[OpenVue, { unstyled: true }]] } })
    await wrapper.get('button').trigger('click')
    await flushPromises()
  }

  const entries = () => [...document.body.querySelectorAll('[role="menu"] > li')].map((entry) => (entry.getAttribute('role') === 'separator' ? '---' : entry.textContent?.trim()))

  it('names the menu, and its button, for assistive technology', async () => {
    await open([{ label: 'Edit', action: vi.fn<() => void>() }])

    expect(wrapper!.get('button').attributes()).toMatchObject({ 'aria-label': 'More actions for casey@shop.test', 'aria-haspopup': 'menu' })
    expect(document.body.querySelector('[role="menu"]')?.getAttribute('aria-label')).toBe('More actions for casey@shop.test')
  })

  it('sets dangerous actions apart at the end, after any separators asked for', async () => {
    await open([
      { label: 'Delete', danger: true, action: vi.fn<() => void>() },
      { label: 'Edit', action: vi.fn<() => void>() },
      { label: 'Resend invitation', separatorBefore: true, action: vi.fn<() => void>() },
    ])

    expect(entries()).toEqual(['Edit', '---', 'Resend invitation', '---', 'Delete'])
  })

  it('runs the chosen action', async () => {
    const edit = vi.fn<() => void>()
    await open([{ label: 'Edit', action: edit }])

    document.body.querySelector<HTMLElement>('[role="menuitem"] a')!.click()

    expect(edit).toHaveBeenCalledOnce()
  })

  it('marks the current entry, with a tick and in words', async () => {
    await open([
      { label: 'Production', current: true, action: vi.fn<() => void>() },
      { label: 'Staging', action: vi.fn<() => void>() },
    ])

    expect(entries()).toEqual(['✓Production(current)', 'Staging'])
  })
})
