function base64Url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')
}

/** A random base64url string, e.g. for PKCE code verifiers, state and nonces. */
export function randomUrlSafe(byteLength = 32): string {
  return base64Url(crypto.getRandomValues(new Uint8Array(byteLength)))
}

/** The S256 PKCE code challenge for a code verifier. */
export async function codeChallengeFor(verifier: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier))
  return base64Url(new Uint8Array(digest))
}
