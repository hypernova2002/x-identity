import { i18n } from '@/i18n'
import type { AuthConfiguration } from '@/types/api'

export type AuthSettingsSection = 'sign-in' | 'mfa' | 'policies' | 'tokens' | 'signing'
export type AuthSettingsField = Exclude<keyof AuthConfiguration, 'updated_at'>

/** The settings each section shows and saves. Saving a section sends only its own fields. */
export const AUTH_SETTINGS_FIELDS: Record<AuthSettingsSection, readonly AuthSettingsField[]> = {
  'sign-in': [
    'require_email_verification',
    'passkeys',
    'passwordless_after_passkey',
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

// Labels are read when this module loads: the locale is chosen once, at startup.
export const authSettingsSections: { section: AuthSettingsSection; label: string; description: string }[] = (
  ['sign-in', 'mfa', 'policies', 'tokens', 'signing'] as const
).map((section) => ({
  section,
  label: i18n.global.t(`settings.sections.${section}.label`),
  description: i18n.global.t(`settings.sections.${section}.description`),
}))

/** Only the given fields of a configuration, for saving one section without touching the rest. */
export function pickFields(values: Partial<AuthConfiguration>, fields: readonly AuthSettingsField[]): Partial<AuthConfiguration> {
  return Object.fromEntries(fields.filter((field) => field in values).map((field) => [field, values[field]])) as Partial<AuthConfiguration>
}
