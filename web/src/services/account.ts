import { apiPage, apiRequest } from './http'
import { LOOKUP, listQuery, type ListParams } from './list'
import { auditEventSchema, deviceSessionSchema, invitationSchema, projectMemberSchema, projectSchema, userSchema } from './schemas'
import type { Account, AccountRole, AuthConfiguration, DeletedProject, Invitation, Me, MfaEnrollment, Project, ProjectMember, ProjectRole, ProjectSettings, User, UserStats, UserStatus } from '@/types/api'

const base = (accountUid: string) => `/v1/accounts/${accountUid}`
const authenticated = { authenticated: true } as const

export const meService = {
  listSessions: (accountUid: string, params: ListParams) =>
    apiPage(`${base(accountUid)}/me/sessions`, deviceSessionSchema, { ...authenticated, query: listQuery(params) }),

  signOutSession: (accountUid: string, sessionUid: string) =>
    apiRequest<null>(`${base(accountUid)}/me/sessions/${sessionUid}`, { ...authenticated, method: 'DELETE' }),

  signOutOtherSessions: (accountUid: string) => apiRequest<null>(`${base(accountUid)}/me/sessions`, { ...authenticated, method: 'DELETE' }),

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

  startOtp: (accountUid: string) => apiRequest<MfaEnrollment>(`${base(accountUid)}/me/otp`, { ...authenticated, method: 'POST' }),

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

  listAuditEvents: (accountUid: string, params: ListParams) =>
    apiPage(`${base(accountUid)}/audit-events`, auditEventSchema, { ...authenticated, query: listQuery(params) }),
}

export const userService = {
  list: (accountUid: string, params: ListParams = LOOKUP) =>
    apiPage(`${base(accountUid)}/users`, userSchema, { ...authenticated, query: listQuery(params) }),

  stats: (accountUid: string) => apiRequest<UserStats>(`${base(accountUid)}/users/stats`, authenticated),

  update: (accountUid: string, userUid: string, changes: { role?: AccountRole; status?: UserStatus }) =>
    apiRequest<User>(`${base(accountUid)}/users/${userUid}`, { ...authenticated, method: 'PATCH', body: changes }),

  remove: (accountUid: string, userUid: string) =>
    apiRequest<null>(`${base(accountUid)}/users/${userUid}`, { ...authenticated, method: 'DELETE' }),

  listInvitations: (accountUid: string, params: ListParams = LOOKUP) =>
    apiPage(`${base(accountUid)}/invitations`, invitationSchema, { ...authenticated, query: listQuery(params) }),

  invite: (accountUid: string, email: string, role: AccountRole) =>
    apiRequest<Invitation>(`${base(accountUid)}/invitations`, { ...authenticated, method: 'POST', body: { email, role } }),

  revokeInvitation: (accountUid: string, invitationUid: string) =>
    apiRequest<null>(`${base(accountUid)}/invitations/${invitationUid}`, { ...authenticated, method: 'DELETE' }),
}

export const projectService = {
  list: (accountUid: string, params: ListParams = LOOKUP) =>
    apiPage(`${base(accountUid)}/projects`, projectSchema, { ...authenticated, query: listQuery(params) }),

  get: (accountUid: string, projectUid: string) =>
    apiRequest<Project>(`${base(accountUid)}/projects/${projectUid}`, authenticated),

  create: (accountUid: string, name: string) =>
    apiRequest<Project>(`${base(accountUid)}/projects`, { ...authenticated, method: 'POST', body: { name } }),

  update: (accountUid: string, projectUid: string, settings: Partial<ProjectSettings>) =>
    apiRequest<Project>(`${base(accountUid)}/projects/${projectUid}`, { ...authenticated, method: 'PATCH', body: settings }),

  remove: (accountUid: string, projectUid: string) =>
    apiRequest<null>(`${base(accountUid)}/projects/${projectUid}`, { ...authenticated, method: 'DELETE' }),

  listDeleted: (accountUid: string) => apiRequest<DeletedProject[]>(`${base(accountUid)}/deleted-projects`, authenticated),

  restore: (accountUid: string, projectUid: string) =>
    apiRequest<Project>(`${base(accountUid)}/deleted-projects/${projectUid}/restore`, { ...authenticated, method: 'POST' }),

  listMembers: (accountUid: string, projectUid: string, params: ListParams = LOOKUP) =>
    apiPage(`${base(accountUid)}/projects/${projectUid}/members`, projectMemberSchema, { ...authenticated, query: listQuery(params) }),

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
