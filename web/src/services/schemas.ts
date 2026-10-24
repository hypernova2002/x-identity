import { z } from 'zod'

import type {
  AppAssignment,
  AppClient,
  Application,
  AttributeDefinition,
  AuditEvent,
  DeviceSession,
  EndUser,
  Group,
  IdentityProvider,
  Invitation,
  Project,
  ProjectMember,
  SamlApp,
  User,
} from '@/types/api'

/*
 * Runtime schemas for list endpoint items. Each one `satisfies` its type in `types/api.ts`, so the
 * two can't drift apart without a type error.
 */

const timestamp = z.string()
const nullableString = z.string().nullable()
const accountRole = z.enum(['owner', 'admin', 'member'])
const appKind = z.enum(['app_client', 'saml_app'])
const appClientType = z.enum(['public', 'confidential'])
const nameIdFormat = z.enum(['email', 'persistent', 'unspecified'])

export const projectSchema = z.object({
  uid: z.string(),
  name: z.string(),
  allow_self_sign_up: z.boolean(),
  confirm_sign_up_url: nullableString,
  reset_password_url: nullableString,
  accept_invitation_url: nullableString,
  token_issuer: z.string(),
  created_at: timestamp,
  updated_at: timestamp,
}) satisfies z.ZodType<Project>

export const userSchema = z.object({
  uid: z.string(),
  name: z.string(),
  email: z.string(),
  role: accountRole,
  status: z.enum(['active', 'disabled']),
  email_verified: z.boolean(),
  mfa_enabled: z.boolean(),
  last_sign_in_at: nullableString,
  created_at: timestamp,
  updated_at: timestamp,
}) satisfies z.ZodType<User>

export const invitationSchema = z.object({
  uid: z.string(),
  email: z.string(),
  role: accountRole,
  invited_by_uid: nullableString,
  expires_at: timestamp,
  created_at: timestamp,
}) satisfies z.ZodType<Invitation>

export const projectMemberSchema = z.object({
  user_uid: z.string(),
  name: z.string(),
  email: z.string(),
  role: z.enum(['admin', 'developer', 'viewer']),
  created_at: timestamp,
}) satisfies z.ZodType<ProjectMember>

export const endUserSchema = z.object({
  uid: z.string(),
  email: z.string(),
  name: nullableString,
  status: z.enum(['active', 'disabled']),
  email_verified: z.boolean(),
  mfa_enabled: z.boolean(),
  invitation_pending: z.boolean(),
  groups: z.array(z.object({ uid: z.string(), name: z.string() })),
  custom_attributes: z.record(z.string(), z.union([z.string(), z.number(), z.boolean()])),
  last_sign_in_at: nullableString,
  created_at: timestamp,
  updated_at: timestamp,
}) satisfies z.ZodType<EndUser>

export const groupSchema = z.object({
  uid: z.string(),
  name: z.string(),
  description: nullableString,
  default_for_new_users: z.boolean(),
  member_count: z.number(),
  created_at: timestamp,
  updated_at: timestamp,
}) satisfies z.ZodType<Group>

export const attributeDefinitionSchema = z.object({
  uid: z.string(),
  key: z.string(),
  label: z.string(),
  data_type: z.enum(['string', 'number', 'boolean', 'date']),
  required: z.boolean(),
  max_length: z.number().nullable(),
  user_editable: z.boolean(),
  include_in_token: z.boolean(),
  created_at: timestamp,
  updated_at: timestamp,
}) satisfies z.ZodType<AttributeDefinition>

export const identityProviderSchema = z.object({
  uid: z.string(),
  kind: z.enum(['google', 'apple', 'oidc', 'saml']),
  name: z.string(),
  enabled: z.boolean(),
  client_id: nullableString,
  client_secret_set: z.boolean(),
  additional_audiences: z.array(z.string()),
  scopes: z.string(),
  discovery_url: nullableString,
  issuer: nullableString,
  apple_team_id: nullableString,
  apple_key_id: nullableString,
  apple_private_key_set: z.boolean(),
  callback_url: z.string(),
  saml_idp_entity_id: nullableString,
  saml_sso_url: nullableString,
  saml_slo_url: nullableString,
  saml_idp_certificates: z.array(z.string()),
  saml_name_id_format: nameIdFormat,
  saml_email_attribute: nullableString,
  saml_name_attribute: nullableString,
  saml_groups_attribute: nullableString,
  domains: z.array(z.string()),
  create_users: z.boolean(),
  allow_idp_initiated: z.boolean(),
  sp_entity_id: nullableString,
  acs_url: nullableString,
  sp_slo_url: nullableString,
  group_mappings: z.array(z.object({ value: z.string(), group_uid: z.string(), group_name: z.string() })),
  created_at: timestamp,
  updated_at: timestamp,
}) satisfies z.ZodType<IdentityProvider>

export const applicationSchema = z.object({
  app_type: appKind,
  uid: z.string(),
  name: z.string(),
  enabled: z.boolean(),
  client_type: appClientType.nullable(),
  entity_id: nullableString,
  created_at: timestamp,
}) satisfies z.ZodType<Application>

export const appClientSchema = z.object({
  uid: z.string(),
  name: z.string(),
  client_type: appClientType,
  allowed_origins: z.array(z.string()),
  redirect_uris: z.array(z.string()),
  post_logout_redirect_uris: z.array(z.string()),
  launch_url: nullableString,
  enabled: z.boolean(),
  created_at: timestamp,
  updated_at: timestamp,
}) satisfies z.ZodType<AppClient>

export const samlAppSchema = z.object({
  uid: z.string(),
  name: z.string(),
  enabled: z.boolean(),
  entity_id: z.string(),
  acs_urls: z.array(z.string()),
  slo_url: nullableString,
  sp_certificate: nullableString,
  name_id_format: nameIdFormat,
  attribute_mappings: z.array(z.object({ name: z.string(), source: z.string() })),
  sign_assertion: z.boolean(),
  sign_response: z.boolean(),
  require_signed_requests: z.boolean(),
  default_relay_state: nullableString,
  launch_url: z.string(),
  created_at: timestamp,
  updated_at: timestamp,
}) satisfies z.ZodType<SamlApp>

export const appAssignmentSchema = z.object({
  uid: z.string(),
  principal_type: z.enum(['end_user', 'group']),
  principal_uid: z.string(),
  principal_label: z.string(),
  created_at: timestamp,
}) satisfies z.ZodType<AppAssignment>

const auditReference = z.object({ type: z.string(), uid: nullableString, label: nullableString })

export const auditEventSchema = z.object({
  uid: z.string(),
  action: z.string(),
  actor: auditReference,
  target: auditReference.nullable(),
  project_uid: nullableString,
  app_client_uid: nullableString,
  saml_app_uid: nullableString,
  ip: nullableString,
  user_agent: nullableString,
  metadata: z.record(z.string(), z.unknown()),
  occurred_at: timestamp,
}) satisfies z.ZodType<AuditEvent>

export const deviceSessionSchema = z.object({
  uid: z.string(),
  device_name: nullableString,
  device_type: nullableString,
  ip: nullableString,
  user_agent: nullableString,
  location: z.object({ city: nullableString, region: nullableString, country_code: nullableString }).nullable(),
  amr: z.array(z.string()),
  created_at: timestamp,
  last_seen_at: timestamp,
  current: z.boolean(),
}) satisfies z.ZodType<DeviceSession>
