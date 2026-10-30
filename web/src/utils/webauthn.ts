import { i18n } from '@/i18n'

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

export interface PasskeyRequestOptionsJSON {
  challenge: string
  timeout?: number
  rpId?: string
  userVerification?: UserVerificationRequirement
  allowCredentials?: { type: 'public-key'; id: string; transports?: AuthenticatorTransport[] }[]
}

/** A passkey's signed answer to a sign-in, as JSON. */
export interface PasskeyAssertionJSON {
  id: string
  rawId: string
  type: string
  authenticatorAttachment: string | null
  clientExtensionResults: AuthenticationExtensionsClientOutputs
  response: { clientDataJSON: string; authenticatorData: string; signature: string; userHandle: string | null }
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

export function requestOptions(json: PasskeyRequestOptionsJSON): PublicKeyCredentialRequestOptions {
  return {
    challenge: toBytes(json.challenge),
    timeout: json.timeout,
    rpId: json.rpId,
    userVerification: json.userVerification,
    allowCredentials: (json.allowCredentials ?? []).map((credential) => ({ ...credential, id: toBytes(credential.id) })),
  }
}

export function assertionJSON(credential: PublicKeyCredential): PasskeyAssertionJSON {
  const response = credential.response as AuthenticatorAssertionResponse
  return {
    id: credential.id,
    rawId: toBase64Url(credential.rawId),
    type: credential.type,
    authenticatorAttachment: credential.authenticatorAttachment,
    clientExtensionResults: credential.getClientExtensionResults(),
    response: {
      clientDataJSON: toBase64Url(response.clientDataJSON),
      authenticatorData: toBase64Url(response.authenticatorData),
      signature: toBase64Url(response.signature),
      userHandle: response.userHandle ? toBase64Url(response.userHandle) : null,
    },
  }
}

/** Why a passkey ceremony ended without one, in words for the user; null when they cancelled. */
export function passkeyErrorMessage(caught: unknown, action: 'create' | 'sign-in' = 'create'): string | null {
  if (caught instanceof DOMException) {
    if (caught.name === 'NotAllowedError' || caught.name === 'AbortError') return null
    if (caught.name === 'InvalidStateError' && action === 'create') return i18n.global.t('signIn.passkeyErrors.alreadyExists')
    if (caught.name === 'SecurityError') return i18n.global.t('signIn.passkeyErrors.wrongSite')
  }
  return action === 'create' ? i18n.global.t('signIn.passkeyErrors.createFailed') : i18n.global.t('signIn.passkeyErrors.signInFailed')
}

/** Whether the browser can offer passkeys in the email field's autofill. */
export async function passkeyAutofillAvailable(): Promise<boolean> {
  try {
    return passkeysSupported() && (await PublicKeyCredential.isConditionalMediationAvailable?.()) === true
  } catch {
    return false
  }
}

/**
 * Asks the browser for a passkey's answer to the API's options: from a prompt, or, with
 * `autofill`, by waiting until the user picks a passkey in the email field's autofill.
 */
export async function getPasskey(options: PasskeyRequestOptionsJSON, { autofill = false, signal }: { autofill?: boolean; signal?: AbortSignal } = {}): Promise<PasskeyAssertionJSON> {
  const credential = await navigator.credentials.get({ publicKey: requestOptions(options), mediation: autofill ? 'conditional' : 'optional', signal })
  if (!(credential instanceof PublicKeyCredential)) throw new DOMException('No passkey was chosen.', 'NotAllowedError')
  return assertionJSON(credential)
}

/** Asks the browser to create a passkey from the API's options. */
export async function createPasskey(options: PasskeyCreationOptionsJSON): Promise<PasskeyRegistrationJSON> {
  const credential = await navigator.credentials.create({ publicKey: creationOptions(options) })
  if (!(credential instanceof PublicKeyCredential)) throw new DOMException('No passkey was created.', 'NotAllowedError')
  return registrationJSON(credential)
}
