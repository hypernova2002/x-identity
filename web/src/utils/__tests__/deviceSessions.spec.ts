import { describe, expect, it } from 'vitest'

import { deviceLabel, formatLocation, signInMethods } from '../deviceSessions'

describe('deviceLabel', () => {
  it('falls back for devices recorded before details were kept', () => {
    expect(deviceLabel({ device_name: 'Chrome on Mac' })).toBe('Chrome on Mac')
    expect(deviceLabel({ device_name: null })).toBe('Unknown device')
  })
})

describe('signInMethods', () => {
  it('names the methods used', () => {
    expect(signInMethods(['pwd', 'otp'])).toBe('Password and MFA code')
    expect(signInMethods(['fed'])).toBe('Identity provider')
    expect(signInMethods([])).toBe('Unknown')
  })
})

describe('formatLocation', () => {
  it('goes from city to country, naming the country', () => {
    expect(formatLocation({ city: 'Dublin', region: 'Leinster', country_code: 'IE' })).toBe('Dublin, Leinster, Ireland')
  })

  it('skips what the database doesn\'t know, and repeats', () => {
    expect(formatLocation({ city: null, region: null, country_code: 'NL' })).toBe('Netherlands')
    expect(formatLocation({ city: 'Singapore', region: 'Singapore', country_code: null })).toBe('Singapore')
    expect(formatLocation(null)).toBeNull()
  })
})
