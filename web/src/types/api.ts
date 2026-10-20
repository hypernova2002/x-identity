export type AccountRole = 'owner' | 'admin' | 'member'
export type UserStatus = 'active' | 'disabled'
export type ProjectRole = 'admin' | 'developer' | 'viewer'
export type MfaRequirement = 'off' | 'optional' | 'required'
export type SigningAlgorithm = 'ES256' | 'RS256' | 'PS256'
export type SignInChallengeName = 'totp' | 'new_password' | 'mfa_setup'

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
  account: Account
}

export interface TokenSet {
  access_token: string
  refresh_token: string
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
  secret: string
  provisioning_uri: string
  qr_code_svg: string
}

export interface Project {
  uid: string
  name: string
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
  password_max_age_days: number | null
  lockout_threshold: number
  lockout_window_minutes: number
  lockout_duration_minutes: number
  access_token_ttl_minutes: number
  refresh_token_ttl_days: number
  session_idle_timeout_minutes: number | null
  signing_algorithm: SigningAlgorithm
  signing_key_rotation_days: number
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
  ip: string | null
  user_agent: string | null
  metadata: Record<string, unknown>
  occurred_at: string
}
