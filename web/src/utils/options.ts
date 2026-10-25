import type { SelectOption } from '@/components/base/types'
import type {
  AccountRole,
  AppClientType,
  AttributeDataType,
  IdentityProviderKind,
  MfaRequirement,
  OtpType,
  PasskeysSetting,
  ProjectRole,
  SigningAlgorithm,
  UserStatus,
} from '@/types/api'

export const identityProviderKindOptions: SelectOption<IdentityProviderKind>[] = [
  { label: 'Google', value: 'google' },
  { label: 'Apple', value: 'apple' },
  { label: 'Other OpenID Connect provider', value: 'oidc' },
  { label: "SAML 2.0 (a company's identity provider)", value: 'saml' },
]

export const accountRoleOptions: SelectOption<AccountRole>[] = [
  { label: 'Owner', value: 'owner' },
  { label: 'Admin', value: 'admin' },
  { label: 'Member', value: 'member' },
]

export const projectRoleOptions: SelectOption<ProjectRole>[] = [
  { label: 'Admin', value: 'admin' },
  { label: 'Developer', value: 'developer' },
  { label: 'Viewer', value: 'viewer' },
]

export const mfaRequirementOptions: SelectOption<MfaRequirement>[] = [
  { label: 'Off — never ask for a code', value: 'off' },
  { label: 'Optional — users choose', value: 'optional' },
  { label: 'Required — everyone must use MFA', value: 'required' },
]

export const passkeysOptions: SelectOption<PasskeysSetting>[] = [
  { label: 'Off', value: 'off' },
  { label: 'Optional: users can add passkeys', value: 'optional' },
]

export const signingAlgorithmOptions: SelectOption<SigningAlgorithm>[] = [
  { label: 'ES256 (ECDSA P-256)', value: 'ES256' },
  { label: 'RS256 (RSA PKCS#1)', value: 'RS256' },
  { label: 'PS256 (RSA-PSS)', value: 'PS256' },
]

export const appClientTypeOptions: SelectOption<AppClientType>[] = [
  { label: 'Public — browser or mobile app, no secret', value: 'public' },
  { label: 'Confidential — server-side app with a secret', value: 'confidential' },
]

export const attributeDataTypeOptions: SelectOption<AttributeDataType>[] = [
  { label: 'Text', value: 'string' },
  { label: 'Number', value: 'number' },
  { label: 'Yes / no', value: 'boolean' },
  { label: 'Date', value: 'date' },
]

export const otpMethodOptions: SelectOption<OtpType>[] = [
  { label: 'Authenticator app (time-based codes)', value: 'totp' },
  { label: 'Hardware token (counter-based codes)', value: 'hotp' },
]

export const userStatusOptions: SelectOption<UserStatus>[] = [
  { label: 'Active', value: 'active' },
  { label: 'Disabled', value: 'disabled' },
]

/** For filters on true/false fields, which the API takes as strings. */
export const yesNoOptions: SelectOption<'true' | 'false'>[] = [
  { label: 'Yes', value: 'true' },
  { label: 'No', value: 'false' },
]
