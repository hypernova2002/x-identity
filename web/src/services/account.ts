import { apiPage, apiRequest } from './http'
import type {
  Account,
  AccountRole,
  AuditEvent,
  AuthConfiguration,
  Invitation,
  Me,
  MfaEnrollment,
  OtpType,
  Project,
  ProjectMember,
  ProjectRole,
  ProjectSettings,
  User,
  UserStatus,
} from '@/types/api'

const base = (accountUid: string) => `/v1/accounts/${accountUid}`
const authenticated = { authenticated: true } as const

export interface AuditEventFilters {
  action_start?: string
}

export function auditEventQuery(page: number, filters: AuditEventFilters) {
  return { page, 'q[action_start]': filters.action_start }
}

export const meService = {
  get: (accountUid: string) => apiRequest<Me>(`${base(accountUid)}/me`, authenticated),

  update: (accountUid: string, name: string) =>
    apiRequest<Me>(`${base(accountUid)}/me`, { ...authenticated, method: 'PATCH', body: { name } }),

  changePassword: (accountUid: string, currentPassword: string, newPassword: string) =>
    apiRequest<null>(`${base(accountUid)}/me/password`, {
      ...authenticated,
      method: 'PUT',
      body: { current_password: currentPassword, new_password: newPassword },
    }),

  requestEmailChange: (accountUid: string, newEmail: string, currentPassword: string, otpCode?: string) =>
    apiRequest<null>(`${base(accountUid)}/me/email`, {
      ...authenticated,
      method: 'POST',
      body: { new_email: newEmail, current_password: currentPassword, otp_code: otpCode },
    }),

  startOtp: (accountUid: string, otpType: OtpType) =>
    apiRequest<MfaEnrollment>(`${base(accountUid)}/me/otp`, { ...authenticated, method: 'POST', body: { otp_type: otpType } }),

  confirmOtp: (accountUid: string, code: string) =>
    apiRequest<{ recovery_codes: string[] }>(`${base(accountUid)}/me/otp/confirm`, { ...authenticated, method: 'POST', body: { code } }),

  disableOtp: (accountUid: string, currentPassword: string, code: string) =>
    apiRequest<null>(`${base(accountUid)}/me/otp`, {
      ...authenticated,
      method: 'DELETE',
      body: { current_password: currentPassword, code },
    }),

  regenerateRecoveryCodes: (accountUid: string, code: string) =>
    apiRequest<{ recovery_codes: string[] }>(`${base(accountUid)}/me/recovery-codes`, { ...authenticated, method: 'POST', body: { code } }),
}

export const accountService = {
  get: (accountUid: string) => apiRequest<Account>(base(accountUid), authenticated),

  update: (accountUid: string, name: string) =>
    apiRequest<Account>(base(accountUid), { ...authenticated, method: 'PATCH', body: { name } }),

  getAuthConfiguration: (accountUid: string) =>
    apiRequest<AuthConfiguration>(`${base(accountUid)}/auth-configuration`, authenticated),

  updateAuthConfiguration: (accountUid: string, changes: Partial<AuthConfiguration>) =>
    apiRequest<AuthConfiguration>(`${base(accountUid)}/auth-configuration`, { ...authenticated, method: 'PUT', body: changes }),

  listAuditEvents: (accountUid: string, page: number, filters: AuditEventFilters) =>
    apiPage<AuditEvent>(`${base(accountUid)}/audit-events`, {
      ...authenticated,
      query: auditEventQuery(page, filters),
    }),
}

export const userService = {
  list: (accountUid: string, page: number) => apiPage<User>(`${base(accountUid)}/users`, { ...authenticated, query: { page } }),

  update: (accountUid: string, userUid: string, changes: { role?: AccountRole; status?: UserStatus }) =>
    apiRequest<User>(`${base(accountUid)}/users/${userUid}`, { ...authenticated, method: 'PATCH', body: changes }),

  remove: (accountUid: string, userUid: string) =>
    apiRequest<null>(`${base(accountUid)}/users/${userUid}`, { ...authenticated, method: 'DELETE' }),

  listInvitations: (accountUid: string) =>
    apiPage<Invitation>(`${base(accountUid)}/invitations`, { ...authenticated, query: { per_page: 100 } }),

  invite: (accountUid: string, email: string, role: AccountRole) =>
    apiRequest<Invitation>(`${base(accountUid)}/invitations`, { ...authenticated, method: 'POST', body: { email, role } }),

  revokeInvitation: (accountUid: string, invitationUid: string) =>
    apiRequest<null>(`${base(accountUid)}/invitations/${invitationUid}`, { ...authenticated, method: 'DELETE' }),
}

export const projectService = {
  list: (accountUid: string, page: number) =>
    apiPage<Project>(`${base(accountUid)}/projects`, { ...authenticated, query: { page } }),

  get: (accountUid: string, projectUid: string) =>
    apiRequest<Project>(`${base(accountUid)}/projects/${projectUid}`, authenticated),

  create: (accountUid: string, name: string) =>
    apiRequest<Project>(`${base(accountUid)}/projects`, { ...authenticated, method: 'POST', body: { name } }),

  update: (accountUid: string, projectUid: string, settings: Partial<ProjectSettings>) =>
    apiRequest<Project>(`${base(accountUid)}/projects/${projectUid}`, { ...authenticated, method: 'PATCH', body: settings }),

  remove: (accountUid: string, projectUid: string) =>
    apiRequest<null>(`${base(accountUid)}/projects/${projectUid}`, { ...authenticated, method: 'DELETE' }),

  listMembers: (accountUid: string, projectUid: string) =>
    apiPage<ProjectMember>(`${base(accountUid)}/projects/${projectUid}/members`, { ...authenticated, query: { per_page: 100 } }),

  addMember: (accountUid: string, projectUid: string, userUid: string, role: ProjectRole) =>
    apiRequest<ProjectMember>(`${base(accountUid)}/projects/${projectUid}/members`, {
      ...authenticated,
      method: 'POST',
      body: { user_uid: userUid, role },
    }),

  updateMember: (accountUid: string, projectUid: string, userUid: string, role: ProjectRole) =>
    apiRequest<ProjectMember>(`${base(accountUid)}/projects/${projectUid}/members/${userUid}`, {
      ...authenticated,
      method: 'PATCH',
      body: { role },
    }),

  removeMember: (accountUid: string, projectUid: string, userUid: string) =>
    apiRequest<null>(`${base(accountUid)}/projects/${projectUid}/members/${userUid}`, { ...authenticated, method: 'DELETE' }),
}
