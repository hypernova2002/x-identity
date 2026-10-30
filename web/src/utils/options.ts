import type { SelectOption } from '@/components/base/types'
import { i18n } from '@/i18n'
import type en from '@/locales/en'
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

// Each label is read when it's shown, so the lists follow the current language.
function options<T extends string>(group: keyof (typeof en)['options'], values: readonly T[]): SelectOption<T>[] {
  return values.map((value) => ({
    get label() {
      return i18n.global.t(`options.${group}.${value}`)
    },
    value,
  }))
}

export const identityProviderKindOptions = options<IdentityProviderKind>('identityProviderKind', ['google', 'apple', 'oidc', 'saml'])

export const accountRoleOptions = options<AccountRole>('accountRole', ['owner', 'admin', 'member'])

export const projectRoleOptions = options<ProjectRole>('projectRole', ['admin', 'developer', 'viewer'])

export const mfaRequirementOptions = options<MfaRequirement>('mfaRequirement', ['off', 'optional', 'required'])

export const passkeysOptions = options<PasskeysSetting>('passkeys', ['off', 'optional', 'required'])

export const signingAlgorithmOptions = options<SigningAlgorithm>('signingAlgorithm', ['ES256', 'RS256', 'PS256'])

export const appClientTypeOptions = options<AppClientType>('appClientType', ['public', 'confidential'])

export const attributeDataTypeOptions = options<AttributeDataType>('attributeDataType', ['string', 'number', 'boolean', 'date'])

export const otpMethodOptions = options<OtpType>('otpMethod', ['totp', 'hotp'])

export const userStatusOptions = options<UserStatus>('userStatus', ['active', 'disabled'])

/** For filters on true/false fields, which the API takes as strings. */
export const yesNoOptions = options<'true' | 'false'>('yesNo', ['true', 'false'])
