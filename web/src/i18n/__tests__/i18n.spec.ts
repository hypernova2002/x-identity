import { afterEach, describe, expect, it, vi } from 'vitest'

import { formatList, i18n, pickLocale } from '@/i18n'
import en from '@/locales/en'

function keys(messages: object, prefix = ''): string[] {
  return Object.entries(messages).flatMap(([key, value]) =>
    typeof value === 'string' ? [`${prefix}${key}`] : keys(value as object, `${prefix}${key}.`),
  )
}

describe('i18n', () => {
  afterEach(() => vi.restoreAllMocks())

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

  it('writes lists the way the language does', () => {
    expect(formatList(['name', 'email', 'role'])).toBe('name, email, and role')
  })
})
