import { describe, expect, it } from 'vitest'

import { secretStatus } from '../appClientSecrets'
import type { AppClientSecret } from '@/types/api'

const now = new Date('2026-10-24T12:00:00Z')

function secret(overrides: Partial<AppClientSecret> = {}): AppClientSecret {
  return { uid: 'sec_1', last_four: 'abcd', expires_at: null, revoked_at: null, last_used_at: null, created_at: '2026-10-01T00:00:00Z', usable: true, ...overrides }
}

describe('secretStatus', () => {
  it('calls a secret without an end date active', () => {
    expect(secretStatus(secret(), now)).toEqual({ tone: 'success', label: 'Active' })
  })

  it('warns until when a replaced secret keeps working', () => {
    expect(secretStatus(secret({ expires_at: '2026-10-31T12:00:00Z' }), now)).toMatchObject({ tone: 'warning', label: expect.stringContaining('Works until') })
  })

  it('reports expired and revoked secrets', () => {
    expect(secretStatus(secret({ expires_at: '2026-10-20T00:00:00Z' }), now).label).toBe('Expired')
    expect(secretStatus(secret({ revoked_at: '2026-10-22T00:00:00Z' }), now).label).toBe('Revoked')
  })
})
