<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import { storeToRefs } from 'pinia'

import AuditEventList from '@/components/audit/AuditEventList.vue'
import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import PageHeader from '@/components/console/PageHeader.vue'
import StatusBadge from '@/components/console/StatusBadge.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useProjectContext } from '@/composables/useProjectContext'
import type { ListParams } from '@/services/list'
import { projectAdminService } from '@/services/project'
import { useSessionStore } from '@/stores/session'
import type { AppKind, IdentityProvider } from '@/types/api'

interface AppSummary {
  kind: AppKind
  uid: string
  name: string
  assignments: number
}

const { accountUid, project, access } = useProjectContext()
const { account } = storeToRefs(useSessionStore())

const apps = ref<AppSummary[]>([])
const endUserCount = ref(0)
const providers = ref<IdentityProvider[]>([])
const signIns = ref<number | null>(null)
const failuresToday = ref<number | null>(null)
const refusalsToday = ref<number | null>(null)

const params = computed(() => ({ projectUid: project.value?.uid }))
const portalUrl = computed(() => (project.value && account.value ? `${window.location.origin}/auth/${account.value.slug}/${project.value.uid}/apps` : ''))

const tasks = [
  { label: 'Connect an application', detail: 'Add an OpenID Connect, API or SAML application and give users access.', to: 'project-applications' },
  { label: 'Manage end users', detail: 'Find, invite and manage the people who sign in.', to: 'project-end-users' },
  { label: 'Configure identity providers', detail: 'Let users sign in with Google, Apple, OpenID Connect or their company.', to: 'project-identity-providers' },
  { label: 'Review authentication policies', detail: 'MFA, passwords, lockouts, tokens and sessions.', to: 'project-authentication' },
  { label: 'Test a sign-in', detail: 'Sign an end user in and inspect the tokens.', to: 'project-test-sign-in' },
]

const anyAssigned = computed(() => apps.value.some((app) => app.assignments > 0))

const checklist = computed(() => [
  {
    label: 'Add an application',
    done: apps.value.length > 0,
    detail: apps.value.length > 0 ? `${apps.value.length} application(s).` : 'No applications yet.',
    to: 'project-applications',
  },
  {
    label: 'Give users access to an application',
    done: anyAssigned.value,
    detail: anyAssigned.value ? 'At least one application is assigned.' : "Applications are assignment-only; nobody can sign in until one is assigned.",
    to: 'project-applications',
  },
  {
    label: 'Have end users',
    done: endUserCount.value > 0,
    detail: endUserCount.value > 0 ? `${endUserCount.value} end user(s).` : project.value?.allow_self_sign_up ? 'None yet; self sign-up is on.' : 'None yet; create or invite them.',
    to: 'project-end-users',
  },
  ...(signIns.value === null
    ? []
    : [
        {
          label: 'Complete a sign-in',
          done: signIns.value > 0,
          detail: signIns.value > 0 ? `${signIns.value} successful sign-in(s) recorded.` : 'Try one with Test sign-in.',
          to: 'project-test-sign-in',
        },
      ]),
])

const unassignedApps = computed(() => apps.value.filter((app) => app.assignments === 0))
const samlProvidersWithoutDomains = computed(() => providers.value.filter((provider) => provider.kind === 'saml' && provider.enabled && provider.domains.length === 0))

const appAccessRoute = (app: AppSummary) =>
  app.kind === 'saml_app'
    ? { name: 'project-saml-app-access', params: { projectUid: project.value?.uid, samlAppUid: app.uid } }
    : { name: 'project-app-client-access', params: { projectUid: project.value?.uid, clientUid: app.uid } }

function fetchAudit(params: ListParams) {
  return projectAdminService.listAuditEvents(accountUid.value, project.value!.uid, params)
}

const countEvents = async (filters: Record<string, string>) => (await fetchAudit({ perPage: 1, filters })).total

const load = useAsyncAction(async () => {
  if (!project.value) return
  const projectUid = project.value.uid
  const [clients, samlApps, endUsers, loadedProviders] = await Promise.all([
    projectAdminService.listAppClients(accountUid.value, projectUid),
    projectAdminService.listSamlApps(accountUid.value, projectUid),
    projectAdminService.listEndUsers(accountUid.value, projectUid, { perPage: 1 }),
    projectAdminService.listIdentityProviders(accountUid.value, projectUid),
  ])
  endUserCount.value = endUsers.total
  providers.value = loadedProviders.items

  const summaries = [
    ...clients.items.map((client) => ({ kind: 'app_client' as const, uid: client.uid, name: client.name })),
    ...samlApps.items.map((app) => ({ kind: 'saml_app' as const, uid: app.uid, name: app.name })),
  ]
  apps.value = await Promise.all(
    summaries.map(async (app) => ({ ...app, assignments: (await projectAdminService.listAssignments(accountUid.value, projectUid, app.kind, app.uid)).total })),
  )

  if (access.value.developer) {
    const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()
    ;[signIns.value, failuresToday.value, refusalsToday.value] = await Promise.all([
      countEvents({ action_eq: 'end_user.signed_in' }),
      countEvents({ action_eq: 'end_user.sign_in_failed', occurred_at_gteq: since }),
      countEvents({ action_eq: 'end_user.app_access_denied', occurred_at_gteq: since }),
    ])
  }
})

onMounted(() => load.run())
</script>

<template>
  <template v-if="project">
    <PageHeader title="Overview" description="Where this project stands, and what to do next.">
      <template #actions>
        <RouterLink :to="{ name: 'project-settings', params }" class="text-sm font-medium text-primary underline">Project settings</RouterLink>
      </template>
    </PageHeader>

    <BaseAlert v-if="load.error.value" variant="danger">We couldn't load the overview. {{ load.error.value.message }}</BaseAlert>

    <BaseCard title="Project summary">
      <dl class="grid gap-2 text-sm sm:grid-cols-[max-content_1fr] sm:gap-x-4">
        <dt class="font-medium">Project ID</dt>
        <dd class="font-mono text-xs break-all">{{ project.uid }}</dd>
        <dt class="font-medium">Issuer</dt>
        <dd class="font-mono text-xs break-all">{{ project.token_issuer }}</dd>
        <dt class="font-medium">OpenID Connect discovery</dt>
        <dd class="font-mono text-xs break-all">{{ project.token_issuer }}/.well-known/openid-configuration</dd>
        <dt class="font-medium">App portal</dt>
        <dd class="font-mono text-xs break-all">
          <a :href="portalUrl" target="_blank" rel="noopener" class="text-primary underline">{{ portalUrl }}</a>
        </dd>
        <dt class="font-medium">Self sign-up</dt>
        <dd>{{ project.allow_self_sign_up ? 'On' : 'Off' }}</dd>
      </dl>
    </BaseCard>

    <div class="grid gap-6 lg:grid-cols-2">
      <BaseCard title="Setup checklist">
        <p v-if="load.loading.value" class="text-sm text-text-muted" role="status">Checking the project…</p>
        <ul v-else class="flex flex-col divide-y divide-border">
          <li v-for="item in checklist" :key="item.label" class="flex items-start justify-between gap-2 py-2 text-sm">
            <span class="flex flex-col">
              <RouterLink :to="{ name: item.to, params }" class="font-medium text-primary underline-offset-2 hover:underline">{{ item.label }}</RouterLink>
              <span class="text-xs text-text-muted">{{ item.detail }}</span>
            </span>
            <StatusBadge :tone="item.done ? 'success' : 'neutral'" :label="item.done ? 'Done' : 'To do'" />
          </li>
        </ul>
      </BaseCard>

      <BaseCard title="Common tasks">
        <ul class="flex flex-col divide-y divide-border">
          <li v-for="task in tasks" :key="task.label" class="flex flex-col py-2 text-sm">
            <RouterLink :to="{ name: task.to, params }" class="font-medium text-primary underline-offset-2 hover:underline">{{ task.label }}</RouterLink>
            <span class="text-xs text-text-muted">{{ task.detail }}</span>
          </li>
        </ul>
      </BaseCard>
    </div>

    <BaseCard v-if="!load.loading.value && (unassignedApps.length > 0 || samlProvidersWithoutDomains.length > 0)" title="Needs attention">
      <ul class="flex flex-col divide-y divide-border">
        <li v-for="app in unassignedApps" :key="app.uid" class="flex flex-wrap items-center justify-between gap-2 py-2 text-sm">
          <span><strong>{{ app.name }}</strong> isn't assigned to anyone, so nobody can sign in to it.</span>
          <RouterLink :to="appAccessRoute(app)" class="font-medium text-primary underline">Give access</RouterLink>
        </li>
        <li v-for="provider in samlProvidersWithoutDomains" :key="provider.uid" class="flex flex-wrap items-center justify-between gap-2 py-2 text-sm">
          <span><strong>{{ provider.name }}</strong> has no email domains, so sign-ins through it are refused.</span>
          <RouterLink :to="{ name: 'project-identity-provider', params: { projectUid: project.uid, providerUid: provider.uid } }" class="font-medium text-primary underline">
            Review
          </RouterLink>
        </li>
      </ul>
    </BaseCard>

    <BaseCard v-if="access.developer" title="Activity" description="From the project's audit log.">
      <dl v-if="failuresToday !== null" class="grid gap-4 sm:grid-cols-2">
        <div class="flex flex-col gap-1 rounded-md border border-border p-3">
          <dt class="text-sm text-text-muted">Failed sign-ins, last 24 hours</dt>
          <dd class="text-2xl font-semibold">{{ failuresToday }}</dd>
          <RouterLink :to="{ name: 'project-audit-log', params, query: { action_start: 'end_user.sign_in_failed' } }" class="text-xs font-medium text-primary underline">
            See failed sign-ins
          </RouterLink>
        </div>
        <div class="flex flex-col gap-1 rounded-md border border-border p-3">
          <dt class="text-sm text-text-muted">Refused for lack of access, last 24 hours</dt>
          <dd class="text-2xl font-semibold">{{ refusalsToday }}</dd>
          <RouterLink :to="{ name: 'project-audit-log', params, query: { action_start: 'end_user.app_access_denied' } }" class="text-xs font-medium text-primary underline">
            See refusals
          </RouterLink>
        </div>
      </dl>
      <h3 class="text-sm font-semibold">Recent events</h3>
      <AuditEventList :fetch-page="fetchAudit" :filters="{}" empty-message="Nothing has happened in this project yet." :full-log="{ name: 'project-audit-log', params }" :limit="5" />
    </BaseCard>
  </template>
</template>
