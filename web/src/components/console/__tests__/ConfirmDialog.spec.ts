import { afterEach, describe, expect, it } from 'vitest'
import { flushPromises, mount, type VueWrapper } from '@vue/test-utils'
import OpenVue from 'openvue/config'

import ConfirmDialog from '../ConfirmDialog.vue'
import { ApiError } from '@/services/http'

describe('ConfirmDialog', () => {
  let wrapper: VueWrapper | null = null

  afterEach(() => {
    wrapper?.unmount()
    document.body.innerHTML = ''
  })

  async function open(props: Record<string, unknown> = {}) {
    wrapper = mount(ConfirmDialog, {
      props: { visible: true, title: 'Sign out this device?', confirmLabel: 'Sign out device', danger: true, ...props },
      slots: { default: 'Chrome on Mac will need to sign in again.' },
      attachTo: document.body,
      global: { plugins: [[OpenVue, { unstyled: true }]] },
    })
    await flushPromises()
  }

  const button = (name: string) => [...document.body.querySelectorAll('button')].find((candidate) => candidate.textContent?.trim() === name)!

  it('asks with a title, an explanation and a dangerous confirm button', async () => {
    await open()

    expect(document.body.querySelector('[role="dialog"]')?.textContent).toContain('Chrome on Mac will need to sign in again.')
    expect(button('Sign out device').className).toContain('bg-danger')
  })

  it('emits confirm, or closes on cancel', async () => {
    await open()

    button('Sign out device').click()
    expect(wrapper!.emitted('confirm')).toHaveLength(1)

    button('Cancel').click()
    expect(wrapper!.emitted('update:visible')).toEqual([[false]])
  })

  it('shows why confirming failed', async () => {
    await open({ error: new ApiError('not_found', 404) })

    expect(document.body.querySelector('[role="alert"]')?.textContent).toBeTruthy()
  })
})
