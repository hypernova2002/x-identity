import { computed, ref } from 'vue'

import { useAsyncAction } from './useAsyncAction'
import { projectAdminService } from '@/services/project'
import type { AppAssignment, AppKind, EndUser, Group, PrincipalType } from '@/types/api'

export interface AppRef {
  kind: AppKind
  uid: string
  name: string
}

/** Who can use one app client or SAML app: its assignments, and finding groups and end users to add. */
export function useAppAccess() {
  const target = ref<{ accountUid: string; projectUid: string; app: AppRef } | null>(null)
  const assignments = ref<AppAssignment[]>([])
  const groups = ref<Group[]>([])
  const endUserMatches = ref<EndUser[]>([])

  const unassignedGroups = computed(() =>
    groups.value.filter((group) => !assignments.value.some((assignment) => assignment.principal_type === 'group' && assignment.principal_uid === group.uid)),
  )

  const load = useAsyncAction(async (accountUid: string, projectUid: string, app: AppRef) => {
    target.value = { accountUid, projectUid, app }
    assignments.value = []
    endUserMatches.value = []
    const [loadedAssignments, loadedGroups] = await Promise.all([
      projectAdminService.listAssignments(accountUid, projectUid, app.kind, app.uid),
      projectAdminService.listGroups(accountUid, projectUid),
    ])
    assignments.value = loadedAssignments.items
    groups.value = loadedGroups.items
  })

  const searchEndUsers = useAsyncAction(async (email: string) => {
    if (!target.value) return
    const { accountUid, projectUid } = target.value
    endUserMatches.value = (await projectAdminService.listEndUsers(accountUid, projectUid, { search: email })).items
  })

  const assign = useAsyncAction(async (principalType: PrincipalType, principalUid: string) => {
    if (!target.value) return
    const { accountUid, projectUid, app } = target.value
    assignments.value = [...assignments.value, await projectAdminService.assign(accountUid, projectUid, app.kind, app.uid, principalType, principalUid)]
  })

  const unassign = useAsyncAction(async (assignment: AppAssignment) => {
    if (!target.value) return
    const { accountUid, projectUid, app } = target.value
    await projectAdminService.unassign(accountUid, projectUid, app.kind, app.uid, assignment.uid)
    assignments.value = assignments.value.filter((existing) => existing.uid !== assignment.uid)
  })

  function isAssigned(principalType: PrincipalType, principalUid: string) {
    return assignments.value.some((assignment) => assignment.principal_type === principalType && assignment.principal_uid === principalUid)
  }

  return { assignments, groups, unassignedGroups, endUserMatches, load, searchEndUsers, assign, unassign, isAssigned }
}
