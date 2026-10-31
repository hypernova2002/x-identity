import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount, type VueWrapper } from '@vue/test-utils'
import { createPinia, setActivePinia, type Pinia } from 'pinia'
import OpenVue from 'openvue/config'

import LanguageSwitcher from '../LanguageSwitcher.vue'
import { i18n } from '@/i18n'
import { useLocaleStore } from '@/stores/locale'

describe('LanguageSwitcher', () => {
  let pinia: Pinia
  let wrapper: VueWrapper | null = null

  beforeEach(() => {
    pinia = createPinia()
    setActivePinia(pinia)
  })

  afterEach(() => {
    wrapper?.unmount()
    wrapper = null
    document.body.innerHTML = ''
    localStorage.clear()
    i18n.global.locale.value = 'en'
  })

  async function openSwitcher() {
    const mounted = mount(LanguageSwitcher, { attachTo: document.body, global: { plugins: [pinia, [OpenVue, { unstyled: true }]] } })
    wrapper = mounted
    await mounted.get('button[aria-haspopup="menu"]').trigger('click')
    await flushPromises()
    return mounted
  }

  function menuItem(name: string) {
    return [...document.body.querySelectorAll('[role="menuitem"] a')].find((item) => item.textContent?.includes(name)) as HTMLElement
  }

  it('names the current language, with its flag', async () => {
    const wrapper = await openSwitcher()
    const trigger = wrapper.get('button[aria-haspopup="menu"]')

    expect(trigger.attributes('aria-label')).toBe('Language: English. Choose a language')
    expect(trigger.text()).toBe('English')
    expect(trigger.find('svg').exists()).toBe(true)
  })

  it('lists each language in its own language, with its flag, marking the current one', async () => {
    await openSwitcher()

    expect(menuItem('English').textContent).toContain('(current)')
    expect(menuItem('日本語').textContent).not.toContain('(current)')
    expect(menuItem('日本語').querySelector('svg circle')).not.toBeNull()
  })

  it('switches language straight away', async () => {
    const wrapper = await openSwitcher()

    menuItem('日本語').click()
    await flushPromises()

    expect(i18n.global.locale.value).toBe('ja')
    expect(wrapper.get('button[aria-haspopup="menu"]').attributes('aria-label')).toBe('言語: 日本語。言語を選択')
  })

  it("keeps the new language when saving it to the user fails", async () => {
    useLocaleStore().signedIn('en', vi.fn<(locale: string) => Promise<unknown>>().mockRejectedValue(new Error('offline')))
    await openSwitcher()

    menuItem('日本語').click()
    await flushPromises()

    expect(i18n.global.locale.value).toBe('ja')
  })
})
