import { computed } from 'vue'
import { defineStore } from 'pinia'

import { chooseLocale, i18n, showBrowserLocale, showUserLocale, type SupportedLocale } from '@/i18n'

type SaveLocale = (locale: SupportedLocale) => Promise<unknown>

/**
 * The language shown, and where a choice is saved: on the signed-in console user or end user, so it
 * follows them to other browsers, and in this browser for the sign-in pages.
 */
export const useLocaleStore = defineStore('locale', () => {
  const locale = computed(() => i18n.global.locale.value)
  let save: SaveLocale | null = null

  /** A user signed in: show their language (the browser's when they haven't chosen), and save choices to them. */
  function signedIn(preference: string | null, saveToUser: SaveLocale) {
    save = saveToUser
    showUserLocale(preference)
  }

  function signedOut() {
    save = null
    showBrowserLocale()
  }

  /** Switches language at once; a signed-in user's choice is saved to them too. */
  async function choose(next: SupportedLocale) {
    chooseLocale(next)
    await save?.(next)
  }

  return { locale, signedIn, signedOut, choose }
})
