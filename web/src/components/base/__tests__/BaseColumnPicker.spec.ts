import { afterEach, describe, expect, it } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import OpenVue from 'openvue/config'

import BaseColumnPicker from '../BaseColumnPicker.vue'

const columns = [
  { key: 'email', label: 'End user', locked: true },
  { key: 'status', label: 'Status' },
  { key: 'groups', label: 'Groups' },
]

describe('BaseColumnPicker', () => {
  let wrapper: ReturnType<typeof mount<typeof BaseColumnPicker>> | null = null

  afterEach(() => {
    wrapper?.unmount()
    document.body.innerHTML = ''
  })

  async function open(hidden: string[]) {
    const mounted = mount(BaseColumnPicker, {
      props: { columns, hidden, 'onUpdate:hidden': (next: string[]) => mounted.setProps({ hidden: next }) },
      attachTo: document.body,
      global: { plugins: [[OpenVue, { unstyled: true }]] },
    })
    wrapper = mounted
    await wrapper.get('button').trigger('click')
    await flushPromises()
  }

  const checkbox = (label: string) =>
    [...document.body.querySelectorAll('label')].find((candidate) => candidate.textContent?.trim() === label)!.control as HTMLInputElement

  it('ticks the shown columns, and always shows a locked one', async () => {
    await open(['groups', 'email'])

    expect([checkbox('End user').checked, checkbox('Status').checked, checkbox('Groups').checked]).toEqual([true, true, false])
    expect(checkbox('End user').disabled).toBe(true)
  })

  it('hides and shows columns', async () => {
    await open(['groups'])

    checkbox('Status').click()
    await flushPromises()
    checkbox('Groups').click()
    await flushPromises()

    expect(wrapper!.props('hidden')).toEqual(['status'])
    expect([checkbox('Status').checked, checkbox('Groups').checked]).toEqual([false, true])
  })
})
