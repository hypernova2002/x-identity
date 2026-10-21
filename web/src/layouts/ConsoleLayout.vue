<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { RouterLink, RouterView, useRoute, useRouter, type RouteLocationRaw } from 'vue-router'
import { storeToRefs } from 'pinia'

import BaseButton from '@/components/base/BaseButton.vue'
import ProjectSwitcher from '@/components/console/ProjectSwitcher.vue'
import { useProjectStore } from '@/stores/project'
import { useSessionStore } from '@/stores/session'

interface NavItem {
  label: string
  to: RouteLocationRaw
}

const route = useRoute()
const router = useRouter()
const session = useSessionStore()
const projectStore = useProjectStore()
const { me, isAccountAdmin } = storeToRefs(session)
const { project, projectsLoaded, access } = storeToRefs(projectStore)

/** The project in the URL, or else the one the sidebar offers to open. */
const currentProjectUid = computed(() => {
  const fromRoute = route.params.projectUid
  if (typeof fromRoute === 'string') return fromRoute
  return project.value?.uid ?? (projectsLoaded.value ? projectStore.defaultProjectUid() : null)
})

const projectNavigation = computed<NavItem[]>(() => {
  const projectUid = currentProjectUid.value
  if (!projectUid) return []

  const item = (label: string, name: string): NavItem => ({ label, to: { name, params: { projectUid } } })
  const showAuditLog = project.value?.uid === projectUid && access.value.developer
  return [
    item('Overview', 'project'),
    item('Members', 'project-members'),
    item('App clients', 'project-app-clients'),
    item('End users', 'project-end-users'),
    item('Attributes', 'project-attributes'),
    item('Authentication', 'project-authentication'),
    item('Sign-in providers', 'project-sign-in-providers'),
    item('Test sign-in', 'project-test-sign-in'),
    ...(showAuditLog ? [item('Audit log', 'project-audit-log')] : []),
  ]
})

const accountNavigation = computed<NavItem[]>(() => [
  { label: 'Projects', to: { name: 'projects' } },
  ...(isAccountAdmin.value
    ? [
        { label: 'Users', to: { name: 'users' } },
        { label: 'Authentication', to: { name: 'auth-settings' } },
        { label: 'Audit log', to: { name: 'audit-log' } },
      ]
    : []),
])

const linkClass =
  'block rounded-md border-l-4 border-transparent px-3 py-2 text-sm text-text hover:bg-border focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary aria-[current=page]:border-primary aria-[current=page]:bg-primary-subtle aria-[current=page]:font-semibold aria-[current=page]:text-primary-active'

async function signOut() {
  const slug = session.account?.slug
  await session.signOut()
  projectStore.clear()
  await router.push(slug ? `/${slug}/sign-in` : '/sign-in')
}

onMounted(() => {
  if (!projectsLoaded.value) projectStore.loadProjects().catch(() => null)
})
</script>

<template>
  <div class="flex min-h-screen flex-col md:flex-row">
    <aside class="flex flex-col gap-6 border-b border-border bg-bg-subtle p-4 md:w-64 md:border-r md:border-b-0">
      <div class="flex flex-col gap-1">
        <p class="text-lg font-semibold">x-identity</p>
        <p class="text-sm text-text-muted">{{ me?.account.name }}</p>
      </div>

      <ProjectSwitcher :current-project-uid="currentProjectUid" />

      <nav v-if="projectNavigation.length > 0" aria-label="Project">
        <ul class="flex flex-wrap gap-1 md:flex-col">
          <li v-for="item in projectNavigation" :key="item.label">
            <RouterLink :to="item.to" :class="linkClass">{{ item.label }}</RouterLink>
          </li>
        </ul>
      </nav>

      <nav aria-labelledby="account-navigation-heading" class="flex flex-col gap-1">
        <h2 id="account-navigation-heading" class="px-3 text-xs font-semibold tracking-wide text-text-muted uppercase">Account</h2>
        <ul class="flex flex-wrap gap-1 md:flex-col">
          <li v-for="item in accountNavigation" :key="item.label">
            <RouterLink :to="item.to" :class="linkClass">{{ item.label }}</RouterLink>
          </li>
        </ul>
      </nav>

      <div class="mt-auto flex flex-col gap-2 border-t border-border pt-4">
        <p class="text-sm">
          <span class="font-medium">{{ me?.name }}</span>
          <span class="block text-text-muted">{{ me?.email }} · {{ me?.role }}</span>
        </p>
        <RouterLink :to="{ name: 'security' }" :class="linkClass">My security</RouterLink>
        <BaseButton label="Sign out" variant="secondary" size="sm" @click="signOut" />
      </div>
    </aside>
    <main class="flex-1 p-6">
      <div class="mx-auto flex max-w-5xl flex-col gap-8">
        <RouterView />
      </div>
    </main>
  </div>
</template>
