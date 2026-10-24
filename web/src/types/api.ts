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
  post_logout_redirect_uris: string[]
  launch_url: string | null
  enabled: boolean
  created_at: string
  updated_at: string
}

export interface AppClientWithSecret extends AppClient {
  client_secret: string | null
}

export interface GroupSummary {
  uid: string
  name: string
}

export interface Group {
  uid: string
  name: string
  description: string | null
  default_for_new_users: boolean
  member_count: number
  created_at: string
  updated_at: string
}

export type AppKind = 'app_client' | 'saml_app'

/** An app client or SAML app, as listed together on the Applications page. */
export interface Application {
  app_type: AppKind
  uid: string
  name: string
  enabled: boolean
  /** App clients only. */
  client_type: AppClientType | null
  /** SAML apps only. */
  entity_id: string | null
  created_at: string
}
export type PrincipalType = 'end_user' | 'group'

export interface AppAssignment {
  uid: string
  principal_type: PrincipalType
  principal_uid: string
  principal_label: string
  created_at: string
}

export type SamlNameIdFormat = 'email' | 'persistent' | 'unspecified'

export interface SamlAttributeMapping {
  name: string
  source: string
}

export interface SamlApp {
  uid: string
  name: string
  enabled: boolean
  entity_id: string
  acs_urls: string[]
  slo_url: string | null
  sp_certificate: string | null
  name_id_format: SamlNameIdFormat
  attribute_mappings: SamlAttributeMapping[]
  sign_assertion: boolean
  sign_response: boolean
  require_signed_requests: boolean
  default_relay_state: string | null
  launch_url: string
  created_at: string
  updated_at: string
}

/** What a SAML app's metadata says, for filling in the form. */
export type SamlAppMetadata = Partial<Pick<SamlApp, 'entity_id' | 'acs_urls' | 'slo_url' | 'sp_certificate' | 'name_id_format'>>

export type SamlCertificateStatus = 'next' | 'active' | 'retired'

export interface SamlCertificate {
  uid: string
  status: SamlCertificateStatus
  certificate: string
  fingerprint_sha256: string
  activated_at: string | null
  expires_at: string
  created_at: string
}

export interface SamlIdentityProviderInfo {
  entity_id: string
  metadata_url: string
  sso_url: string
  slo_url: string
  certificates: SamlCertificate[]
}

export interface PortalConfig {
  issuer: string
  client_id: string
  redirect_uri: string
  post_logout_redirect_uri: string
}

export interface PortalApp {
  uid: string
  kind: 'oidc' | 'saml'
  name: string
  launch_url: string
}

export type IdentityProviderKind = 'google' | 'apple' | 'oidc' | 'saml'

export interface IdentityProvider {
  uid: string
  kind: IdentityProviderKind
  name: string
  enabled: boolean
  client_id: string | null
  client_secret_set: boolean
  additional_audiences: string[]
  scopes: string
  discovery_url: string | null
  issuer: string | null
  apple_team_id: string | null
  apple_key_id: string | null
  apple_private_key_set: boolean
  callback_url: string
  saml_idp_entity_id: string | null
  saml_sso_url: string | null
  saml_slo_url: string | null
  saml_idp_certificates: string[]
  saml_name_id_format: SamlNameIdFormat
  saml_email_attribute: string | null
  saml_name_attribute: string | null
  saml_groups_attribute: string | null
  domains: string[]
  create_users: boolean
  allow_idp_initiated: boolean
  sp_entity_id: string | null
  acs_url: string | null
  sp_slo_url: string | null
  group_mappings: IdentityProviderGroupMapping[]
  created_at: string
  updated_at: string
}

export interface IdentityProviderGroupMapping {
  value: string
  group_uid: string
  group_name: string
}

/** What an upstream SAML provider's metadata says, for filling in the form. */
export type SamlProviderMetadata = Partial<Pick<IdentityProvider, 'saml_idp_entity_id' | 'saml_sso_url' | 'saml_slo_url' | 'saml_idp_certificates'>>

export interface IdentityProviderSummary {
  uid: string
  kind: IdentityProviderKind
  name: string
}

/** What the hosted login page shows for one sign-in. */
export interface HostedLoginDetails {
  account_name: string
  project_name: string
  app_name: string
  allow_self_sign_up: boolean
  login_hint: string | null
  /** Some company providers are found from the email's domain instead of a button. */
  home_realm_discovery: boolean
  identity_providers: IdentityProviderSummary[]
}

/** The hosted page never receives tokens: a finished sign-in only says where to send the browser. */
export type HostedSignInResult =
  | { challenge: SignInChallengeName; session: string; recovery_codes?: string[] }
  | { redirect_to: string; recovery_codes?: string[] }

/** An app an end user can sign in to, and the assignments that give them access. */
export interface EndUserAppAccess {
  app_type: AppKind
  uid: string
  name: string
  enabled: boolean
  via: ({ type: 'direct'; assignment_uid: string } | { type: 'group'; assignment_uid: string; group_uid: string; group_name: string })[]
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
  groups: GroupSummary[]
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
  notify_new_devices: boolean
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
  sso_session_ttl_seconds: number
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
  /** The SAML app an end user signed in to, or was refused. */
  saml_app_uid: string | null
  ip: string | null
  user_agent: string | null
  metadata: Record<string, unknown>
  occurred_at: string
}

export interface DeviceSessionLocation {
  city: string | null
  region: string | null
  country_code: string | null
}

/** A device a user is signed in on. Location is approximate, from an offline IP database. */
export interface DeviceSession {
  uid: string
  device_name: string | null
  device_type: string | null
  ip: string | null
  user_agent: string | null
  location: DeviceSessionLocation | null
  amr: string[]
  created_at: string
  last_seen_at: string
  /** The device making the request. */
  current: boolean
}
