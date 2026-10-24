import { ref } from 'vue'

import { useAsyncAction } from './useAsyncAction'
import { lookupFrom, type LookupPage } from '@/services/list'
import { projectAdminService } from '@/services/project'
import type { AppAssignment, AppKind, EndUser, PrincipalType } from '@/types/api'

export interface AppRef {
  kind: AppKind
  uid: string
  name: string
}

/** Who can use one app client or SAML app: its assignments, and finding groups and end users to add. */
export function useAppAccess() {
  const target = ref<{ accountUid: string; projectUid: string; app: AppRef } | null>(null)
  const assignments = ref<AppAssignment[]>([])
  const endUserMatches = ref<EndUser[]>([])

  const load = useAsyncAction(async (accountUid: string, projectUid: string, app: AppRef) => {
    target.value = { accountUid, projectUid, app }
    assignments.value = []
    endUserMatches.value = []
    assignments.value = (await projectAdminService.listAssignments(accountUid, projectUid, app.kind, app.uid)).items
  })

  /** Groups that could be assigned: the search's matches, minus the groups already assigned. */
  async function searchUnassignedGroups(term: string): Promise<LookupPage> {
    if (!target.value) return { items: [], total: 0 }
    const { accountUid, projectUid } = target.value
    const page = await lookupFrom(
      (params) => projectAdminService.listGroups(accountUid, projectUid, params),
      (group) => ({ label: `${group.name} (${group.member_count})`, value: group.uid }),
    )(term)
    const items = page.items.filter((option) => !isAssigned('group', option.value))
    return { items, total: page.total - (page.items.length - items.length) }
  }

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

  return { assignments, endUserMatches, load, searchUnassignedGroups, searchEndUsers, assign, unassign, isAssigned }
}
