const dateTimeFormat = new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' })

export function formatDateTime(value: string | null): string {
  return value ? dateTimeFormat.format(new Date(value)) : '—'
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

const DURATION_UNITS: [number, string][] = [
  [86_400, 'day'],
  [3_600, 'hour'],
  [60, 'minute'],
  [1, 'second'],
]

/** Seconds as a readable duration, e.g. 5400 → "1 hour 30 minutes". Uses at most two units. */
export function formatDuration(totalSeconds: number): string {
  if (totalSeconds <= 0) return '0 seconds'

  const parts: string[] = []
  let remaining = Math.floor(totalSeconds)
  for (const [size, unit] of DURATION_UNITS) {
    const count = Math.floor(remaining / size)
    if (count > 0 && parts.length < 2) {
      parts.push(`${count} ${unit}${count === 1 ? '' : 's'}`)
      remaining -= count * size
    }
  }
  return parts.join(' ')
}
