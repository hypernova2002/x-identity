import { describe, expect, it } from 'vitest'

import { codeChallengeFor, randomUrlSafe } from '../pkce'

describe('PKCE', () => {
  it('derives the RFC 7636 example challenge', async () => {
    await expect(codeChallengeFor('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk')).resolves.toBe('E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM')
  })

  it('makes url-safe random strings without padding', () => {
    expect(randomUrlSafe(32)).toMatch(/^[A-Za-z0-9_-]{43}$/)
  })
})
