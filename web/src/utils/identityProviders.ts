import type { IdentityProviderInput } from '@/services/project'
import type { IdentityProvider, IdentityProviderKind, SamlNameIdFormat, SamlProviderMetadata } from '@/types/api'
import { parseList } from './format'

export interface GroupMappingDraft {
  value: string
  groupUid: string
}

/** Form state for adding or editing an identity provider. Secrets start blank and stay unchanged unless filled in. */
export interface IdentityProviderDraft {
  kind: IdentityProviderKind
  name: string
  clientId: string
  clientSecret: string
  additionalAudiences: string
  scopes: string
  discoveryUrl: string
  appleTeamId: string
  appleKeyId: string
  applePrivateKey: string
  samlEntityId: string
  samlSsoUrl: string
  samlSloUrl: string
  samlCertificates: string
  samlNameIdFormat: SamlNameIdFormat
  samlEmailAttribute: string
  samlNameAttribute: string
  samlGroupsAttribute: string
  domains: string
  createUsers: boolean
  allowIdpInitiated: boolean
  groupMappings: GroupMappingDraft[]
}

const DEFAULT_SCOPES = 'openid email profile'
const DEFAULT_NAMES: Record<IdentityProviderKind, string> = { google: 'Google', apple: 'Apple', oidc: '', saml: '' }
const CERTIFICATE = /-----BEGIN CERTIFICATE-----[\s\S]+?-----END CERTIFICATE-----/g

export function emptyProviderDraft(kind: IdentityProviderKind): IdentityProviderDraft {
  return {
    kind,
    name: DEFAULT_NAMES[kind],
    clientId: '',
    clientSecret: '',
    additionalAudiences: '',
    scopes: DEFAULT_SCOPES,
    discoveryUrl: '',
    appleTeamId: '',
    appleKeyId: '',
    applePrivateKey: '',
    samlEntityId: '',
    samlSsoUrl: '',
    samlSloUrl: '',
    samlCertificates: '',
    samlNameIdFormat: 'email',
    samlEmailAttribute: '',
    samlNameAttribute: '',
    samlGroupsAttribute: '',
    domains: '',
    createUsers: kind === 'saml',
    allowIdpInitiated: false,
    groupMappings: [],
  }
}

export function providerDraftFrom(provider: IdentityProvider): IdentityProviderDraft {
  return {
    ...emptyProviderDraft(provider.kind),
    name: provider.name,
    clientId: provider.client_id ?? '',
    additionalAudiences: provider.additional_audiences.join(', '),
    scopes: provider.scopes,
    discoveryUrl: provider.discovery_url ?? '',
    appleTeamId: provider.apple_team_id ?? '',
    appleKeyId: provider.apple_key_id ?? '',
    samlEntityId: provider.saml_idp_entity_id ?? '',
    samlSsoUrl: provider.saml_sso_url ?? '',
    samlSloUrl: provider.saml_slo_url ?? '',
    samlCertificates: provider.saml_idp_certificates.join('\n'),
    samlNameIdFormat: provider.saml_name_id_format,
    samlEmailAttribute: provider.saml_email_attribute ?? '',
    samlNameAttribute: provider.saml_name_attribute ?? '',
    samlGroupsAttribute: provider.saml_groups_attribute ?? '',
    domains: provider.domains.join(', '),
    createUsers: provider.create_users,
    allowIdpInitiated: provider.allow_idp_initiated,
    groupMappings: provider.group_mappings.map((mapping) => ({ value: mapping.value, groupUid: mapping.group_uid })),
  }
}

/** Fills in what an upstream SAML provider's metadata says, keeping the rest of the draft. */
export function withProviderMetadata(draft: IdentityProviderDraft, metadata: SamlProviderMetadata): IdentityProviderDraft {
  return {
    ...draft,
    samlEntityId: metadata.saml_idp_entity_id ?? draft.samlEntityId,
    samlSsoUrl: metadata.saml_sso_url ?? draft.samlSsoUrl,
    samlSloUrl: metadata.saml_slo_url ?? draft.samlSloUrl,
    samlCertificates: metadata.saml_idp_certificates?.join('\n') ?? draft.samlCertificates,
  }
}

function samlInputFrom(draft: IdentityProviderDraft): IdentityProviderInput {
  return {
    name: draft.name.trim(),
    additional_audiences: [],
    saml_idp_entity_id: draft.samlEntityId.trim(),
    saml_sso_url: draft.samlSsoUrl.trim(),
    saml_slo_url: draft.samlSloUrl.trim() || null,
    saml_idp_certificates: draft.samlCertificates.match(CERTIFICATE) ?? [],
    saml_name_id_format: draft.samlNameIdFormat,
    saml_email_attribute: draft.samlEmailAttribute.trim() || null,
    saml_name_attribute: draft.samlNameAttribute.trim() || null,
    saml_groups_attribute: draft.samlGroupsAttribute.trim() || null,
    domains: parseList(draft.domains),
    create_users: draft.createUsers,
    allow_idp_initiated: draft.allowIdpInitiated,
    group_mappings: draft.groupMappings
      .filter((mapping) => mapping.value.trim() !== '' && mapping.groupUid !== '')
      .map((mapping) => ({ value: mapping.value.trim(), group_uid: mapping.groupUid })),
  }
}

/** The fields the draft's kind uses, leaving out blank secrets so saving keeps the current ones. */
export function providerInputFrom(draft: IdentityProviderDraft): IdentityProviderInput {
  if (draft.kind === 'saml') return samlInputFrom(draft)

  const input: IdentityProviderInput = {
    name: draft.name.trim(),
    client_id: draft.clientId.trim(),
    additional_audiences: parseList(draft.additionalAudiences),
    create_users: draft.createUsers,
  }

  if (draft.kind === 'apple') {
    input.apple_team_id = draft.appleTeamId.trim()
    input.apple_key_id = draft.appleKeyId.trim()
    if (draft.applePrivateKey.trim()) input.apple_private_key = draft.applePrivateKey.trim()
    return input
  }

  input.scopes = draft.scopes.trim()
  if (draft.clientSecret) input.client_secret = draft.clientSecret
  if (draft.kind === 'oidc') input.discovery_url = draft.discoveryUrl.trim()
  return input
}
