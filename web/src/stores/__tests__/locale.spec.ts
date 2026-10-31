import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'

import { i18n } from '@/i18n'
import { useLocaleStore } from '@/stores/locale'

type Save = (locale: string) => Promise<unknown>

describe('useLocaleStore', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.spyOn(navigator, 'languages', 'get').mockReturnValue(['en-GB'])
  })

  afterEach(() => {
    vi.restoreAllMocks()
    localStorage.clear()
    i18n.global.locale.value = 'en'
  })

  it("shows a signed-in user's language", () => {
    const store = useLocaleStore()

    store.signedIn('ja', vi.fn<Save>())

    expect(store.locale).toBe('ja')
  })

  it("saves a signed-in user's choice to them, after switching at once", async () => {
    const store = useLocaleStore()
    let shownWhileSaving: string | null = null
    const save = vi.fn<Save>(async () => {
      shownWhileSaving = store.locale
    })
    store.signedIn(null, save)

    await store.choose('ja')

    expect(save).toHaveBeenCalledWith('ja')
    expect(shownWhileSaving).toBe('ja')
    expect(localStorage.getItem('x-identity:locale')).toBe('ja')
  })

  it("keeps the new language when saving it fails, and reports the failure", async () => {
    const store = useLocaleStore()
    store.signedIn(null, vi.fn<Save>().mockRejectedValue(new Error('offline')))

    await expect(store.choose('ja')).rejects.toThrow('offline')

    expect(store.locale).toBe('ja')
  })

  it("stops saving choices after signing out, and shows this browser's own choice", async () => {
    const store = useLocaleStore()
    const save = vi.fn<Save>()
    localStorage.setItem('x-identity:locale', 'en')
    store.signedIn('ja', save)

    store.signedOut()
    expect(store.locale).toBe('en')

    await store.choose('ja')
    expect(save).not.toHaveBeenCalled()
    expect(store.locale).toBe('ja')
  })
})
