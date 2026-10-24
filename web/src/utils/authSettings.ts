import type { AuthConfiguration } from '@/types/api'

export type AuthSettingsSection = 'sign-in' | 'mfa' | 'policies' | 'tokens' | 'signing'
export type AuthSettingsField = Exclude<keyof AuthConfiguration, 'updated_at'>

/** The settings each section shows and saves. Saving a section sends only its own fields. */
export const AUTH_SETTINGS_FIELDS: Record<AuthSettingsSection, readonly AuthSettingsField[]> = {
  'sign-in': [
    'require_email_verification',
    'email_code_max_attempts',
    'email_code_max_failures_per_email',
    'email_code_max_failures_per_code',
    'email_code_failure_window_seconds',
  ],
  mfa: ['mfa_requirement', 'mfa_max_failed_attempts', 'otp_method', 'otp_digits', 'otp_step_seconds', 'otp_drift_steps', 'otp_hotp_look_ahead'],
  policies: [
    'password_min_length',
    'password_max_age_seconds',
    'password_require_uppercase',
    'password_require_lowercase',
    'password_require_number',
    'password_require_symbol',
    'lockout_threshold',
    'lockout_window_seconds',
    'lockout_duration_seconds',
    'notify_new_devices',
  ],
  tokens: [
    'access_token_ttl_seconds',
    'refresh_token_ttl_seconds',
    'session_idle_timeout_seconds',
    'sso_session_ttl_seconds',
    'client_secret_rotation_overlap_seconds',
    'token_requests_per_minute',
  ],
  signing: ['signing_algorithm', 'signing_key_rotation_seconds'],
}

export const EMAIL_CODE_FIELDS: readonly AuthSettingsField[] = [
  'email_code_max_attempts',
  'email_code_max_failures_per_email',
  'email_code_max_failures_per_code',
  'email_code_failure_window_seconds',
]

export const authSettingsSections: { section: AuthSettingsSection; label: string; description: string }[] = [
  { section: 'sign-in', label: 'Sign-in methods', description: 'Password sign-in, email verification and the codes sent by email.' },
  { section: 'mfa', label: 'Multi-factor authentication', description: 'The project-wide MFA policy. Each user\'s own MFA setup is shown on their end user page.' },
  { section: 'policies', label: 'Security policies', description: 'Password rules, password expiry and lockouts after failed sign-ins.' },
  { section: 'tokens', label: 'Tokens and sessions', description: 'How long tokens, sessions and the hosted login session last, and limits for app clients.' },
  { section: 'signing', label: 'Signing keys', description: 'How tokens and SAML messages are signed, and key rotation.' },
]

/** Only the given fields of a configuration, for saving one section without touching the rest. */
export function pickFields(values: Partial<AuthConfiguration>, fields: readonly AuthSettingsField[]): Partial<AuthConfiguration> {
  return Object.fromEntries(fields.filter((field) => field in values).map((field) => [field, values[field]])) as Partial<AuthConfiguration>
}
