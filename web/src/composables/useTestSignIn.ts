import { ref } from 'vue'

import { useAsyncAction } from './useAsyncAction'
import { isChallenge } from '@/services/auth'
import { endUserAuthService, type ClientCredentials, type ProjectRef } from '@/services/endUserAuth'
import type { MfaEnrollment, SignInChallenge, SignInResult, TokenSet } from '@/types/api'

/**
 * Signs an end user in to a project the way an app would, through every challenge the API asks for,
 * and keeps the resulting tokens so they can be refreshed and revoked. Nothing touches the console session.
 */
export function useTestSignIn() {
  const target = ref<{ project: ProjectRef; client: ClientCredentials } | null>(null)
  const challenge = ref<SignInChallenge | null>(null)
  const enrollment = ref<MfaEnrollment | null>(null)
  const tokens = ref<TokenSet | null>(null)
  const recoveryCodes = ref<string[]>([])
  const refreshedAt = ref<Date | null>(null)
  const signedOut = ref(false)

  async function handleResult(result: SignInResult) {
    if (result.recovery_codes) recoveryCodes.value = result.recovery_codes

    if (isChallenge(result)) {
      challenge.value = result
      enrollment.value = null
      if (result.challenge === 'mfa_setup' && target.value) {
        enrollment.value = await endUserAuthService.startMfaSetup(target.value.project, target.value.client, result.session)
      }
      return
    }

    challenge.value = null
    enrollment.value = null
    tokens.value = result
  }

  function reset() {
    target.value = null
    challenge.value = null
    enrollment.value = null
    tokens.value = null
    recoveryCodes.value = []
    refreshedAt.value = null
    signedOut.value = false
  }

  const signIn = useAsyncAction(async (project: ProjectRef, client: ClientCredentials, email: string, password: string) => {
    reset()
    target.value = { project, client }
    await handleResult(await endUserAuthService.signIn(project, client, email, password))
  })

  const answer = useAsyncAction(async (response: { code?: string; newPassword?: string }) => {
    if (!target.value || !challenge.value) return

    const result = await endUserAuthService.respondToChallenge(target.value.project, target.value.client, {
      challenge: challenge.value.challenge,
      session: challenge.value.session,
      code: challenge.value.challenge === 'new_password' ? undefined : response.code,
      new_password: challenge.value.challenge === 'new_password' ? response.newPassword : undefined,
    })
    await handleResult(result)
  })

  const refresh = useAsyncAction(async () => {
    if (!target.value || !tokens.value) return

    tokens.value = await endUserAuthService.refresh(target.value.project, target.value.client, tokens.value.refresh_token)
    refreshedAt.value = new Date()
  })

  const signOut = useAsyncAction(async () => {
    if (!target.value || !tokens.value) return

    await endUserAuthService.signOut(target.value.project, target.value.client, tokens.value.refresh_token)
    signedOut.value = true
  })

  return { challenge, enrollment, tokens, recoveryCodes, refreshedAt, signedOut, signIn, answer, refresh, signOut, reset }
}
