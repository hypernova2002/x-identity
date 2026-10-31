import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'

import CopyButton from '../CopyButton.vue'

describe('CopyButton', () => {
  const writeText = vi.fn<(text: string) => Promise<void>>()

  beforeEach(() => {
    vi.useFakeTimers()
    Object.defineProperty(navigator, 'clipboard', { value: { writeText }, configurable: true })
  })

  afterEach(() => {
    vi.useRealTimers()
    writeText.mockReset()
  })

  const mountButton = () => mount(CopyButton, { props: { value: 'v=spf1 include:x-identity', label: 'TXT record value' } })

  it('copies the value and says so, briefly', async () => {
    writeText.mockResolvedValue()
    const wrapper = mountButton()

    await wrapper.get('button').trigger('click')
    await flushPromises()

    expect(writeText).toHaveBeenCalledWith('v=spf1 include:x-identity')
    expect(wrapper.get('button').text()).toBe('Copied')
    expect(wrapper.get('[role="status"]').text()).toBe('TXT record value copied')

    await vi.advanceTimersByTimeAsync(2000)
    expect(wrapper.get('button').text()).toBe('Copy')
    expect(wrapper.get('[role="status"]').text()).toBe('')
  })

  it("says when the browser won't copy, so the user can do it themselves", async () => {
    writeText.mockRejectedValue(new DOMException('denied', 'NotAllowedError'))
    const wrapper = mountButton()

    await wrapper.get('button').trigger('click')
    await flushPromises()

    expect(wrapper.get('button').text()).toBe('Copy failed')
    expect(wrapper.get('[role="status"]').text()).toBe("Couldn't copy TXT record value; select it and copy it yourself.")
  })

  it('names what it copies for assistive technology', () => {
    expect(mountButton().get('button').attributes('aria-label')).toBe('Copy TXT record value')
  })
})
