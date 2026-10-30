<script setup lang="ts">
import { computed } from 'vue'
import { RouterLink, useRoute, type RouteLocationRaw } from 'vue-router'
import { storeToRefs } from 'pinia'
import { useI18n } from 'vue-i18n'

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
const { t } = useI18n()
const { me, isAccountAdmin } = storeToRefs(useSessionStore())
const { project, projects, access } = storeToRefs(useProjectStore())

const inAccount = computed(() => route.meta.context === 'account')

const projectNavigation = computed<NavGroup[]>(() => {
  const projectUid = props.currentProjectUid
  if (!projectUid) return []

  const item = (key: string, label: string, name: string): NavItem => ({ key, label, to: { name, params: { projectUid } } })
  const canReadAuditLog = project.value?.uid === projectUid && access.value.developer
  return [
    { key: 'overview', label: t('shell.nav.overview'), items: [item('overview', t('shell.nav.overview'), 'project')] },
    {
      key: 'applications',
      label: t('shell.nav.applications'),
      items: [item('applications', t('shell.nav.applications'), 'project-applications'), item('apis', t('shell.nav.apis'), 'project-apis')],
    },
    {
      key: 'directory',
      label: t('shell.nav.directory'),
      items: [
        item('end-users', t('shell.nav.endUsers'), 'project-end-users'),
        item('groups', t('shell.nav.groups'), 'project-groups'),
        item('attributes', t('shell.nav.attributes'), 'project-attributes'),
      ],
    },
    {
      key: 'authentication',
      label: t('shell.nav.authentication'),
      items: [
        item('authentication', t('shell.nav.authenticationSettings'), 'project-authentication'),
        item('identity-providers', t('shell.nav.identityProviders'), 'project-identity-providers'),
      ],
    },
    {
      key: 'monitoring',
      label: t('shell.nav.monitoring'),
      items: [
        item('test-sign-in', t('shell.nav.testSignIn'), 'project-test-sign-in'),
        ...(canReadAuditLog ? [item('audit-log', t('shell.nav.auditLog'), 'project-audit-log')] : []),
      ],
    },
    {
      key: 'settings',
      label: t('shell.nav.projectSettings'),
      items: [
        item('settings', t('shell.nav.general'), 'project-settings'),
        item('domain', t('shell.nav.customDomain'), 'project-domain'),
        item('members', t('shell.nav.members'), 'project-members'),
      ],
    },
  ]
})

const accountNavigation = computed<NavItem[]>(() => [
  { key: 'account-projects', label: t('shell.nav.projects'), to: { name: 'projects' } },
  ...(isAccountAdmin.value
    ? [
        { key: 'account-users', label: t('shell.nav.consoleUsers'), to: { name: 'users' } },
        { key: 'account-authentication', label: t('shell.nav.consoleSignIn'), to: { name: 'auth-settings' } },
        { key: 'account-audit-log', label: t('shell.nav.auditLog'), to: { name: 'audit-log' } },
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
        <p class="text-xs text-text-muted">{{ t('shell.account') }}</p>
        <p class="truncate text-sm font-semibold" :title="me?.account.name">{{ me?.account.name }}</p>
      </div>
      <nav :aria-label="t('shell.account')">
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
        <span aria-hidden="true">←</span> {{ t('shell.backTo', { name: returnProject.name }) }}
      </RouterLink>
    </template>

    <template v-else>
      <ProjectSwitcher :current-project-uid="currentProjectUid" />

      <nav v-if="projectNavigation.length > 0" :aria-label="t('shell.project')">
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

      <RouterLink :to="{ name: 'projects' }" :class="quietLinkClass" class="mt-auto border-t border-border pt-4">{{ t('shell.accountSettings') }}</RouterLink>
    </template>
  </div>
</template>
