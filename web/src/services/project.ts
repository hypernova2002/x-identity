import { apiPage, apiRequest } from './http'
import { LOOKUP, listQuery, type ListParams } from './list'
import {
  appAssignmentSchema,
  apiResourceSchema,
  appClientSchema,
  applicationSchema,
  attributeDefinitionSchema,
  auditEventSchema,
  deviceSessionSchema,
  endUserSchema,
  groupSchema,
  identityProviderSchema,
  samlAppSchema,
} from './schemas'
import type {
  ApiGrant,
  ApiResource,
  ApiScope,
  AppClient,
  AppClientSecret,
  AppClientType,
  AppClientWithSecret,
  AttributeDataType,
  AppAssignment,
  AppKind,
  ApplicationStats,
  AttributeDefinition,
  AuthConfiguration,
  CustomAttributes,
  EndUser,
  EndUserStats,
  EndUserAppAccess,
  EndUserIdentity,
  EndUserStatus,
  Group,
  GroupStats,
  Passkey,
  ProjectDomain,
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

export interface NewAppClient {
  name: string
  client_type: AppClientType
  machine?: boolean
  allowed_origins: string[]
  redirect_uris: string[]
  post_logout_redirect_uris: string[]
  launch_url: string | null
}

export interface ApiResourceInput {
  name: string
  identifier: string
  scopes: ApiScope[]
  access_token_ttl_seconds: number | null
}

export interface GroupInput {
  name: string
  description: string | null
  default_for_new_users: boolean
}

export type SamlAppInput = Omit<SamlApp, 'uid' | 'launch_url' | 'on_custom_domain' | 'idp' | 'created_at' | 'updated_at'> & { on_custom_domain?: boolean }

const appPath = (kind: AppKind) => (kind === 'saml_app' ? 'saml-apps' : 'app-clients')

/** Settings for an identity provider. Secrets are write-only: leave them out to keep the current ones. */
export interface IdentityProviderInput {
  name: string
  /** SAML only: use the project's verified custom domain for the service provider URLs. */
  on_custom_domain?: boolean
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

  listAuditEvents: (accountUid: string, projectUid: string, params: ListParams) =>
    apiPage(`${base(accountUid, projectUid)}/audit-events`, auditEventSchema, { ...authenticated, query: listQuery(params) }),

  listApplications: (accountUid: string, projectUid: string, params: ListParams) =>
    apiPage(`${base(accountUid, projectUid)}/applications`, applicationSchema, { ...authenticated, query: listQuery(params) }),

  applicationStats: (accountUid: string, projectUid: string) =>
    apiRequest<ApplicationStats>(`${base(accountUid, projectUid)}/applications/stats`, authenticated),

  listAppClients: (accountUid: string, projectUid: string) =>
    apiPage(`${base(accountUid, projectUid)}/app-clients`, appClientSchema, { ...authenticated, query: listQuery(LOOKUP) }),

  createAppClient: (accountUid: string, projectUid: string, client: NewAppClient) =>
    apiRequest<AppClientWithSecret>(`${base(accountUid, projectUid)}/app-clients`, { ...authenticated, method: 'POST', body: client }),

  updateAppClient: (
    accountUid: string,
    projectUid: string,
    clientUid: string,
    changes: Partial<Omit<NewAppClient, 'client_type'>> & { enabled?: boolean; token_requests_per_minute?: number | null },
  ) =>
    apiRequest<AppClient>(`${base(accountUid, projectUid)}/app-clients/${clientUid}`, { ...authenticated, method: 'PATCH', body: changes }),

  listAppClientSecrets: (accountUid: string, projectUid: string, clientUid: string) =>
    apiRequest<AppClientSecret[]>(`${base(accountUid, projectUid)}/app-clients/${clientUid}/secrets`, authenticated),

  revokeAppClientSecret: (accountUid: string, projectUid: string, clientUid: string, secretUid: string) =>
    apiRequest<null>(`${base(accountUid, projectUid)}/app-clients/${clientUid}/secrets/${secretUid}`, { ...authenticated, method: 'DELETE' }),

  listApis: (accountUid: string, projectUid: string, params: ListParams = LOOKUP) =>
    apiPage(`${base(accountUid, projectUid)}/apis`, apiResourceSchema, { ...authenticated, query: listQuery(params) }),

  getApi: (accountUid: string, projectUid: string, apiUid: string) =>
    apiRequest<ApiResource>(`${base(accountUid, projectUid)}/apis/${apiUid}`, authenticated),

  createApi: (accountUid: string, projectUid: string, api: ApiResourceInput) =>
    apiRequest<ApiResource>(`${base(accountUid, projectUid)}/apis`, { ...authenticated, method: 'POST', body: api }),

  updateApi: (accountUid: string, projectUid: string, apiUid: string, changes: Partial<Omit<ApiResourceInput, 'identifier'>>) =>
    apiRequest<ApiResource>(`${base(accountUid, projectUid)}/apis/${apiUid}`, { ...authenticated, method: 'PATCH', body: changes }),

  deleteApi: (accountUid: string, projectUid: string, apiUid: string) =>
    apiRequest<null>(`${base(accountUid, projectUid)}/apis/${apiUid}`, { ...authenticated, method: 'DELETE' }),

  listApiGrants: (accountUid: string, projectUid: string, clientUid: string) =>
    apiRequest<ApiGrant[]>(`${base(accountUid, projectUid)}/app-clients/${clientUid}/api-grants`, authenticated),

  grantApi: (accountUid: string, projectUid: string, clientUid: string, apiUid: string, scopes: string[]) =>
    apiRequest<ApiGrant>(`${base(accountUid, projectUid)}/app-clients/${clientUid}/api-grants`, {
      ...authenticated,
      method: 'POST',
      body: { api_uid: apiUid, scopes },
    }),

  updateApiGrant: (accountUid: string, projectUid: string, clientUid: string, grantUid: string, scopes: string[]) =>
    apiRequest<ApiGrant>(`${base(accountUid, projectUid)}/app-clients/${clientUid}/api-grants/${grantUid}`, {
      ...authenticated,
      method: 'PATCH',
      body: { scopes },
    }),

  revokeApiGrant: (accountUid: string, projectUid: string, clientUid: string, grantUid: string) =>
    apiRequest<null>(`${base(accountUid, projectUid)}/app-clients/${clientUid}/api-grants/${grantUid}`, { ...authenticated, method: 'DELETE' }),

  rotateAppClientSecret: (accountUid: string, projectUid: string, clientUid: string) =>
    apiRequest<AppClientWithSecret>(`${base(accountUid, projectUid)}/app-clients/${clientUid}/rotate-secret`, {
      ...authenticated,
      method: 'POST',
    }),

  deleteAppClient: (accountUid: string, projectUid: string, clientUid: string) =>
    apiRequest<null>(`${base(accountUid, projectUid)}/app-clients/${clientUid}`, { ...authenticated, method: 'DELETE' }),

  listIdentityProviders: (accountUid: string, projectUid: string, params: ListParams = LOOKUP) =>
    apiPage(`${base(accountUid, projectUid)}/identity-providers`, identityProviderSchema, { ...authenticated, query: listQuery(params) }),

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

  listEndUserPasskeys: (accountUid: string, projectUid: string, endUserUid: string) =>
    apiRequest<Passkey[]>(`${base(accountUid, projectUid)}/end-users/${endUserUid}/passkeys`, authenticated),

  removeEndUserPasskey: (accountUid: string, projectUid: string, endUserUid: string, passkeyUid: string) =>
    apiRequest<null>(`${base(accountUid, projectUid)}/end-users/${endUserUid}/passkeys/${passkeyUid}`, { ...authenticated, method: 'DELETE' }),

  unlinkEndUserIdentity: (accountUid: string, projectUid: string, endUserUid: string, identityUid: string) =>
    apiRequest<null>(`${base(accountUid, projectUid)}/end-users/${endUserUid}/identities/${identityUid}`, {
      ...authenticated,
      method: 'DELETE',
    }),

  listGroups: (accountUid: string, projectUid: string, params: ListParams = LOOKUP) =>
    apiPage(`${base(accountUid, projectUid)}/groups`, groupSchema, { ...authenticated, query: listQuery(params) }),

  groupStats: (accountUid: string, projectUid: string) => apiRequest<GroupStats>(`${base(accountUid, projectUid)}/groups/stats`, authenticated),

  getGroup: (accountUid: string, projectUid: string, groupUid: string) =>
    apiRequest<Group>(`${base(accountUid, projectUid)}/groups/${groupUid}`, authenticated),

  createGroup: (accountUid: string, projectUid: string, input: GroupInput) =>
    apiRequest<Group>(`${base(accountUid, projectUid)}/groups`, { ...authenticated, method: 'POST', body: input }),

  updateGroup: (accountUid: string, projectUid: string, groupUid: string, input: Partial<GroupInput>) =>
    apiRequest<Group>(`${base(accountUid, projectUid)}/groups/${groupUid}`, { ...authenticated, method: 'PATCH', body: input }),

  deleteGroup: (accountUid: string, projectUid: string, groupUid: string) =>
    apiRequest<null>(`${base(accountUid, projectUid)}/groups/${groupUid}`, { ...authenticated, method: 'DELETE' }),

  listGroupMembers: (accountUid: string, projectUid: string, groupUid: string, page: number) =>
    apiPage(`${base(accountUid, projectUid)}/groups/${groupUid}/members`, endUserSchema, { ...authenticated, query: listQuery({ page }) }),

  addGroupMember: (accountUid: string, projectUid: string, groupUid: string, endUserUid: string) =>
    apiRequest<null>(`${base(accountUid, projectUid)}/groups/${groupUid}/members`, {
      ...authenticated,
      method: 'POST',
      body: { end_user_uid: endUserUid },
    }),

  removeGroupMember: (accountUid: string, projectUid: string, groupUid: string, endUserUid: string) =>
    apiRequest<null>(`${base(accountUid, projectUid)}/groups/${groupUid}/members/${endUserUid}`, { ...authenticated, method: 'DELETE' }),

  listAssignments: (accountUid: string, projectUid: string, kind: AppKind, appUid: string) =>
    apiPage(`${base(accountUid, projectUid)}/${appPath(kind)}/${appUid}/assignments`, appAssignmentSchema, { ...authenticated, query: listQuery(LOOKUP) }),

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
    apiPage(`${base(accountUid, projectUid)}/saml-apps`, samlAppSchema, { ...authenticated, query: listQuery(LOOKUP) }),

  createSamlApp: (accountUid: string, projectUid: string, input: SamlAppInput) =>
    apiRequest<SamlApp>(`${base(accountUid, projectUid)}/saml-apps`, { ...authenticated, method: 'POST', body: input }),

  updateSamlApp: (accountUid: string, projectUid: string, appUid: string, input: Partial<SamlAppInput>) =>
    apiRequest<SamlApp>(`${base(accountUid, projectUid)}/saml-apps/${appUid}`, { ...authenticated, method: 'PATCH', body: input }),

  deleteSamlApp: (accountUid: string, projectUid: string, appUid: string) =>
    apiRequest<null>(`${base(accountUid, projectUid)}/saml-apps/${appUid}`, { ...authenticated, method: 'DELETE' }),

  parseSamlMetadata: (accountUid: string, projectUid: string, source: { metadata_xml: string } | { metadata_url: string }) =>
    apiRequest<SamlAppMetadata>(`${base(accountUid, projectUid)}/saml-apps/parse-metadata`, { ...authenticated, method: 'POST', body: source }),

  listDomains: (accountUid: string, projectUid: string) => apiRequest<ProjectDomain[]>(`${base(accountUid, projectUid)}/domains`, authenticated),

  addDomain: (accountUid: string, projectUid: string, hostname: string) =>
    apiRequest<ProjectDomain>(`${base(accountUid, projectUid)}/domains`, { ...authenticated, method: 'POST', body: { hostname } }),

  checkDomain: (accountUid: string, projectUid: string, domainUid: string) =>
    apiRequest<ProjectDomain>(`${base(accountUid, projectUid)}/domains/${domainUid}/check`, { ...authenticated, method: 'POST' }),

  removeDomain: (accountUid: string, projectUid: string, domainUid: string) =>
    apiRequest<null>(`${base(accountUid, projectUid)}/domains/${domainUid}`, { ...authenticated, method: 'DELETE' }),

  getSamlIdentityProvider: (accountUid: string, projectUid: string) =>
    apiRequest<SamlIdentityProviderInfo>(`${base(accountUid, projectUid)}/saml-certificates`, authenticated),

  addSamlCertificate: (accountUid: string, projectUid: string) =>
    apiRequest<SamlCertificate>(`${base(accountUid, projectUid)}/saml-certificates`, { ...authenticated, method: 'POST' }),

  activateSamlCertificate: (accountUid: string, projectUid: string, certificateUid: string) =>
    apiRequest<SamlCertificate>(`${base(accountUid, projectUid)}/saml-certificates/${certificateUid}/activate`, { ...authenticated, method: 'POST' }),

  removeSamlCertificate: (accountUid: string, projectUid: string, certificateUid: string) =>
    apiRequest<null>(`${base(accountUid, projectUid)}/saml-certificates/${certificateUid}`, { ...authenticated, method: 'DELETE' }),

  listEndUsers: (accountUid: string, projectUid: string, params: ListParams) =>
    apiPage(`${base(accountUid, projectUid)}/end-users`, endUserSchema, { ...authenticated, query: listQuery(params) }),

  endUserStats: (accountUid: string, projectUid: string) =>
    apiRequest<EndUserStats>(`${base(accountUid, projectUid)}/end-users/stats`, authenticated),

  listEndUserSessions: (accountUid: string, projectUid: string, endUserUid: string, params: ListParams) =>
    apiPage(`${base(accountUid, projectUid)}/end-users/${endUserUid}/sessions`, deviceSessionSchema, { ...authenticated, query: listQuery(params) }),

  signOutEndUserSession: (accountUid: string, projectUid: string, endUserUid: string, sessionUid: string) =>
    apiRequest<null>(`${base(accountUid, projectUid)}/end-users/${endUserUid}/sessions/${sessionUid}`, { ...authenticated, method: 'DELETE' }),

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

  listAttributes: (accountUid: string, projectUid: string, params: ListParams = LOOKUP) =>
    apiPage(`${base(accountUid, projectUid)}/attributes`, attributeDefinitionSchema, { ...authenticated, query: listQuery(params) }),

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
