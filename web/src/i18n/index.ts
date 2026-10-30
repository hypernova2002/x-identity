import { createI18n } from 'vue-i18n'

import en from '@/locales/en'

export type MessageSchema = typeof en

declare module 'vue-i18n' {
  // eslint-disable-next-line @typescript-eslint/no-empty-object-type
  export interface DefineLocaleMessage extends MessageSchema {}
}

export const SUPPORTED_LOCALES = ['en'] as const
export type SupportedLocale = (typeof SUPPORTED_LOCALES)[number]

/** The first of the browser's languages we have messages for, matching on the language alone (en-GB → en). */
export function pickLocale(languages: readonly string[]): SupportedLocale {
  for (const language of languages) {
    const base = language.toLowerCase().split('-')[0]
    const match = SUPPORTED_LOCALES.find((locale) => locale === base)
    if (match) return match
  }
  return 'en'
}

const locale = pickLocale(typeof navigator === 'undefined' ? [] : navigator.languages)

export const i18n = createI18n<[MessageSchema], SupportedLocale, false>({
  legacy: false,
  locale,
  fallbackLocale: 'en',
  messages: { en },
})

if (typeof document !== 'undefined') document.documentElement.lang = locale

/** The current locale, for Intl formatting. */
export function currentLocale(): string {
  return i18n.global.locale.value
}

/** A list as the current language writes it, e.g. "a, b and c". */
export function formatList(items: readonly string[]): string {
  return new Intl.ListFormat(currentLocale(), { type: 'conjunction' }).format(items)
}
