import type { SelectOption } from '@/components/base/types'
import type { AccountRole, MfaRequirement, ProjectRole, SigningAlgorithm } from '@/types/api'

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

export const signingAlgorithmOptions: SelectOption<SigningAlgorithm>[] = [
  { label: 'ES256 (ECDSA P-256)', value: 'ES256' },
  { label: 'RS256 (RSA PKCS#1)', value: 'RS256' },
  { label: 'PS256 (RSA-PSS)', value: 'PS256' },
]
