import { computed, inject, provide, ref, type ComputedRef, type InjectionKey, type Ref } from 'vue'
import { storeToRefs } from 'pinia'

import { projectService } from '@/services/account'
import { useSessionStore } from '@/stores/session'
import type { Project, ProjectMember } from '@/types/api'

export interface ProjectAccess {
  /** Rename the project, change its settings, members and attributes. */
  admin: boolean
  /** Manage app clients and end users, and read the audit log. */
  developer: boolean
  /** Delete the project. */
  accountAdmin: boolean
}

export interface ProjectContext {
  accountUid: ComputedRef<string>
  project: Ref<Project | null>
  members: Ref<ProjectMember[]>
  access: ComputedRef<ProjectAccess>
  load: (projectUid: string) => Promise<void>
}

const ProjectContextKey = Symbol('ProjectContext') as InjectionKey<ProjectContext>

/** Creates the context for a project page and makes it available to its tabs. */
export function provideProjectContext(): ProjectContext {
  const { account, me, isAccountAdmin } = storeToRefs(useSessionStore())

  const project = ref<Project | null>(null)
  const members = ref<ProjectMember[]>([])

  const accountUid = computed(() => account.value?.uid ?? '')

  const access = computed<ProjectAccess>(() => {
    const role = members.value.find((member) => member.user_uid === me.value?.uid)?.role
    const admin = isAccountAdmin.value || role === 'admin'
    return { admin, developer: admin || role === 'developer', accountAdmin: isAccountAdmin.value }
  })

  async function load(projectUid: string) {
    const [loadedProject, loadedMembers] = await Promise.all([
      projectService.get(accountUid.value, projectUid),
      projectService.listMembers(accountUid.value, projectUid),
    ])
    project.value = loadedProject
    members.value = loadedMembers.items
  }

  const context = { accountUid, project, members, access, load }
  provide(ProjectContextKey, context)
  return context
}

/** The context of the enclosing project page. */
export function useProjectContext(): ProjectContext {
  const context = inject(ProjectContextKey)
  if (!context) throw new Error('useProjectContext must be used inside a project page')
  return context
}
