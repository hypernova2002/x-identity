import { describe, expect, it } from 'vitest'

import { decodeJwt } from '../jwt'

function segment(value: unknown): string {
  const bytes = new TextEncoder().encode(JSON.stringify(value))
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

describe('decodeJwt', () => {
  it('reads the header and claims', () => {
    const token = `${segment({ alg: 'ES256', kid: 'k1' })}.${segment({ sub: 'eu_1', name: 'Zoë' })}.signature`

    expect(decodeJwt(token)).toEqual({ header: { alg: 'ES256', kid: 'k1' }, payload: { sub: 'eu_1', name: 'Zoë' } })
  })

  it('returns null for opaque tokens', () => {
    expect(decodeJwt('rt_opaqueRefreshToken')).toBeNull()
  })

  it('returns null when a segment is not a JSON object', () => {
    expect(decodeJwt(`${segment({ alg: 'ES256' })}.${segment([1, 2])}.signature`)).toBeNull()
    expect(decodeJwt('not.base64!.json')).toBeNull()
  })
})
