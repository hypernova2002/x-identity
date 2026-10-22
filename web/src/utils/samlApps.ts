import type { SelectOption } from '@/components/base/types'
import type { SamlAppInput } from '@/services/project'
import type { SamlApp, SamlAppMetadata, SamlNameIdFormat } from '@/types/api'
import { parseList } from './format'

export type AttributeSourceChoice = 'email' | 'email_verified' | 'name' | 'uid' | 'groups' | 'custom'

export interface AttributeMappingDraft {
  name: string
  source: AttributeSourceChoice
  customKey: string
}

/** Form state for adding or editing a SAML app. */
export interface SamlAppDraft {
  name: string
  entityId: string
  acsUrls: string
  sloUrl: string
  spCertificate: string
  nameIdFormat: SamlNameIdFormat
  attributeMappings: AttributeMappingDraft[]
  signAssertion: boolean
  signResponse: boolean
  requireSignedRequests: boolean
  defaultRelayState: string
  enabled: boolean
}

export const attributeSourceOptions: SelectOption<AttributeSourceChoice>[] = [
  { label: 'Email', value: 'email' },
  { label: 'Email verified (true/false)', value: 'email_verified' },
  { label: 'Name', value: 'name' },
  { label: 'User ID', value: 'uid' },
  { label: 'Groups (one value per group)', value: 'groups' },
  { label: 'Custom attribute…', value: 'custom' },
]

export const nameIdFormatOptions: SelectOption<SamlNameIdFormat>[] = [
  { label: 'Email address', value: 'email' },
  { label: 'Persistent (the user ID)', value: 'persistent' },
  { label: 'Unspecified (email address)', value: 'unspecified' },
]

export function emptySamlAppDraft(): SamlAppDraft {
  return {
    name: '',
    entityId: '',
    acsUrls: '',
    sloUrl: '',
    spCertificate: '',
    nameIdFormat: 'email',
    attributeMappings: [{ name: 'email', source: 'email', customKey: '' }],
    signAssertion: true,
    signResponse: false,
    requireSignedRequests: false,
    defaultRelayState: '',
    enabled: true,
  }
}

function mappingDraft(mapping: { name: string; source: string }): AttributeMappingDraft {
  if (mapping.source.startsWith('custom:')) return { name: mapping.name, source: 'custom', customKey: mapping.source.slice('custom:'.length) }
  return { name: mapping.name, source: mapping.source as AttributeSourceChoice, customKey: '' }
}

export function samlAppDraftFrom(app: SamlApp): SamlAppDraft {
  return {
    name: app.name,
    entityId: app.entity_id,
    acsUrls: app.acs_urls.join(', '),
    sloUrl: app.slo_url ?? '',
    spCertificate: app.sp_certificate ?? '',
    nameIdFormat: app.name_id_format,
    attributeMappings: app.attribute_mappings.map(mappingDraft),
    signAssertion: app.sign_assertion,
    signResponse: app.sign_response,
    requireSignedRequests: app.require_signed_requests,
    defaultRelayState: app.default_relay_state ?? '',
    enabled: app.enabled,
  }
}

/** Fills in whatever the app's metadata provided, keeping the rest of the draft. */
export function withMetadata(draft: SamlAppDraft, metadata: SamlAppMetadata): SamlAppDraft {
  return {
    ...draft,
    entityId: metadata.entity_id ?? draft.entityId,
    acsUrls: metadata.acs_urls?.join(', ') ?? draft.acsUrls,
    sloUrl: metadata.slo_url ?? draft.sloUrl,
    spCertificate: metadata.sp_certificate ?? draft.spCertificate,
    nameIdFormat: metadata.name_id_format ?? draft.nameIdFormat,
  }
}

export function samlAppInputFrom(draft: SamlAppDraft): SamlAppInput {
  return {
    name: draft.name.trim(),
    entity_id: draft.entityId.trim(),
    acs_urls: parseList(draft.acsUrls),
    slo_url: draft.sloUrl.trim() || null,
    sp_certificate: draft.spCertificate.trim() || null,
    name_id_format: draft.nameIdFormat,
    attribute_mappings: draft.attributeMappings
      .filter((mapping) => mapping.name.trim() !== '')
      .map((mapping) => ({ name: mapping.name.trim(), source: mapping.source === 'custom' ? `custom:${mapping.customKey.trim()}` : mapping.source })),
    sign_assertion: draft.signAssertion,
    sign_response: draft.signResponse,
    require_signed_requests: draft.requireSignedRequests,
    default_relay_state: draft.defaultRelayState.trim() || null,
    enabled: draft.enabled,
  }
}
