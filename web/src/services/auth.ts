import { apiRequest } from './http'
import type { AccountSummary, MfaEnrollment, SignInChallengeName, SignInResult, TokenSet, User } from '@/types/api'

export interface SignUpInput {
  account_name: string
  slug: string
  name: string
  email: string
  password: string
}

export interface ChallengeAnswer {
  challenge: SignInChallengeName
  session: string
  code?: string
  new_password?: string
}

const authPath = (accountUid: string, action: string) => `/v1/accounts/${accountUid}/auth/${action}`

export const authService = {
  signUp(input: SignUpInput) {
    return apiRequest<{ account: AccountSummary; user: User }>('/v1/sign-up', { method: 'POST', body: input })
  },

  lookupAccount(slug: string) {
    return apiRequest<AccountSummary>(`/v1/account-lookup/${encodeURIComponent(slug)}`)
  },

  signIn(accountUid: string, email: string, password: string) {
    return apiRequest<SignInResult>(authPath(accountUid, 'sign-in'), { method: 'POST', body: { email, password } })
  },

  respondToChallenge(accountUid: string, answer: ChallengeAnswer) {
    return apiRequest<SignInResult>(authPath(accountUid, 'respond-to-challenge'), { method: 'POST', body: answer })
  },

  startMfaSetup(accountUid: string, session: string) {
    return apiRequest<MfaEnrollment>(authPath(accountUid, 'mfa-setup'), { method: 'POST', body: { session } })
  },

  refresh(accountUid: string, refreshToken: string) {
    return apiRequest<TokenSet>(authPath(accountUid, 'refresh'), { method: 'POST', body: { refresh_token: refreshToken } })
  },

  signOut(accountUid: string, refreshToken: string) {
    return apiRequest<null>(authPath(accountUid, 'sign-out'), { method: 'POST', body: { refresh_token: refreshToken } })
  },

  forgotPassword(accountUid: string, email: string) {
    return apiRequest<null>(authPath(accountUid, 'forgot-password'), { method: 'POST', body: { email } })
  },

  resetPassword(accountUid: string, token: string, password: string) {
    return apiRequest<null>(authPath(accountUid, 'reset-password'), { method: 'POST', body: { token, password } })
  },

  confirmEmail(accountUid: string, token: string) {
    return apiRequest<null>(authPath(accountUid, 'confirm-email'), { method: 'POST', body: { token } })
  },

  resendConfirmation(accountUid: string, email: string) {
    return apiRequest<null>(authPath(accountUid, 'resend-confirmation'), { method: 'POST', body: { email } })
  },

  confirmEmailChange(accountUid: string, token: string) {
    return apiRequest<null>(authPath(accountUid, 'confirm-email-change'), { method: 'POST', body: { token } })
  },

  acceptInvitation(accountUid: string, token: string, name: string, password: string) {
    return apiRequest<User>(authPath(accountUid, 'accept-invitation'), { method: 'POST', body: { token, name, password } })
  },
}

export function isChallenge(result: SignInResult): result is Extract<SignInResult, { challenge: string }> {
  return 'challenge' in result
}
