import { afterEach, describe, expect, it, vi } from 'vitest'

import { chooseLocale, currentLocale, formatList, i18n, pickLocale, showBrowserLocale, showUserLocale } from '@/i18n'
import en from '@/locales/en'
import ja from '@/locales/ja'

function keys(messages: object, prefix = ''): string[] {
  return Object.entries(messages).flatMap(([key, value]) =>
    typeof value === 'string' ? [`${prefix}${key}`] : keys(value as object, `${prefix}${key}.`),
  )
}

function browserLanguages(languages: string[]) {
  vi.spyOn(navigator, 'languages', 'get').mockReturnValue(languages)
}

describe('i18n', () => {
  afterEach(() => {
    vi.restoreAllMocks()
    localStorage.clear()
    i18n.global.locale.value = 'en'
  })

  it('picks the first supported browser language, by language alone', () => {
    expect(pickLocale(['de-DE', 'en-GB'])).toBe('en')
  })

  it('falls back to English', () => {
    expect(pickLocale(['fr', 'de'])).toBe('en')
    expect(pickLocale([])).toBe('en')
  })

  it('compiles every English message', () => {
    const warn = vi.spyOn(console, 'warn')
    const error = vi.spyOn(console, 'error')

    for (const key of keys(en)) i18n.global.t(key, { count: 2 }, 2)

    expect([warn.mock.calls, error.mock.calls]).toEqual([[], []])
  })

  it('compiles every Japanese message', () => {
    const warn = vi.spyOn(console, 'warn')
    const error = vi.spyOn(console, 'error')

    for (const key of keys(ja)) i18n.global.t(key, { count: 2 }, { locale: 'ja', plural: 2 })

    expect([warn.mock.calls, error.mock.calls]).toEqual([[], []])
  })

  it('writes lists the way the language does', () => {
    expect(formatList(['name', 'email', 'role'])).toBe('name, email, and role')

    showUserLocale('ja')

    expect(formatList(['name', 'email', 'role'])).toBe('name、email、role')
  })

  it('shows a chosen language, marks the page with it, and remembers it in this browser', () => {
    chooseLocale('ja')

    expect(currentLocale()).toBe('ja')
    expect(document.documentElement.lang).toBe('ja')
    expect(localStorage.getItem('x-identity:locale')).toBe('ja')
  })

  it("still switches when the browser won't store the choice", () => {
    vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
      throw new DOMException('blocked', 'SecurityError')
    })

    chooseLocale('ja')

    expect(currentLocale()).toBe('ja')
  })

  it("shows a signed-in user's language, or the browser's when they haven't chosen", () => {
    browserLanguages(['ja-JP', 'en'])

    showUserLocale('en')
    expect(currentLocale()).toBe('en')

    showUserLocale(null)
    expect(currentLocale()).toBe('ja')

    showUserLocale('fr')
    expect(currentLocale()).toBe('ja')
  })

  it("goes back to this browser's choice, or its language, after signing out", () => {
    browserLanguages(['ja'])
    showUserLocale('en')

    showBrowserLocale()
    expect(currentLocale()).toBe('ja')

    localStorage.setItem('x-identity:locale', 'en')
    showBrowserLocale()
    expect(currentLocale()).toBe('en')
  })

  it('ignores a stored language it has no messages for', () => {
    browserLanguages(['ja'])
    localStorage.setItem('x-identity:locale', 'fr')

    showBrowserLocale()

    expect(currentLocale()).toBe('ja')
  })
})
