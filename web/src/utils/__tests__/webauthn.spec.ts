import { describe, expect, it } from 'vitest'

import { creationOptions, passkeyErrorMessage, registrationJSON } from '../webauthn'

const bytes = (...values: number[]) => new Uint8Array(values)

describe('webauthn', () => {
  it("decodes the API's base64url options into the bytes the browser takes", () => {
    const options = creationOptions({
      challenge: 'AQID',
      rp: { id: 'login.acme.com', name: 'Acme' },
      user: { id: '_-8', name: 'casey@acme.com', displayName: 'Casey' },
      pubKeyCredParams: [{ type: 'public-key', alg: -7 }],
      authenticatorSelection: { residentKey: 'required', userVerification: 'required' },
      excludeCredentials: [{ type: 'public-key', id: 'BAU' }],
    })

    expect(new Uint8Array(options.challenge as ArrayBuffer)).toEqual(bytes(1, 2, 3))
    expect(new Uint8Array(options.user.id as ArrayBuffer)).toEqual(bytes(255, 239))
    expect(new Uint8Array(options.excludeCredentials![0]!.id as ArrayBuffer)).toEqual(bytes(4, 5))
    expect(options.rp).toEqual({ id: 'login.acme.com', name: 'Acme' })
  })

  it('encodes the created passkey as base64url JSON for the API', () => {
    const credential = {
      id: 'cred-1',
      rawId: bytes(251, 255).buffer,
      type: 'public-key',
      authenticatorAttachment: 'platform',
      getClientExtensionResults: () => ({}),
      response: { clientDataJSON: bytes(1, 2).buffer, attestationObject: bytes(3).buffer, getTransports: () => ['internal'] },
    } as unknown as PublicKeyCredential

    expect(registrationJSON(credential)).toEqual({
      id: 'cred-1',
      rawId: '-_8',
      type: 'public-key',
      authenticatorAttachment: 'platform',
      clientExtensionResults: {},
      response: { clientDataJSON: 'AQI', attestationObject: 'Aw', transports: ['internal'] },
    })
  })

  it('stays quiet when the user cancels, and explains other failures', () => {
    expect(passkeyErrorMessage(new DOMException('cancelled', 'NotAllowedError'))).toBeNull()
    expect(passkeyErrorMessage(new DOMException('exists', 'InvalidStateError'))).toBe('This device already has a passkey for your account.')
    expect(passkeyErrorMessage(new Error('boom'))).toBe("We couldn't create the passkey. Try again.")
  })
})
