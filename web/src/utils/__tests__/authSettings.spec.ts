import { describe, expect, it } from 'vitest'

import { AUTH_SETTINGS_FIELDS, pickFields } from '../authSettings'

describe('pickFields', () => {
  it("keeps only the section's fields, so saving it leaves the others alone", () => {
    const values = { otp_digits: 6, mfa_requirement: 'optional' as const, password_min_length: 12, access_token_ttl_seconds: 900 }

    expect(pickFields(values, AUTH_SETTINGS_FIELDS.mfa)).toEqual({ otp_digits: 6, mfa_requirement: 'optional' })
  })

  it("leaves out fields the values don't have", () => {
    expect(pickFields({ password_min_length: 12 }, AUTH_SETTINGS_FIELDS.policies)).toEqual({ password_min_length: 12 })
  })
})

describe('AUTH_SETTINGS_FIELDS', () => {
  it('puts each setting in exactly one section', () => {
    const fields = Object.values(AUTH_SETTINGS_FIELDS).flat()

    expect(new Set(fields).size).toBe(fields.length)
  })
})
