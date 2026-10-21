import { ref } from 'vue'

import { useAsyncAction } from './useAsyncAction'
import { hostedLoginService, type InteractionRef } from '@/services/hostedLogin'
import type { HostedLoginDetails, HostedSignInResult, MfaEnrollment, SignInChallenge } from '@/types/api'

export type HostedLoginStep = 'sign-in' | 'challenge' | 'recovery-codes' | 'sign-up' | 'confirm-sign-up' | 'forgot-password' | 'reset-password'

export interface HostedLoginOptions {
  /** Sends the browser on; replaced in tests. */
  navigate?: (url: string) => void
}

/**
 * The hosted login page's steps for one interaction: sign in (and any challenge), sign up and
 * confirm the email, or reset a password. When sign-in finishes, the browser is sent back to the
 * backend, which completes the app's authorization; the page itself never holds tokens.
 */
export function useHostedLogin(options: HostedLoginOptions = {}) {
  const navigate = options.navigate ?? ((url: string) => window.location.assign(url))

  const target = ref<InteractionRef | null>(null)
  const details = ref<HostedLoginDetails | null>(null)
  const step = ref<HostedLoginStep>('sign-in')
  const email = ref('')
  const challenge = ref<SignInChallenge | null>(null)
  const enrollment = ref<MfaEnrollment | null>(null)
  const recoveryCodes = ref<string[]>([])
  const pendingRedirect = ref<string | null>(null)
  const notice = ref<string | null>(null)
  let signUpPassword = ''

  function go(next: HostedLoginStep) {
    notice.value = null
    step.value = next
  }

  async function showChallenge(value: SignInChallenge) {
    if (!target.value) return
    challenge.value = value
    enrollment.value = value.challenge === 'mfa_setup' ? await hostedLoginService.startMfaSetup(target.value, value.session) : null
    step.value = 'challenge'
  }

  async function handleResult(result: HostedSignInResult) {
    if (result.recovery_codes) recoveryCodes.value = result.recovery_codes
    if ('challenge' in result) return showChallenge(result)

    if (recoveryCodes.value.length > 0) {
      pendingRedirect.value = result.redirect_to
      step.value = 'recovery-codes'
    } else {
      navigate(result.redirect_to)
    }
  }

  /** Loads the interaction; resumes a challenge when returning from an identity provider. */
  const load = useAsyncAction(async (interaction: InteractionRef, resume?: SignInChallenge) => {
    target.value = interaction
    details.value = await hostedLoginService.details(interaction)
    email.value = details.value.login_hint ?? ''
    if (resume) await showChallenge(resume)
  })

  const signIn = useAsyncAction(async (password: string) => {
    if (!target.value) return
    await handleResult(await hostedLoginService.signIn(target.value, email.value, password))
  })

  const answer = useAsyncAction(async (response: { code?: string; newPassword?: string }) => {
    if (!target.value || !challenge.value) return
    const isNewPassword = challenge.value.challenge === 'new_password'
    await handleResult(
      await hostedLoginService.respondToChallenge(target.value, {
        challenge: challenge.value.challenge,
        session: challenge.value.session,
        code: isNewPassword ? undefined : response.code,
        new_password: isNewPassword ? response.newPassword : undefined,
      }),
    )
  })

  function continueAfterRecoveryCodes() {
    if (pendingRedirect.value) navigate(pendingRedirect.value)
  }

  const signUp = useAsyncAction(async (input: { name: string; password: string }) => {
    if (!target.value) return
    await hostedLoginService.signUp(target.value, { email: email.value, password: input.password, name: input.name.trim() || undefined })
    signUpPassword = input.password
    go('confirm-sign-up')
  })

  /** Confirms the email, then signs in with the password just chosen. */
  const confirmSignUp = useAsyncAction(async (code: string) => {
    if (!target.value) return
    await hostedLoginService.confirmSignUp(target.value, email.value, code)
    await handleResult(await hostedLoginService.signIn(target.value, email.value, signUpPassword))
    signUpPassword = ''
  })

  const resendConfirmation = useAsyncAction(async () => {
    if (!target.value) return
    await hostedLoginService.resendConfirmation(target.value, email.value)
    notice.value = `If ${email.value} is waiting for confirmation, a new code is on its way.`
  })

  const forgotPassword = useAsyncAction(async () => {
    if (!target.value) return
    await hostedLoginService.forgotPassword(target.value, email.value)
    go('reset-password')
  })

  const resetPassword = useAsyncAction(async (input: { code: string; password: string }) => {
    if (!target.value) return
    await hostedLoginService.confirmForgotPassword(target.value, email.value, input.code, input.password)
    go('sign-in')
    notice.value = 'Your password was changed. Sign in with the new one.'
  })

  function providerUrl(providerUid: string) {
    return target.value ? hostedLoginService.providerUrl(target.value, providerUid) : ''
  }

  return {
    details,
    step,
    email,
    challenge,
    enrollment,
    recoveryCodes,
    notice,
    go,
    load,
    signIn,
    answer,
    continueAfterRecoveryCodes,
    signUp,
    confirmSignUp,
    resendConfirmation,
    forgotPassword,
    resetPassword,
    providerUrl,
    navigate,
  }
}
