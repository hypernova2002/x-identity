import type { IdentityProviderInput } from '@/services/project'
import type { IdentityProvider, IdentityProviderKind } from '@/types/api'
import { parseList } from './format'

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
}

const DEFAULT_SCOPES = 'openid email profile'
const DEFAULT_NAMES: Record<IdentityProviderKind, string> = { google: 'Google', apple: 'Apple', oidc: '' }

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
  }
}

export function providerDraftFrom(provider: IdentityProvider): IdentityProviderDraft {
  return {
    ...emptyProviderDraft(provider.kind),
    name: provider.name,
    clientId: provider.client_id,
    additionalAudiences: provider.additional_audiences.join(', '),
    scopes: provider.scopes,
    discoveryUrl: provider.discovery_url ?? '',
    appleTeamId: provider.apple_team_id ?? '',
    appleKeyId: provider.apple_key_id ?? '',
  }
}

/** The fields the draft's kind uses, leaving out blank secrets so saving keeps the current ones. */
export function providerInputFrom(draft: IdentityProviderDraft): IdentityProviderInput {
  const input: IdentityProviderInput = {
    name: draft.name.trim(),
    client_id: draft.clientId.trim(),
    additional_audiences: parseList(draft.additionalAudiences),
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
