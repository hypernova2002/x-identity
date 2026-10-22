import { apiRequest } from './http'
import type { HostedLoginDetails, HostedSignInResult, MfaEnrollment, SignInChallengeName } from '@/types/api'

/** One sign-in on a project's hosted login page, identified by its interaction. */
export interface InteractionRef {
  accountUid: string
  projectUid: string
  interaction: string
}

export interface HostedChallengeAnswer {
  challenge: SignInChallengeName
  session: string
  code?: string
  new_password?: string
}

export interface HostedSignUpInput {
  email: string
  password: string
  name?: string
}

const interactionPath = (ref: InteractionRef, action = '') =>
  `/v1/accounts/${ref.accountUid}/projects/${ref.projectUid}/oauth2/interactions/${encodeURIComponent(ref.interaction)}${action ? `/${action}` : ''}`

export const hostedLoginService = {
  details: (ref: InteractionRef) => apiRequest<HostedLoginDetails>(interactionPath(ref)),

  signIn: (ref: InteractionRef, email: string, password: string) =>
    apiRequest<HostedSignInResult>(interactionPath(ref, 'sign-in'), { method: 'POST', body: { email, password } }),

  /** Which company identity provider, if any, an email's domain belongs to. */
  discover: (ref: InteractionRef, email: string) =>
    apiRequest<{ identity_provider_uid: string | null }>(interactionPath(ref, 'discover'), { method: 'POST', body: { email } }),

  respondToChallenge: (ref: InteractionRef, answer: HostedChallengeAnswer) =>
    apiRequest<HostedSignInResult>(interactionPath(ref, 'respond-to-challenge'), { method: 'POST', body: answer }),

  startMfaSetup: (ref: InteractionRef, session: string) =>
    apiRequest<MfaEnrollment>(interactionPath(ref, 'mfa-setup'), { method: 'POST', body: { session } }),

  signUp: (ref: InteractionRef, input: HostedSignUpInput) => apiRequest<null>(interactionPath(ref, 'sign-up'), { method: 'POST', body: input }),

  confirmSignUp: (ref: InteractionRef, email: string, code: string) =>
    apiRequest<null>(interactionPath(ref, 'confirm-sign-up'), { method: 'POST', body: { email, code } }),

  resendConfirmation: (ref: InteractionRef, email: string) =>
    apiRequest<null>(interactionPath(ref, 'resend-confirmation'), { method: 'POST', body: { email } }),

  forgotPassword: (ref: InteractionRef, email: string) =>
    apiRequest<null>(interactionPath(ref, 'forgot-password'), { method: 'POST', body: { email } }),

  confirmForgotPassword: (ref: InteractionRef, email: string, code: string, password: string) =>
    apiRequest<null>(interactionPath(ref, 'confirm-forgot-password'), { method: 'POST', body: { email, code, password } }),

  /** A browser navigation, not an API call: the backend redirects to the provider. */
  providerUrl: (ref: InteractionRef, providerUid: string) =>
    `${import.meta.env.VITE_API_BASE_URL}${interactionPath(ref, `providers/${encodeURIComponent(providerUid)}`)}`,
}
