import { describe, expect, it } from 'vitest'
import { mount } from '@vue/test-utils'
import OpenVue from 'openvue/config'

import BaseInput from '../BaseInput.vue'

function mountInput(props: InstanceType<typeof BaseInput>['$props']) {
  return mount(BaseInput, {
    props,
    global: { plugins: [[OpenVue, { unstyled: true }]] },
  })
}

describe('BaseInput', () => {
  it('associates the label with the input', () => {
    const wrapper = mountInput({ label: 'Email' })

    expect(wrapper.find('label').attributes('for')).toBe(wrapper.find('input').attributes('id'))
  })

  it('emits model updates as the user types', async () => {
    const wrapper = mountInput({ label: 'Email', modelValue: '' })

    await wrapper.find('input').setValue('dan@example.com')

    const updates = wrapper.emitted('update:modelValue') ?? []
    expect(updates[updates.length - 1]).toEqual(['dan@example.com'])
  })

  it('marks the input invalid and describes it with the error message', () => {
    const wrapper = mountInput({ label: 'Email', error: 'Enter a valid email address.' })
    const input = wrapper.find('input')
    const errorId = input.attributes('aria-describedby')

    expect([input.attributes('aria-invalid'), wrapper.find(`#${errorId}`).text()]).toEqual([
      'true',
      'Error: Enter a valid email address.',
    ])
  })
})
