import { currentLocale, i18n } from '@/i18n'

const formats = new Map<string, Intl.DateTimeFormat>()

/** A date format for the current language, made once per language. */
function dateFormat(options: Intl.DateTimeFormatOptions): Intl.DateTimeFormat {
  const key = `${currentLocale()} ${JSON.stringify(options)}`
  let format = formats.get(key)
  if (!format) {
    format = new Intl.DateTimeFormat(currentLocale(), options)
    formats.set(key, format)
  }
  return format
}

export function formatDateTime(value: string | null): string {
  return value ? dateFormat({ dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value)) : '—'
}

/** A calendar date such as 2026-10-25, in the viewer's format, without shifting it across time zones. */
export function formatDate(value: string): string {
  const [year, month, day] = value.split('-').map(Number)
  return year && month && day ? dateFormat({ dateStyle: 'medium' }).format(new Date(year, month - 1, day)) : value
}

/** Splits a comma- or newline-separated list, dropping blanks. */
export function parseList(value: string): string[] {
  return value
    .split(/[,\n]/)
    .map((item) => item.trim())
    .filter((item) => item !== '')
}

export function slugify(value: string): string {
  return value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 40)
}

const DURATION_UNITS = [
  [86_400, 'days'],
  [3_600, 'hours'],
  [60, 'minutes'],
  [1, 'seconds'],
] as const

/** Seconds as a readable duration, e.g. 5400 → "1 hour 30 minutes". Uses at most two units. */
export function formatDuration(totalSeconds: number): string {
  const { t } = i18n.global
  if (totalSeconds <= 0) return t('common.duration.seconds', 0)

  const parts: string[] = []
  let remaining = Math.floor(totalSeconds)
  for (const [size, unit] of DURATION_UNITS) {
    const count = Math.floor(remaining / size)
    if (count > 0 && parts.length < 2) {
      parts.push(t(`common.duration.${unit}`, count))
      remaining -= count * size
    }
  }
  return t('common.duration.join', { first: parts[0], second: parts[1] ?? '' }).trim()
}
