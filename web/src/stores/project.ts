import { computed, ref } from 'vue'
import { defineStore } from 'pinia'

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

const LAST_PROJECT_KEY = 'x-identity.last-project'

/** The projects the console user can see, and the one they're currently working in. */
export const useProjectStore = defineStore('project', () => {
  const session = useSessionStore()

  const projects = ref<Project[]>([])
  const project = ref<Project | null>(null)
  const members = ref<ProjectMember[]>([])
  const projectsLoaded = ref(false)

  const accountUid = computed(() => session.account?.uid ?? '')

  const access = computed<ProjectAccess>(() => {
    const role = members.value.find((member) => member.user_uid === session.me?.uid)?.role
    const admin = session.isAccountAdmin || role === 'admin'
    return { admin, developer: admin || role === 'developer', accountAdmin: session.isAccountAdmin }
  })

  async function loadProjects() {
    projects.value = (await projectService.list(accountUid.value)).items
    projectsLoaded.value = true
  }

  /** Loads a project and its members, and remembers it as the one to open next time. */
  async function select(projectUid: string) {
    const [loadedProject, loadedMembers] = await Promise.all([
      projectService.get(accountUid.value, projectUid),
      projectService.listMembers(accountUid.value, projectUid),
    ])
    project.value = loadedProject
    members.value = loadedMembers.items
    remember(projectUid)
  }

  /** Adds or replaces a project in the list, e.g. after it's created or renamed. */
  function upsert(updated: Project) {
    projects.value = projects.value.some((existing) => existing.uid === updated.uid)
      ? projects.value.map((existing) => (existing.uid === updated.uid ? updated : existing))
      : [...projects.value, updated]
    if (project.value?.uid === updated.uid) project.value = updated
  }

  function remove(projectUid: string) {
    projects.value = projects.value.filter((existing) => existing.uid !== projectUid)
    if (project.value?.uid === projectUid) {
      project.value = null
      members.value = []
    }
  }

  /** The project to open when none is in the URL: the last one used, if it still exists, else the first. */
  function defaultProjectUid(): string | null {
    const last = readLast()
    return projects.value.find((existing) => existing.uid === last)?.uid ?? projects.value[0]?.uid ?? null
  }

  function clear() {
    projects.value = []
    project.value = null
    members.value = []
    projectsLoaded.value = false
  }

  function storageKey() {
    return `${LAST_PROJECT_KEY}.${accountUid.value}`
  }

  function remember(projectUid: string) {
    try {
      localStorage.setItem(storageKey(), projectUid)
    } catch {
      // Storage can be unavailable (private mode, blocked site data); the console then opens the first project.
    }
  }

  function readLast(): string | null {
    try {
      return localStorage.getItem(storageKey())
    } catch {
      return null
    }
  }

  return { accountUid, projects, project, members, projectsLoaded, access, loadProjects, select, upsert, remove, defaultProjectUid, clear }
})
