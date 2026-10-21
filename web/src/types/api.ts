export type AccountRole = 'owner' | 'admin' | 'member'
export type UserStatus = 'active' | 'disabled'
export type ProjectRole = 'admin' | 'developer' | 'viewer'
export type MfaRequirement = 'off' | 'optional' | 'required'
export type SigningAlgorithm = 'ES256' | 'RS256' | 'PS256'
export type SignInChallengeName = 'otp' | 'new_password' | 'mfa_setup'
export type OtpType = 'totp' | 'hotp'

export interface Account {
  uid: string
  name: string
  slug: string
  created_at: string
  updated_at: string
}

export interface AccountSummary {
  uid: string
  name: string
  slug: string
}

export interface User {
  uid: string
  name: string
  email: string
  role: AccountRole
  status: UserStatus
  email_verified: boolean
  mfa_enabled: boolean
  last_sign_in_at: string | null
  created_at: string
  updated_at: string
}

export interface Me extends User {
  password_changed_at: string
  otp_method: OtpType
  account: Account
}

export interface TokenSet {
  access_token: string
  refresh_token: string
  id_token?: string
  token_type: 'Bearer'
  expires_in: number
  recovery_codes?: string[]
}

export interface SignInChallenge {
  challenge: SignInChallengeName
  session: string
  recovery_codes?: string[]
}

export type SignInResult = TokenSet | SignInChallenge

export interface MfaEnrollment {
  otp_type: OtpType
  digits: number
  step_seconds: number | null
  secret: string
  provisioning_uri: string
  qr_code_svg: string
}

export interface Project {
  uid: string
  name: string
  allow_self_sign_up: boolean
  confirm_sign_up_url: string | null
  reset_password_url: string | null
  accept_invitation_url: string | null
  token_issuer: string
  created_at: string
  updated_at: string
}

export type ProjectSettings = Pick<
  Project,
  'name' | 'allow_self_sign_up' | 'confirm_sign_up_url' | 'reset_password_url' | 'accept_invitation_url'
>

export type AppClientType = 'public' | 'confidential'

export interface AppClient {
  uid: string
  name: string
  client_type: AppClientType
  allowed_origins: string[]
  redirect_uris: string[]
  enabled: boolean
  created_at: string
  updated_at: string
}

export interface AppClientWithSecret extends AppClient {
  client_secret: string | null
}

export type IdentityProviderKind = 'google' | 'apple' | 'oidc'

export interface IdentityProvider {
  uid: string
  kind: IdentityProviderKind
  name: string
  enabled: boolean
  client_id: string
  client_secret_set: boolean
  additional_audiences: string[]
  scopes: string
  discovery_url: string | null
  issuer: string | null
  apple_team_id: string | null
  apple_key_id: string | null
  apple_private_key_set: boolean
  callback_url: string
  created_at: string
  updated_at: string
}

export interface EndUserIdentity {
  uid: string
  identity_provider_uid: string
  identity_provider_kind: IdentityProviderKind
  identity_provider_name: string
  subject: string
  email: string | null
  last_sign_in_at: string | null
  created_at: string
}

export type EndUserStatus = 'active' | 'disabled'
export type CustomAttributeValue = string | number | boolean
export type CustomAttributes = Record<string, CustomAttributeValue>

export interface EndUser {
  uid: string
  email: string
  name: string | null
  status: EndUserStatus
  email_verified: boolean
  mfa_enabled: boolean
  invitation_pending: boolean
  custom_attributes: CustomAttributes
  last_sign_in_at: string | null
  created_at: string
  updated_at: string
}

export type AttributeDataType = 'string' | 'number' | 'boolean' | 'date'

export interface AttributeDefinition {
  uid: string
  key: string
  label: string
  data_type: AttributeDataType
  required: boolean
  max_length: number | null
  user_editable: boolean
  include_in_token: boolean
  created_at: string
  updated_at: string
}

export interface ProjectMember {
  user_uid: string
  name: string
  email: string
  role: ProjectRole
  created_at: string
}

export interface Invitation {
  uid: string
  email: string
  role: AccountRole
  invited_by_uid: string | null
  expires_at: string
  created_at: string
}

export interface AuthConfiguration {
  mfa_requirement: MfaRequirement
  require_email_verification: boolean
  password_min_length: number
  password_require_uppercase: boolean
  password_require_lowercase: boolean
  password_require_number: boolean
  password_require_symbol: boolean
  password_max_age_seconds: number | null
  lockout_threshold: number
  lockout_window_seconds: number
  lockout_duration_seconds: number
  access_token_ttl_seconds: number
  refresh_token_ttl_seconds: number
  session_idle_timeout_seconds: number | null
  signing_algorithm: SigningAlgorithm
  signing_key_rotation_seconds: number
  mfa_max_failed_attempts: number
  email_code_max_attempts: number
  email_code_max_failures_per_email: number
  email_code_max_failures_per_code: number
  email_code_failure_window_seconds: number
  otp_method: OtpType
  otp_digits: number
  otp_step_seconds: number
  otp_drift_steps: number
  otp_hotp_look_ahead: number
  updated_at: string
}

export interface AuditEventReference {
  type: string
  uid: string | null
  label: string | null
}

export interface AuditEvent {
  uid: string
  action: string
  actor: AuditEventReference
  target: AuditEventReference | null
  project_uid: string | null
  app_client_uid: string | null
  ip: string | null
  user_agent: string | null
  metadata: Record<string, unknown>
  occurred_at: string
}
