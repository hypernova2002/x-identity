import type { MfaMethod, SignInChallenge, SignInChallengeName } from '@/types/api'

const CHALLENGES: readonly SignInChallengeName[] = ['otp', 'passkey', 'new_password', 'mfa_setup', 'passkey_setup']
const MFA_METHODS: readonly MfaMethod[] = ['otp', 'passkey']

/**
 * The challenge hosted login resumes at when the user comes back from an identity provider: the
 * `challenge`, `session` and comma-separated `mfa_methods` query parameters. Unknown names are ignored.
 */
export function resumedChallenge(challenge: string, session: string, mfaMethods: string): SignInChallenge | undefined {
  if (!session || !CHALLENGES.includes(challenge as SignInChallengeName)) return undefined

  const methods = mfaMethods.split(',').filter((method): method is MfaMethod => MFA_METHODS.includes(method as MfaMethod))
  return { challenge: challenge as SignInChallengeName, session, ...(methods.length > 0 ? { mfa_methods: methods } : {}) }
}
