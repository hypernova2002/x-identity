import { apiPage, apiRequest } from './http'
import { auditEventQuery, type AuditEventFilters } from './account'
import type {
  AppClient,
  AppClientType,
  AppClientWithSecret,
  AttributeDataType,
  AppAssignment,
  AppKind,
  AttributeDefinition,
  AuditEvent,
  AuthConfiguration,
  CustomAttributes,
  EndUser,
  EndUserAppAccess,
  EndUserIdentity,
  EndUserStatus,
  Group,
  IdentityProvider,
  IdentityProviderKind,
  PrincipalType,
  SamlApp,
  SamlAppMetadata,
  SamlCertificate,
  SamlIdentityProviderInfo,
  SamlNameIdFormat,
  SamlProviderMetadata,
} from '@/types/api'

const authenticated = { authenticated: true } as const

function base(accountUid: string, projectUid: string) {
  return `/v1/accounts/${accountUid}/projects/${projectUid}`
}

export interface EndUserFilters {
  email_cont?: string
  uid_eq?: string
  status_eq?: EndUserStatus
  email_verified?: boolean
  mfa?: boolean
  invitation_pending?: boolean
  group_uid?: string
}

const flag = (value: boolean | undefined) => (value === undefined ? undefined : String(value))

function endUserQuery(page: number, filters: EndUserFilters) {
  return {
    page,
    'q[email_cont]': filters.email_cont,
    'q[uid_eq]': filters.uid_eq,
    'q[status_eq]': filters.status_eq,
    'filter[email_verified]': flag(filters.email_verified),
    'filter[mfa]': flag(filters.mfa),
    'filter[invitation_pending]': filters.invitation_pending ? 'true' : undefined,
    'filter[group_uid]': filters.group_uid,
  }
}

export interface NewAppClient {
  name: string
  client_type: AppClientType
  allowed_origins: string[]
  redirect_uris: string[]
  post_logout_redirect_uris: string[]
  launch_url: string | null
}

export interface GroupInput {
  name: string
  description: string | null
  default_for_new_users: boolean
}

export type SamlAppInput = Omit<SamlApp, 'uid' | 'launch_url' | 'created_at' | 'updated_at'>

const appPath = (kind: AppKind) => (kind === 'saml_app' ? 'saml-apps' : 'app-clients')

/** Settings for an identity provider. Secrets are write-only: leave them out to keep the current ones. */
export interface IdentityProviderInput {
  name: string
  client_id?: string
  client_secret?: string
  additional_audiences: string[]
  scopes?: string
  discovery_url?: string
  apple_team_id?: string
  apple_key_id?: string
  apple_private_key?: string
  saml_idp_entity_id?: string
  saml_sso_url?: string
  saml_slo_url?: string | null
  saml_idp_certificates?: string[]
  saml_name_id_format?: SamlNameIdFormat
  saml_email_attribute?: string | null
  saml_name_attribute?: string | null
  saml_groups_attribute?: string | null
  domains?: string[]
  create_users?: boolean
  allow_idp_initiated?: boolean
  group_mappings?: { value: string; group_uid: string }[]
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

  parseSamlProviderMetadata: (accountUid: string, projectUid: string, source: { metadata_xml: string } | { metadata_url: string }) =>
    apiRequest<SamlProviderMetadata>(`${base(accountUid, projectUid)}/identity-providers/parse-saml-metadata`, {
      ...authenticated,
      method: 'POST',
      body: source,
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

  listGroups: (accountUid: string, projectUid: string) =>
    apiPage<Group>(`${base(accountUid, projectUid)}/groups`, { ...authenticated, query: { per_page: 100 } }),

  createGroup: (accountUid: string, projectUid: string, input: GroupInput) =>
    apiRequest<Group>(`${base(accountUid, projectUid)}/groups`, { ...authenticated, method: 'POST', body: input }),

  updateGroup: (accountUid: string, projectUid: string, groupUid: string, input: Partial<GroupInput>) =>
    apiRequest<Group>(`${base(accountUid, projectUid)}/groups/${groupUid}`, { ...authenticated, method: 'PATCH', body: input }),

  deleteGroup: (accountUid: string, projectUid: string, groupUid: string) =>
    apiRequest<null>(`${base(accountUid, projectUid)}/groups/${groupUid}`, { ...authenticated, method: 'DELETE' }),

  listGroupMembers: (accountUid: string, projectUid: string, groupUid: string, page: number) =>
    apiPage<EndUser>(`${base(accountUid, projectUid)}/groups/${groupUid}/members`, { ...authenticated, query: { page } }),

  addGroupMember: (accountUid: string, projectUid: string, groupUid: string, endUserUid: string) =>
    apiRequest<null>(`${base(accountUid, projectUid)}/groups/${groupUid}/members`, {
      ...authenticated,
      method: 'POST',
      body: { end_user_uid: endUserUid },
    }),

  removeGroupMember: (accountUid: string, projectUid: string, groupUid: string, endUserUid: string) =>
    apiRequest<null>(`${base(accountUid, projectUid)}/groups/${groupUid}/members/${endUserUid}`, { ...authenticated, method: 'DELETE' }),

  listAssignments: (accountUid: string, projectUid: string, kind: AppKind, appUid: string) =>
    apiPage<AppAssignment>(`${base(accountUid, projectUid)}/${appPath(kind)}/${appUid}/assignments`, { ...authenticated, query: { per_page: 100 } }),

  assign: (accountUid: string, projectUid: string, kind: AppKind, appUid: string, principalType: PrincipalType, principalUid: string) =>
    apiRequest<AppAssignment>(`${base(accountUid, projectUid)}/${appPath(kind)}/${appUid}/assignments`, {
      ...authenticated,
      method: 'POST',
      body: { principal_type: principalType, principal_uid: principalUid },
    }),

  unassign: (accountUid: string, projectUid: string, kind: AppKind, appUid: string, assignmentUid: string) =>
    apiRequest<null>(`${base(accountUid, projectUid)}/${appPath(kind)}/${appUid}/assignments/${assignmentUid}`, {
      ...authenticated,
      method: 'DELETE',
    }),

  listSamlApps: (accountUid: string, projectUid: string) =>
    apiPage<SamlApp>(`${base(accountUid, projectUid)}/saml-apps`, { ...authenticated, query: { per_page: 100 } }),

  createSamlApp: (accountUid: string, projectUid: string, input: SamlAppInput) =>
    apiRequest<SamlApp>(`${base(accountUid, projectUid)}/saml-apps`, { ...authenticated, method: 'POST', body: input }),

  updateSamlApp: (accountUid: string, projectUid: string, appUid: string, input: Partial<SamlAppInput>) =>
    apiRequest<SamlApp>(`${base(accountUid, projectUid)}/saml-apps/${appUid}`, { ...authenticated, method: 'PATCH', body: input }),

  deleteSamlApp: (accountUid: string, projectUid: string, appUid: string) =>
    apiRequest<null>(`${base(accountUid, projectUid)}/saml-apps/${appUid}`, { ...authenticated, method: 'DELETE' }),

  parseSamlMetadata: (accountUid: string, projectUid: string, source: { metadata_xml: string } | { metadata_url: string }) =>
    apiRequest<SamlAppMetadata>(`${base(accountUid, projectUid)}/saml-apps/parse-metadata`, { ...authenticated, method: 'POST', body: source }),

  getSamlIdentityProvider: (accountUid: string, projectUid: string) =>
    apiRequest<SamlIdentityProviderInfo>(`${base(accountUid, projectUid)}/saml-certificates`, authenticated),

  addSamlCertificate: (accountUid: string, projectUid: string) =>
    apiRequest<SamlCertificate>(`${base(accountUid, projectUid)}/saml-certificates`, { ...authenticated, method: 'POST' }),

  activateSamlCertificate: (accountUid: string, projectUid: string, certificateUid: string) =>
    apiRequest<SamlCertificate>(`${base(accountUid, projectUid)}/saml-certificates/${certificateUid}/activate`, { ...authenticated, method: 'POST' }),

  removeSamlCertificate: (accountUid: string, projectUid: string, certificateUid: string) =>
    apiRequest<null>(`${base(accountUid, projectUid)}/saml-certificates/${certificateUid}`, { ...authenticated, method: 'DELETE' }),

  listEndUsers: (accountUid: string, projectUid: string, page: number, filters: EndUserFilters) =>
    apiPage<EndUser>(`${base(accountUid, projectUid)}/end-users`, {
      ...authenticated,
      query: endUserQuery(page, filters),
    }),

  getEndUser: (accountUid: string, projectUid: string, endUserUid: string) =>
    apiRequest<EndUser>(`${base(accountUid, projectUid)}/end-users/${endUserUid}`, authenticated),

  getEndUserAccess: (accountUid: string, projectUid: string, endUserUid: string) =>
    apiRequest<EndUserAppAccess[]>(`${base(accountUid, projectUid)}/end-users/${endUserUid}/access`, authenticated),

  getAppClient: (accountUid: string, projectUid: string, clientUid: string) =>
    apiRequest<AppClient>(`${base(accountUid, projectUid)}/app-clients/${clientUid}`, authenticated),

  getSamlApp: (accountUid: string, projectUid: string, appUid: string) =>
    apiRequest<SamlApp>(`${base(accountUid, projectUid)}/saml-apps/${appUid}`, authenticated),

  getIdentityProvider: (accountUid: string, projectUid: string, providerUid: string) =>
    apiRequest<IdentityProvider>(`${base(accountUid, projectUid)}/identity-providers/${providerUid}`, authenticated),

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
