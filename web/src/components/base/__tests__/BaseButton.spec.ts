import { describe, expect, it } from 'vitest'
import { mount } from '@vue/test-utils'
import OpenVue from 'openvue/config'

import BaseButton from '../BaseButton.vue'

function mountButton(props: InstanceType<typeof BaseButton>['$props']) {
  return mount(BaseButton, {
    props,
    global: { plugins: [[OpenVue, { unstyled: true }]] },
  })
}

describe('BaseButton', () => {
  it('renders the label', () => {
    const wrapper = mountButton({ label: 'Save' })

    expect(wrapper.text()).toContain('Save')
  })

  it('emits click when pressed', async () => {
    const wrapper = mountButton({ label: 'Save' })

    await wrapper.find('button').trigger('click')

    expect(wrapper.emitted('click')).toHaveLength(1)
  })

  it('is disabled and marked busy while loading', () => {
    const wrapper = mountButton({ label: 'Save', loading: true })
    const button = wrapper.find('button')

    expect([button.attributes('disabled'), button.attributes('aria-busy')]).toEqual(['', 'true'])
  })

  it('does not emit click when disabled', async () => {
    const wrapper = mountButton({ label: 'Save', disabled: true })

    await wrapper.find('button').trigger('click')

    expect(wrapper.emitted('click')).toBeUndefined()
  })
})
