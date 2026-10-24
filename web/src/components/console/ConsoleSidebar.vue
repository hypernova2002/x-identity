<script setup lang="ts">
import { computed } from 'vue'
import { RouterLink, useRoute, type RouteLocationRaw } from 'vue-router'
import { storeToRefs } from 'pinia'

import ProjectSwitcher from '@/components/console/ProjectSwitcher.vue'
import { useProjectStore } from '@/stores/project'
import { useSessionStore } from '@/stores/session'

interface NavItem {
  key: string
  label: string
  to: RouteLocationRaw
}

interface NavGroup {
  key: string
  label: string
  items: NavItem[]
}

const props = defineProps<{
  currentProjectUid: string | null
}>()

const route = useRoute()
const { me, isAccountAdmin } = storeToRefs(useSessionStore())
const { project, projects, access } = storeToRefs(useProjectStore())

const inAccount = computed(() => route.meta.context === 'account')

const projectNavigation = computed<NavGroup[]>(() => {
  const projectUid = props.currentProjectUid
  if (!projectUid) return []

  const item = (key: string, label: string, name: string): NavItem => ({ key, label, to: { name, params: { projectUid } } })
  const canReadAuditLog = project.value?.uid === projectUid && access.value.developer
  return [
    { key: 'overview', label: 'Overview', items: [item('overview', 'Overview', 'project')] },
    {
      key: 'applications',
      label: 'Applications',
      items: [item('applications', 'Applications', 'project-applications'), item('apis', 'APIs', 'project-apis')],
    },
    {
      key: 'directory',
      label: 'Directory',
      items: [item('end-users', 'End users', 'project-end-users'), item('groups', 'Groups', 'project-groups'), item('attributes', 'Attributes', 'project-attributes')],
    },
    {
      key: 'authentication',
      label: 'Authentication',
      items: [item('authentication', 'Settings', 'project-authentication'), item('identity-providers', 'Identity providers', 'project-identity-providers')],
    },
    {
      key: 'monitoring',
      label: 'Monitoring & testing',
      items: [item('test-sign-in', 'Test sign-in', 'project-test-sign-in'), ...(canReadAuditLog ? [item('audit-log', 'Audit log', 'project-audit-log')] : [])],
    },
    {
      key: 'settings',
      label: 'Project settings',
      items: [item('settings', 'General', 'project-settings'), item('members', 'Members', 'project-members')],
    },
  ]
})

const accountNavigation = computed<NavItem[]>(() => [
  { key: 'account-projects', label: 'Projects', to: { name: 'projects' } },
  ...(isAccountAdmin.value
    ? [
        { key: 'account-users', label: 'Console users and roles', to: { name: 'users' } },
        { key: 'account-authentication', label: 'Console sign-in', to: { name: 'auth-settings' } },
        { key: 'account-audit-log', label: 'Audit log', to: { name: 'audit-log' } },
      ]
    : []),
])

const returnProject = computed(() => projects.value.find((existing) => existing.uid === props.currentProjectUid) ?? null)

/** Detail pages (an end user, an application) keep their list's entry current. */
const isCurrent = (item: NavItem) => route.meta.navItem === item.key

const linkClass =
  'block truncate rounded-md border-l-2 border-transparent px-3 py-1.5 text-sm text-text hover:bg-border focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary active:bg-border aria-[current=page]:border-primary aria-[current=page]:bg-primary-subtle aria-[current=page]:font-semibold aria-[current=page]:text-primary-active'
const headingClass = 'px-3 pb-1 text-xs font-semibold tracking-wide text-text-muted uppercase'
const quietLinkClass =
  'block rounded-md px-3 py-2 text-sm font-medium text-text-muted hover:bg-border hover:text-text focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary'
</script>

<template>
  <div class="flex flex-1 flex-col gap-6 p-4">
    <template v-if="inAccount">
      <div class="flex flex-col gap-1 px-3">
        <p class="text-xs text-text-muted">Account</p>
        <p class="truncate text-sm font-semibold" :title="me?.account.name">{{ me?.account.name }}</p>
      </div>
      <nav aria-label="Account">
        <ul class="flex flex-col gap-0.5">
          <li v-for="item in accountNavigation" :key="item.key">
            <RouterLink :to="item.to" :class="linkClass" :aria-current="isCurrent(item) ? 'page' : undefined">{{ item.label }}</RouterLink>
          </li>
        </ul>
      </nav>
      <RouterLink
        v-if="returnProject"
        :to="{ name: 'project', params: { projectUid: returnProject.uid } }"
        :class="quietLinkClass"
        class="mt-auto truncate"
      >
        <span aria-hidden="true">←</span> Back to {{ returnProject.name }}
      </RouterLink>
    </template>

    <template v-else>
      <ProjectSwitcher :current-project-uid="currentProjectUid" />

      <nav v-if="projectNavigation.length > 0" aria-label="Project">
        <ul class="flex flex-col gap-4">
          <li v-for="group in projectNavigation" :key="group.key">
            <RouterLink
              v-if="group.items.length === 1 && group.items[0]!.label === group.label"
              :to="group.items[0]!.to"
              :class="linkClass"
              :aria-current="isCurrent(group.items[0]!) ? 'page' : undefined"
            >
              {{ group.label }}
            </RouterLink>
            <template v-else>
              <p :id="`nav-${group.key}`" :class="headingClass">{{ group.label }}</p>
              <ul :aria-labelledby="`nav-${group.key}`" class="flex flex-col gap-0.5">
                <li v-for="item in group.items" :key="item.key">
                  <RouterLink :to="item.to" :class="linkClass" :aria-current="isCurrent(item) ? 'page' : undefined">{{ item.label }}</RouterLink>
                </li>
              </ul>
            </template>
          </li>
        </ul>
      </nav>

      <RouterLink :to="{ name: 'projects' }" :class="quietLinkClass" class="mt-auto border-t border-border pt-4">Account settings</RouterLink>
    </template>
  </div>
</template>
