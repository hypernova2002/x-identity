import { createI18n } from 'vue-i18n'

import en from '@/locales/en'
import ja from '@/locales/ja'

export type MessageSchema = typeof en

declare module 'vue-i18n' {
  // eslint-disable-next-line @typescript-eslint/no-empty-object-type
  export interface DefineLocaleMessage extends MessageSchema {}
}

export const SUPPORTED_LOCALES = ['en', 'ja'] as const
export type SupportedLocale = (typeof SUPPORTED_LOCALES)[number]

/** Each language's name in that language, for the language switcher. */
export const LOCALE_NAMES: Record<SupportedLocale, string> = { en: 'English', ja: '日本語' }

const STORAGE_KEY = 'x-identity:locale'

export function isSupportedLocale(value: unknown): value is SupportedLocale {
  return SUPPORTED_LOCALES.includes(value as SupportedLocale)
}

/** The first of the browser's languages we have messages for, matching on the language alone (en-GB → en). */
export function pickLocale(languages: readonly string[]): SupportedLocale {
  for (const language of languages) {
    const base = language.toLowerCase().split('-')[0]
    const match = SUPPORTED_LOCALES.find((locale) => locale === base)
    if (match) return match
  }
  return 'en'
}

function browserLocale(): SupportedLocale {
  return pickLocale(typeof navigator === 'undefined' ? [] : navigator.languages)
}

/** The language last chosen in this browser, used while nobody is signed in. */
function storedLocale(): SupportedLocale | null {
  try {
    const value = localStorage.getItem(STORAGE_KEY)
    return isSupportedLocale(value) ? value : null
  } catch {
    return null
  }
}

export const i18n = createI18n<[MessageSchema], SupportedLocale, false>({
  legacy: false,
  locale: storedLocale() ?? browserLocale(),
  fallbackLocale: 'en',
  messages: { en, ja },
})

function show(locale: SupportedLocale) {
  i18n.global.locale.value = locale
  if (typeof document !== 'undefined') document.documentElement.lang = locale
}

show(i18n.global.locale.value)

/** Switches to a language chosen in this browser, and remembers it here. */
export function chooseLocale(locale: SupportedLocale) {
  show(locale)
  try {
    localStorage.setItem(STORAGE_KEY, locale)
  } catch {
    // The choice then lasts until the page is reloaded.
  }
}

/** Shows a signed-in user's language; without one (null), the browser's. */
export function showUserLocale(locale: string | null) {
  show(isSupportedLocale(locale) ? locale : browserLocale())
}

/** Back to this browser's own choice, e.g. after signing out. */
export function showBrowserLocale() {
  show(storedLocale() ?? browserLocale())
}

/** The current locale, for Intl formatting. */
export function currentLocale(): string {
  return i18n.global.locale.value
}

/** A list as the current language writes it, e.g. "a, b and c". */
export function formatList(items: readonly string[]): string {
  return new Intl.ListFormat(currentLocale(), { type: 'conjunction' }).format(items)
}
