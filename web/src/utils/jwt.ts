export interface DecodedJwt {
  header: Record<string, unknown>
  payload: Record<string, unknown>
}

function decodeSegment(segment: string): Record<string, unknown> | null {
  try {
    const base64 = segment.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(segment.length / 4) * 4, '=')
    const bytes = Uint8Array.from(atob(base64), (character) => character.charCodeAt(0))
    const value: unknown = JSON.parse(new TextDecoder().decode(bytes))
    return typeof value === 'object' && value !== null && !Array.isArray(value) ? (value as Record<string, unknown>) : null
  } catch {
    return null
  }
}

/** Reads a JWT's header and claims without verifying its signature; for display only. */
export function decodeJwt(token: string): DecodedJwt | null {
  const segments = token.split('.')
  if (segments.length !== 3) return null

  const [headerSegment, payloadSegment] = segments as [string, string, string]
  const header = decodeSegment(headerSegment)
  const payload = decodeSegment(payloadSegment)
  return header && payload ? { header, payload } : null
}
