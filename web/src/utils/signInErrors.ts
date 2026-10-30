import { i18n } from '@/i18n'

/**
 * What a failed sign-in means, for the test sign-in page. Explanations follow the API: where it
 * deliberately doesn't say whether an email is registered, neither do these.
 */
export function explainSignInError(code: string): string | undefined {
  const key = `project.signInErrors.${code}`
  return i18n.global.te(key) ? i18n.global.t(key) : undefined
}
