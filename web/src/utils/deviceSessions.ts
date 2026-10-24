import type { DeviceSession, DeviceSessionLocation } from '@/types/api'

const METHODS: Record<string, string> = {
  pwd: 'Password',
  otp: 'MFA code',
  fed: 'Identity provider',
}

export function deviceLabel(session: Pick<DeviceSession, 'device_name'>): string {
  return session.device_name ?? 'Unknown device'
}

/** How the user signed in, e.g. "Password and authenticator code". */
export function signInMethods(amr: readonly string[]): string {
  const labels = amr.map((method) => METHODS[method] ?? method)
  if (labels.length === 0) return 'Unknown'
  return labels.length === 1 ? labels[0]! : `${labels.slice(0, -1).join(', ')} and ${labels[labels.length - 1]}`
}

function countryName(code: string, locale: string): string {
  try {
    return new Intl.DisplayNames([locale], { type: 'region' }).of(code) ?? code
  } catch {
    return code
  }
}

/** "Dublin, Leinster, Ireland", from the most specific to the country; null when nothing is known. */
export function formatLocation(location: DeviceSessionLocation | null, locale = 'en'): string | null {
  if (!location) return null
  const parts = [location.city, location.region, location.country_code ? countryName(location.country_code, locale) : null]
  const known = parts.filter((part, index): part is string => part !== null && parts.indexOf(part) === index)
  return known.length > 0 ? known.join(', ') : null
}
