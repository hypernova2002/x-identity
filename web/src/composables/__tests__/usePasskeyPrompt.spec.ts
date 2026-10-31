import { beforeEach, describe, expect, it, vi } from 'vitest'
import { effectScope } from 'vue'

import { usePasskeyPrompt } from '../usePasskeyPrompt'
import { ApiError } from '@/services/http'
import type { PasskeyAuthenticationOptions } from '@/types/api'
import { getPasskey, type PasskeyAssertionJSON } from '@/utils/webauthn'

vi.mock('@/utils/webauthn', async (importOriginal) => ({
  ...(await importOriginal<typeof import('@/utils/webauthn')>()),
  getPasskey: vi.fn<typeof getPasskey>(),
}))

const options: PasskeyAuthenticationOptions = { authentication_id: 'auth_1', public_key: { challenge: 'c' } as PasskeyAuthenticationOptions['public_key'] }
const credential = { id: 'cred_1' } as PasskeyAssertionJSON
const loadOptions = () => Promise.resolve(options)

/** A getPasskey that waits until its prompt is aborted, like a browser prompt left open. */
function waitUntilAborted() {
  vi.mocked(getPasskey).mockImplementationOnce(
    (_options, { signal } = {}) => new Promise((_, reject) => signal?.addEventListener('abort', () => reject(new DOMException('aborted', 'AbortError')))),
  )
}

describe('usePasskeyPrompt', () => {
  beforeEach(() => {
    vi.mocked(getPasskey).mockReset()
  })

  it("answers with the passkey the user picked", async () => {
    vi.mocked(getPasskey).mockResolvedValue(credential)

    await expect(usePasskeyPrompt().prompt(loadOptions)).resolves.toEqual({ authenticationId: 'auth_1', credential })
  })

  it('cancels a waiting prompt when another starts, without reporting an error', async () => {
    const passkeys = usePasskeyPrompt()
    waitUntilAborted()
    const autofill = passkeys.prompt(loadOptions, { autofill: true })
    await Promise.resolve()

    vi.mocked(getPasskey).mockResolvedValueOnce(credential)
    const button = await passkeys.prompt(loadOptions)

    await expect(autofill).resolves.toBeNull()
    expect(button).toEqual({ authenticationId: 'auth_1', credential })
    expect(passkeys.error.value).toBeNull()
  })

  it('stays quiet when the user closes the prompt', async () => {
    vi.mocked(getPasskey).mockRejectedValue(new DOMException('closed', 'NotAllowedError'))
    const passkeys = usePasskeyPrompt()

    await expect(passkeys.prompt(loadOptions)).resolves.toBeNull()
    expect(passkeys.error.value).toBeNull()
  })

  it('explains a failed prompt the user started, but not a failed autofill', async () => {
    vi.mocked(getPasskey).mockRejectedValue(new Error('broken authenticator'))
    const passkeys = usePasskeyPrompt()

    await passkeys.prompt(loadOptions, { autofill: true })
    expect(passkeys.error.value).toBeNull()

    await passkeys.prompt(loadOptions)
    expect(passkeys.error.value).toBeTruthy()
  })

  it("passes on the API's error when the options can't be loaded", async () => {
    await expect(usePasskeyPrompt().prompt(() => Promise.reject(new ApiError('rate_limited', 429)))).rejects.toMatchObject({ code: 'rate_limited' })
    expect(getPasskey).not.toHaveBeenCalled()
  })

  it('cancels a waiting prompt when the page using it goes away', async () => {
    const scope = effectScope()
    const passkeys = scope.run(() => usePasskeyPrompt())!
    waitUntilAborted()
    const waiting = passkeys.prompt(loadOptions, { autofill: true })
    await Promise.resolve()

    scope.stop()

    await expect(waiting).resolves.toBeNull()
  })
})
