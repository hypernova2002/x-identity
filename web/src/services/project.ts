import { apiPage, apiRequest } from './http'
import { auditEventQuery, type AuditEventFilters } from './account'
import type {
  AppClient,
  AppClientType,
  AppClientWithSecret,
  AttributeDataType,
  AttributeDefinition,
  AuditEvent,
  AuthConfiguration,
  CustomAttributes,
  EndUser,
  EndUserIdentity,
  EndUserStatus,
  IdentityProvider,
  IdentityProviderKind,
} from '@/types/api'

const authenticated = { authenticated: true } as const

function base(accountUid: string, projectUid: string) {
  return `/v1/accounts/${accountUid}/projects/${projectUid}`
}

export interface EndUserFilters {
  email_cont?: string
}

export interface NewAppClient {
  name: string
  client_type: AppClientType
  allowed_origins: string[]
  redirect_uris: string[]
  post_logout_redirect_uris: string[]
}

/** Settings for an identity provider. Secrets are write-only: leave them out to keep the current ones. */
export interface IdentityProviderInput {
  name: string
  client_id: string
  client_secret?: string
  additional_audiences: string[]
  scopes?: string
  discovery_url?: string
  apple_team_id?: string
  apple_key_id?: string
  apple_private_key?: string
  enabled?: boolean
}

/** Attribute values to send; `null` clears a value. */
export type CustomAttributeInput = Record<string, CustomAttributes[string] | null>

export interface NewEndUser {
  email: string
  name?: string | null
  custom_attributes?: CustomAttributeInput
  send_invitation?: boolean
}

export interface EndUserChanges {
  name?: string | null
  custom_attributes?: CustomAttributeInput
  status?: EndUserStatus
}

export interface NewAttributeDefinition {
  key: string
  label: string
  data_type: AttributeDataType
  required?: boolean
  max_length?: number | null
  user_editable?: boolean
  include_in_token?: boolean
}

export type AttributeDefinitionChanges = Partial<Omit<NewAttributeDefinition, 'key' | 'data_type'>>

/** Console-side management of one project. Every call needs the account and project uids. */
export const projectAdminService = {
  getAuthConfiguration: (accountUid: string, projectUid: string) =>
    apiRequest<AuthConfiguration>(`${base(accountUid, projectUid)}/auth-configuration`, authenticated),

  updateAuthConfiguration: (accountUid: string, projectUid: string, changes: Partial<AuthConfiguration>) =>
    apiRequest<AuthConfiguration>(`${base(accountUid, projectUid)}/auth-configuration`, {
      ...authenticated,
      method: 'PUT',
      body: changes,
    }),

  listAuditEvents: (accountUid: string, projectUid: string, page: number, filters: AuditEventFilters) =>
    apiPage<AuditEvent>(`${base(accountUid, projectUid)}/audit-events`, { ...authenticated, query: auditEventQuery(page, filters) }),

  listAppClients: (accountUid: string, projectUid: string) =>
    apiPage<AppClient>(`${base(accountUid, projectUid)}/app-clients`, { ...authenticated, query: { per_page: 100 } }),

  createAppClient: (accountUid: string, projectUid: string, client: NewAppClient) =>
    apiRequest<AppClientWithSecret>(`${base(accountUid, projectUid)}/app-clients`, { ...authenticated, method: 'POST', body: client }),

  updateAppClient: (accountUid: string, projectUid: string, clientUid: string, changes: Partial<Omit<NewAppClient, 'client_type'>> & { enabled?: boolean }) =>
    apiRequest<AppClient>(`${base(accountUid, projectUid)}/app-clients/${clientUid}`, { ...authenticated, method: 'PATCH', body: changes }),

  rotateAppClientSecret: (accountUid: string, projectUid: string, clientUid: string) =>
    apiRequest<AppClientWithSecret>(`${base(accountUid, projectUid)}/app-clients/${clientUid}/rotate-secret`, {
      ...authenticated,
      method: 'POST',
    }),

  deleteAppClient: (accountUid: string, projectUid: string, clientUid: string) =>
    apiRequest<null>(`${base(accountUid, projectUid)}/app-clients/${clientUid}`, { ...authenticated, method: 'DELETE' }),

  listIdentityProviders: (accountUid: string, projectUid: string) =>
    apiPage<IdentityProvider>(`${base(accountUid, projectUid)}/identity-providers`, { ...authenticated, query: { per_page: 100 } }),

  createIdentityProvider: (accountUid: string, projectUid: string, kind: IdentityProviderKind, input: IdentityProviderInput) =>
    apiRequest<IdentityProvider>(`${base(accountUid, projectUid)}/identity-providers`, {
      ...authenticated,
      method: 'POST',
      body: { kind, ...input },
    }),

  updateIdentityProvider: (accountUid: string, projectUid: string, providerUid: string, changes: Partial<IdentityProviderInput>) =>
    apiRequest<IdentityProvider>(`${base(accountUid, projectUid)}/identity-providers/${providerUid}`, {
      ...authenticated,
      method: 'PATCH',
      body: changes,
    }),

  deleteIdentityProvider: (accountUid: string, projectUid: string, providerUid: string) =>
    apiRequest<null>(`${base(accountUid, projectUid)}/identity-providers/${providerUid}`, { ...authenticated, method: 'DELETE' }),

  listEndUserIdentities: (accountUid: string, projectUid: string, endUserUid: string) =>
    apiRequest<EndUserIdentity[]>(`${base(accountUid, projectUid)}/end-users/${endUserUid}/identities`, authenticated),

  unlinkEndUserIdentity: (accountUid: string, projectUid: string, endUserUid: string, identityUid: string) =>
    apiRequest<null>(`${base(accountUid, projectUid)}/end-users/${endUserUid}/identities/${identityUid}`, {
      ...authenticated,
      method: 'DELETE',
    }),

  listEndUsers: (accountUid: string, projectUid: string, page: number, filters: EndUserFilters) =>
    apiPage<EndUser>(`${base(accountUid, projectUid)}/end-users`, {
      ...authenticated,
      query: { page, 'q[email_cont]': filters.email_cont },
    }),

  createEndUser: (accountUid: string, projectUid: string, endUser: NewEndUser) =>
    apiRequest<EndUser>(`${base(accountUid, projectUid)}/end-users`, { ...authenticated, method: 'POST', body: endUser }),

  updateEndUser: (accountUid: string, projectUid: string, endUserUid: string, changes: EndUserChanges) =>
    apiRequest<EndUser>(`${base(accountUid, projectUid)}/end-users/${endUserUid}`, { ...authenticated, method: 'PATCH', body: changes }),

  deleteEndUser: (accountUid: string, projectUid: string, endUserUid: string) =>
    apiRequest<null>(`${base(accountUid, projectUid)}/end-users/${endUserUid}`, { ...authenticated, method: 'DELETE' }),

  resetEndUserMfa: (accountUid: string, projectUid: string, endUserUid: string) =>
    apiRequest<null>(`${base(accountUid, projectUid)}/end-users/${endUserUid}/mfa`, { ...authenticated, method: 'DELETE' }),

  signOutEndUser: (accountUid: string, projectUid: string, endUserUid: string) =>
    apiRequest<null>(`${base(accountUid, projectUid)}/end-users/${endUserUid}/sign-out`, { ...authenticated, method: 'POST' }),

  resendInvitation: (accountUid: string, projectUid: string, endUserUid: string) =>
    apiRequest<null>(`${base(accountUid, projectUid)}/end-users/${endUserUid}/invitation`, { ...authenticated, method: 'POST' }),

  listAttributes: (accountUid: string, projectUid: string) =>
    apiPage<AttributeDefinition>(`${base(accountUid, projectUid)}/attributes`, { ...authenticated, query: { per_page: 100 } }),

  createAttribute: (accountUid: string, projectUid: string, definition: NewAttributeDefinition) =>
    apiRequest<AttributeDefinition>(`${base(accountUid, projectUid)}/attributes`, { ...authenticated, method: 'POST', body: definition }),

  updateAttribute: (accountUid: string, projectUid: string, definitionUid: string, changes: AttributeDefinitionChanges) =>
    apiRequest<AttributeDefinition>(`${base(accountUid, projectUid)}/attributes/${definitionUid}`, {
      ...authenticated,
      method: 'PATCH',
      body: changes,
    }),

  deleteAttribute: (accountUid: string, projectUid: string, definitionUid: string) =>
    apiRequest<null>(`${base(accountUid, projectUid)}/attributes/${definitionUid}`, { ...authenticated, method: 'DELETE' }),
}
