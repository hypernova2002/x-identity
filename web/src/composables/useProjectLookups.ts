import { computed } from 'vue'

import { useProjectContext } from './useProjectContext'
import { lookupFrom } from '@/services/list'
import { projectAdminService } from '@/services/project'

/** Searches for the project's searchable dropdowns, and names for values picked earlier. */
export function useProjectLookups() {
  const { accountUid, project } = useProjectContext()
  const projectUid = () => project.value!.uid

  const searchGroups = lookupFrom(
    (params) => projectAdminService.listGroups(accountUid.value, projectUid(), params),
    (group) => ({ label: group.name, value: group.uid }),
  )

  /** Enabled app clients, the ones end users can sign in through. */
  const searchAppClients = lookupFrom(
    (params) => projectAdminService.listApplications(accountUid.value, projectUid(), params),
    (app) => ({ label: `${app.name} (${app.client_type})`, value: app.uid }),
    { app_type_eq: 'app_client', enabled_eq: 'true' },
  )

  async function groupName(groupUid: string) {
    return (await projectAdminService.getGroup(accountUid.value, projectUid(), groupUid).catch(() => null))?.name ?? null
  }

  async function appClientName(clientUid: string) {
    return (await projectAdminService.getAppClient(accountUid.value, projectUid(), clientUid).catch(() => null))?.name ?? null
  }

  const allGroups = computed(() => ({ name: 'project-groups', params: { projectUid: project.value?.uid } }))
  const allApplications = computed(() => ({ name: 'project-applications', params: { projectUid: project.value?.uid }, query: { app_type_eq: 'app_client' } }))

  return { searchGroups, searchAppClients, groupName, appClientName, allGroups, allApplications }
}
