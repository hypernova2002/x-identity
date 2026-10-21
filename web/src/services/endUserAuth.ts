import { apiRequest } from './http'
import type { ChallengeAnswer } from './auth'
import type { MfaEnrollment, SignInResult, TokenSet } from '@/types/api'

/** The app client an end user signs in through. Only confidential clients have a secret. */
export interface ClientCredentials {
  client_id: string
  client_secret?: string
}

export interface ProjectRef {
  accountUid: string
  projectUid: string
}

const authPath = ({ accountUid, projectUid }: ProjectRef, action: string) =>
  `/v1/accounts/${accountUid}/projects/${projectUid}/auth/${action}`

/** A project's public end-user sign-in API, called the way an app would: without the console session. */
export const endUserAuthService = {
  signIn: (project: ProjectRef, client: ClientCredentials, email: string, password: string) =>
    apiRequest<SignInResult>(authPath(project, 'sign-in'), { method: 'POST', body: { ...client, email, password } }),

  respondToChallenge: (project: ProjectRef, client: ClientCredentials, answer: ChallengeAnswer) =>
    apiRequest<SignInResult>(authPath(project, 'respond-to-challenge'), { method: 'POST', body: { ...client, ...answer } }),

  startMfaSetup: (project: ProjectRef, client: ClientCredentials, session: string) =>
    apiRequest<MfaEnrollment>(authPath(project, 'mfa-setup'), { method: 'POST', body: { ...client, session } }),

  refresh: (project: ProjectRef, client: ClientCredentials, refreshToken: string) =>
    apiRequest<TokenSet>(authPath(project, 'refresh'), { method: 'POST', body: { ...client, refresh_token: refreshToken } }),

  signOut: (project: ProjectRef, client: ClientCredentials, refreshToken: string) =>
    apiRequest<null>(authPath(project, 'sign-out'), { method: 'POST', body: { ...client, refresh_token: refreshToken } }),
}
