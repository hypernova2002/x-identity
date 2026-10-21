import { storeToRefs } from 'pinia'

import { useProjectStore } from '@/stores/project'

export type { ProjectAccess } from '@/stores/project'

/** The project the console user is working in, with their access to it. */
export function useProjectContext() {
  const { accountUid, project, members, access } = storeToRefs(useProjectStore())
  return { accountUid, project, members, access }
}
