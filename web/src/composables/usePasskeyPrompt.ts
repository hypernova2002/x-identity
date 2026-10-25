import { onScopeDispose, ref } from 'vue'

import { ApiError } from '@/services/http'
import type { PasskeyAuthenticationOptions } from '@/types/api'
import { getPasskey, passkeyErrorMessage, type PasskeyAssertionJSON } from '@/utils/webauthn'

export interface PasskeyAnswer {
  authenticationId: string
  credential: PasskeyAssertionJSON
}

/**
 * Passkey prompts on a sign-in page: one waiting in the email field's autofill, and ones the user
 * starts with a button. Only one runs at a time; a new one cancels the last.
 */
export function usePasskeyPrompt() {
  const error = ref<string | null>(null)
  let controller: AbortController | null = null

  function cancel() {
    controller?.abort()
    controller = null
  }

  /**
   * @returns the passkey's answer, or null when the user cancelled or another prompt replaced this one
   * @throws ApiError when the options can't be loaded
   */
  async function prompt(options: () => Promise<PasskeyAuthenticationOptions>, { autofill = false } = {}): Promise<PasskeyAnswer | null> {
    cancel()
    const current = new AbortController()
    controller = current
    error.value = null
    try {
      const loaded = await options()
      const credential = await getPasskey(loaded.public_key, { autofill, signal: current.signal })
      return { authenticationId: loaded.authentication_id, credential }
    } catch (caught) {
      if (caught instanceof ApiError) throw caught
      if (!current.signal.aborted && !autofill) error.value = passkeyErrorMessage(caught, 'sign-in')
      return null
    } finally {
      if (controller === current) controller = null
    }
  }

  onScopeDispose(cancel)

  return { prompt, cancel, error }
}
