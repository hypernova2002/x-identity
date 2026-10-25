/**
 * The browser side of passkeys. The API sends WebAuthn options as JSON with binary values as
 * base64url strings; the browser's WebAuthn API takes and returns ArrayBuffers.
 */

export interface PasskeyCreationOptionsJSON {
  challenge: string
  rp: { id?: string; name: string }
  user: { id: string; name: string; displayName: string }
  pubKeyCredParams: { type: 'public-key'; alg: number }[]
  timeout?: number
  attestation?: AttestationConveyancePreference
  authenticatorSelection?: AuthenticatorSelectionCriteria
  excludeCredentials?: { type: 'public-key'; id: string; transports?: AuthenticatorTransport[] }[]
}

/** What the API expects back: the PublicKeyCredential as JSON, like its toJSON(). */
export interface PasskeyRegistrationJSON {
  id: string
  rawId: string
  type: string
  authenticatorAttachment: string | null
  clientExtensionResults: AuthenticationExtensionsClientOutputs
  response: { clientDataJSON: string; attestationObject: string; transports: string[] }
}

export function passkeysSupported(): boolean {
  return typeof window !== 'undefined' && 'PublicKeyCredential' in window && typeof navigator.credentials?.create === 'function'
}

function toBytes(value: string): Uint8Array<ArrayBuffer> {
  const base64 = value.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(value.length / 4) * 4, '=')
  return Uint8Array.from(atob(base64), (character) => character.charCodeAt(0))
}

function toBase64Url(buffer: ArrayBuffer): string {
  return btoa(String.fromCharCode(...new Uint8Array(buffer)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')
}

export function creationOptions(json: PasskeyCreationOptionsJSON): PublicKeyCredentialCreationOptions {
  return {
    challenge: toBytes(json.challenge),
    rp: json.rp,
    user: { ...json.user, id: toBytes(json.user.id) },
    pubKeyCredParams: json.pubKeyCredParams,
    timeout: json.timeout,
    attestation: json.attestation,
    authenticatorSelection: json.authenticatorSelection,
    excludeCredentials: (json.excludeCredentials ?? []).map((credential) => ({ ...credential, id: toBytes(credential.id) })),
  }
}

export function registrationJSON(credential: PublicKeyCredential): PasskeyRegistrationJSON {
  const response = credential.response as AuthenticatorAttestationResponse
  return {
    id: credential.id,
    rawId: toBase64Url(credential.rawId),
    type: credential.type,
    authenticatorAttachment: credential.authenticatorAttachment,
    clientExtensionResults: credential.getClientExtensionResults(),
    response: {
      clientDataJSON: toBase64Url(response.clientDataJSON),
      attestationObject: toBase64Url(response.attestationObject),
      transports: response.getTransports?.() ?? [],
    },
  }
}

/** Why a passkey ceremony ended without one, in words for the user; null when they cancelled. */
export function passkeyErrorMessage(caught: unknown): string | null {
  if (caught instanceof DOMException) {
    if (caught.name === 'NotAllowedError' || caught.name === 'AbortError') return null
    if (caught.name === 'InvalidStateError') return 'This device already has a passkey for your account.'
    if (caught.name === 'SecurityError') return "Passkeys can't be used on this site's address."
  }
  return "We couldn't create the passkey. Try again."
}

/** Asks the browser to create a passkey from the API's options. */
export async function createPasskey(options: PasskeyCreationOptionsJSON): Promise<PasskeyRegistrationJSON> {
  const credential = await navigator.credentials.create({ publicKey: creationOptions(options) })
  if (!(credential instanceof PublicKeyCredential)) throw new DOMException('No passkey was created.', 'NotAllowedError')
  return registrationJSON(credential)
}
