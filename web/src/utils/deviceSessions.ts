import type { DeviceSession, DeviceSessionLocation } from '@/types/api'
import { currentLocale, formatList, i18n } from '@/i18n'


export function deviceLabel(session: Pick<DeviceSession, 'device_name'>): string {
  return session.device_name ?? i18n.global.t('security.devices.unknownDevice')
}

/** How the user signed in, e.g. "Password and authenticator code". */
export function signInMethods(amr: readonly string[]): string {
  const { t, te } = i18n.global
  const labels = amr.map((method) => (te(`security.devices.methods.${method}`) ? t(`security.devices.methods.${method}`) : method))
  return labels.length === 0 ? t('security.devices.unknown') : formatList(labels)
}

function countryName(code: string, locale: string): string {
  try {
    return new Intl.DisplayNames([locale], { type: 'region' }).of(code) ?? code
  } catch {
    return code
  }
}

/** "Dublin, Leinster, Ireland", from the most specific to the country; null when nothing is known. */
export function formatLocation(location: DeviceSessionLocation | null, locale = currentLocale()): string | null {
  if (!location) return null
  const parts = [location.city, location.region, location.country_code ? countryName(location.country_code, locale) : null]
  const known = parts.filter((part, index): part is string => part !== null && parts.indexOf(part) === index)
  return known.length > 0 ? known.join(', ') : null
}
