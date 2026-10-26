import { describe, expect, it } from 'vitest'

import { resumedChallenge } from '../resumedChallenge'

describe('resumedChallenge', () => {
  it('resumes a second factor with the methods that can answer it', () => {
    expect(resumedChallenge('otp', 'sess_1', 'otp,passkey')).toEqual({ challenge: 'otp', session: 'sess_1', mfa_methods: ['otp', 'passkey'] })
  })

  it('resumes passkey challenges too', () => {
    expect(resumedChallenge('passkey_setup', 'sess_1', '')).toEqual({ challenge: 'passkey_setup', session: 'sess_1' })
    expect(resumedChallenge('passkey', 'sess_1', 'passkey')).toEqual({ challenge: 'passkey', session: 'sess_1', mfa_methods: ['passkey'] })
  })

  it('ignores unknown challenges and methods, and a missing session', () => {
    expect(resumedChallenge('teleport', 'sess_1', '')).toBeUndefined()
    expect(resumedChallenge('otp', '', 'otp')).toBeUndefined()
    expect(resumedChallenge('otp', 'sess_1', 'otp,carrier-pigeon')).toEqual({ challenge: 'otp', session: 'sess_1', mfa_methods: ['otp'] })
  })
})
