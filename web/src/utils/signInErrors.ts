/**
 * What a failed sign-in means, for the test sign-in page. Explanations follow the API: where it
 * deliberately doesn't say whether an email is registered, neither do these.
 */
const EXPLANATIONS: Record<string, string> = {
  invalid_credentials:
    'The email or password is wrong, or the user is disabled. The API doesn\'t say which, so sign-in can\'t be used to find out who has an account. Check the user on the End users page.',
  app_access_denied: 'The user isn\'t assigned to this application. Give them, or one of their groups, access in the application\'s Access tab.',
  access_denied: 'The user isn\'t assigned to this application. Give them, or one of their groups, access in the application\'s Access tab.',
  email_not_verified: 'The project requires a verified email, and this user hasn\'t confirmed theirs. Turn this off in Authentication › Sign-in methods, or have them confirm it.',
  too_many_attempts: 'Too many failed sign-ins for this email: it\'s locked for the lockout duration set in Authentication › Security policies.',
  invalid_client: 'The application is disabled, or a confidential client\'s secret is wrong.',
  invalid_otp: 'The code is wrong or expired. Repeated wrong codes disable the user.',
  user_disabled: 'The user is disabled. Enable them on their end user page.',
  invalid_challenge: 'The challenge session expired (they last 5 minutes) or was already used. Start over.',
  session_expired: 'The session has ended (session lifetime or idle timeout). Sign in again.',
  mfa_required: 'The project now requires MFA and this session didn\'t use it. Sign in again.',
  invalid_token: 'The refresh token was already used, revoked or is unknown. Reusing a refresh token signs out the whole session.',
  login_required: 'There\'s no hosted login session, and the app asked not to show the login page.',
  invalid_state: 'This response doesn\'t match a sign-in started here. Start again.',
}

export function explainSignInError(code: string): string | undefined {
  return EXPLANATIONS[code]
}
