import type { PasskeyCreationOptionsJSON, PasskeyRequestOptionsJSON } from '@/utils/webauthn'

export type AccountRole = 'owner' | 'admin' | 'member'
export type UserStatus = 'active' | 'disabled'
export type ProjectRole = 'admin' | 'developer' | 'viewer'
export type MfaRequirement = 'off' | 'optional' | 'required'
export type SigningAlgorithm = 'ES256' | 'RS256' | 'PS256'
export type SignInChallengeName = 'otp' | 'passkey' | 'new_password' | 'mfa_setup'
/** What can answer a second-factor challenge. */
export type MfaMethod = 'otp' | 'passkey'
export type OtpType = 'totp' | 'hotp'

export interface Account {
  uid: string
  name: string
  slug: string
  created_at: string
  updated_at: string
}

/** The project a custom domain serves, for its hosted pages. */
export interface HostedDomain {
  account_uid: string
  account_slug: string
  account_name: string
  project_uid: string
  project_name: string
  issuer: string
}

export type PasskeysSetting = 'off' | 'optional'

export interface AccountSummary {
  uid: string
  name: string
  slug: string
  /** Whether console users can sign in with passkeys. */
  passkeys?: boolean
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
  /** Whether the account lets console users add passkeys. */
  passkeys_available: boolean
  account: Account
}

export interface Passkey {
  uid: string
  name: string
  created_at: string
  last_used_at: string | null
  /** The domain it belongs to; it only works there. */
  domain: string
  /** Saved in a password manager that syncs it, rather than on one device or security key. */
  synced: boolean
}

export interface PasskeyAuthenticationOptions {
  authentication_id: string
  public_key: PasskeyRequestOptionsJSON
}

export interface PasskeyRegistrationOptions {
  registration_id: string
  public_key: PasskeyCreationOptionsJSON
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
  /** For a second-factor challenge: the methods that can answer it. */
  mfa_methods?: MfaMethod[]
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

export type ProjectDomainStatus = 'pending' | 'verified' | 'failed'

/** A custom domain for the project's hosted login and endpoints, e.g. login.acme.com. */
export interface ProjectDomain {
  uid: string
  hostname: string
  status: ProjectDomainStatus
  verified_at: string | null
  last_checked_at: string | null
  /** What the last DNS check found wrong. */
  check_error: string | null
  /** Since when a verified domain's DNS records have been missing. */
  dns_missing_since: string | null
  /** external: TLS certificates are issued outside x-identity. */
  certificate_status: 'external'
  /** When a pending domain stops being checked and fails. */
  verify_until: string
  created_at: string
  /** The project's SAML apps, and whether each uses the custom domain. */
  saml_apps: SamlConnection[]
  saml_identity_providers: SamlConnection[]
  /** End users' passkeys that belong to the domain; they stop working if it's removed or replaced. */
  passkey_count: number
  dns_records: { type: 'CNAME' | 'TXT'; name: string; value: string }[]
}

export interface SamlConnection {
  uid: string
  name: string
  on_custom_domain: boolean
}

/** Headline counts shown above list pages. */
export interface EndUserStats {
  total: number
  active: number
  disabled: number
  invitation_pending: number
  /** Signed in during the last 30 days. */
  signed_in_recently: number
}

export interface ApplicationStats {
  total: number
  oidc: number
  machine: number
  saml: number
}

export interface GroupStats {
  total: number
  empty: number
}

export interface UserStats {
  total: number
  admins: number
  /** Only for account admins. */
  pending_invitations: number | null
}

/** A deleted project, which an account admin can restore until `purge_at`. */
export interface DeletedProject {
  uid: string
  name: string
  deleted_at: string
  purge_at: string
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
  /** A machine-to-machine app: gets tokens for APIs with client credentials, signs no users in. */
  machine: boolean
  allowed_origins: string[]
  redirect_uris: string[]
  post_logout_redirect_uris: string[]
  launch_url: string | null
  enabled: boolean
  /** Null uses the project's limit. */
  token_requests_per_minute: number | null
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
  machine: boolean
  /** SAML apps only. */
  entity_id: string | null
  created_at: string
  /** Users and groups assigned. */
  assignment_count: number
  /** APIs a machine-to-machine app can get tokens for. */
  api_count: number
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
  /** Whether the app uses the project's custom domain for its entity ID and URLs. */
  on_custom_domain: boolean
  /** What to enter in the app's SAML settings. */
  idp: { entity_id: string; metadata_url: string; sso_url: string; slo_url: string }
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
  /** Whether end users can add passkeys here: they're on, and this is the project's custom domain. */
  passkeys_available: boolean
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
  /** SAML providers: whether the service provider URLs use the project's custom domain. */
  on_custom_domain: boolean | null
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
  /** Whether passkeys can be used here: they're on, and this is the project's custom domain. */
  passkeys: boolean
  /** Some company providers are found from the email's domain instead of a button. */
  home_realm_discovery: boolean
  identity_providers: IdentityProviderSummary[]
}

/** The hosted page never receives tokens: a finished sign-in only says where to send the browser. */
export type HostedSignInResult =
  | SignInChallenge
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
  /** Whether users can add passkeys. A project's also need its verified custom domain. */
  passkeys: PasskeysSetting
  /** Projects only: how long previous client secrets keep working after a rotation. */
  client_secret_rotation_overlap_seconds: number
  /** Projects only: token requests per app client per minute, unless the app sets its own. */
  token_requests_per_minute: number
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

export interface ApiScope {
  name: string
  description: string | null
}

/** One of the project's own APIs, which machine-to-machine apps get access tokens for. */
export interface ApiResource {
  uid: string
  name: string
  /** The `aud` of tokens for the API. */
  identifier: string
  scopes: ApiScope[]
  /** Null uses the project's access token lifetime. */
  access_token_ttl_seconds: number | null
  app_count: number
  created_at: string
  updated_at: string
}

/** The scopes a machine-to-machine app may request on one API. */
export interface ApiGrant {
  uid: string
  api_uid: string
  api_name: string
  api_identifier: string
  scopes: string[]
  created_at: string
  updated_at: string
}

export interface AppClientSecret {
  uid: string
  /** Null for secrets from before rotation overlap. */
  last_four: string | null
  expires_at: string | null
  revoked_at: string | null
  last_used_at: string | null
  created_at: string
  usable: boolean
}
