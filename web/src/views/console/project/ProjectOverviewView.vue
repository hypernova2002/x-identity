<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink } from 'vue-router'
import { storeToRefs } from 'pinia'

import AuditEventList from '@/components/audit/AuditEventList.vue'
import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import PageHeader from '@/components/console/PageHeader.vue'
import StatusBadge from '@/components/console/StatusBadge.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useProjectContext } from '@/composables/useProjectContext'
import { LOOKUP, type ListParams } from '@/services/list'
import { projectAdminService } from '@/services/project'
import { useSessionStore } from '@/stores/session'
import type { AppKind, IdentityProvider, ProjectDomain } from '@/types/api'

const { t } = useI18n()

interface AppSummary {
  kind: AppKind
  uid: string
  name: string
  /** Machine-to-machine apps have API access instead of assigned users. */
  machine: boolean
  /** Users and groups assigned, or for machine apps, APIs it may get tokens for. */
  assignments: number
}

const { accountUid, project, access } = useProjectContext()
const { account } = storeToRefs(useSessionStore())

const apps = ref<AppSummary[]>([])
const endUserCount = ref(0)
const providers = ref<IdentityProvider[]>([])
const domains = ref<ProjectDomain[]>([])
const signIns = ref<number | null>(null)
const failuresToday = ref<number | null>(null)
const refusalsToday = ref<number | null>(null)

const params = computed(() => ({ projectUid: project.value?.uid }))
const portalUrl = computed(() => (project.value && account.value ? `${window.location.origin}/auth/${account.value.slug}/${project.value.uid}/apps` : ''))

const tasks = [
  { label: t('project.projectOverview.connectAnApplication'), detail: t('project.projectOverview.addAnOpenidConnectApi'), to: 'project-applications' },
  { label: t('project.projectOverview.manageEndUsers'), detail: t('project.projectOverview.findInviteAndManageThe'), to: 'project-end-users' },
  { label: t('project.projectOverview.configureIdentityProviders'), detail: t('project.projectOverview.letUsersSignInWith'), to: 'project-identity-providers' },
  { label: t('project.projectOverview.reviewAuthenticationPolicies'), detail: t('project.projectOverview.mfaPasswordsLockoutsTokensAnd'), to: 'project-authentication' },
  { label: t('project.projectOverview.testASignIn'), detail: t('project.projectOverview.signAnEndUserIn'), to: 'project-test-sign-in' },
]

const anyAssigned = computed(() => apps.value.some((app) => !app.machine && app.assignments > 0))

const checklist = computed(() => [
  {
    label: t('project.projectOverview.addAnApplication'),
    done: apps.value.length > 0,
    detail: apps.value.length > 0 ? t('project.projectOverview.applicationS', { valueLength: apps.value.length }) : t('project.projectOverview.noApplicationsYet'),
    to: 'project-applications',
  },
  {
    label: t('project.projectOverview.giveUsersAccessToAn'),
    done: anyAssigned.value,
    detail: anyAssigned.value ? t('project.projectOverview.atLeastOneApplicationIs') : t('project.projectOverview.assignmentOnly'),
    to: 'project-applications',
  },
  {
    label: t('project.projectOverview.haveEndUsers'),
    done: endUserCount.value > 0,
    detail: endUserCount.value > 0 ? t('project.projectOverview.endUserS', { endUserCountValue: endUserCount.value }) : project.value?.allow_self_sign_up ? t('project.projectOverview.noneYetSelfSignUp') : t('project.projectOverview.noneYetCreateOrInvite'),
    to: 'project-end-users',
  },
  ...(signIns.value === null
    ? []
    : [
        {
          label: t('project.projectOverview.completeASignIn'),
          done: signIns.value > 0,
          detail: signIns.value > 0 ? t('project.projectOverview.successfulSignInSRecorded', { signInsValue: signIns.value }) : t('project.projectOverview.tryOneWithTestSign'),
          to: 'project-test-sign-in',
        },
      ]),
])

const unassignedApps = computed(() => apps.value.filter((app) => !app.machine && app.assignments === 0))
const machineAppsWithoutApis = computed(() => apps.value.filter((app) => app.machine && app.assignments === 0))
const verifiedDomain = computed(() => domains.value.find((domain) => domain.status === 'verified') ?? null)

/** Domain problems, and SAML connections still on the standard URLs once a custom domain is in use. */
const domainAttention = computed(() => {
  const projectUid = project.value?.uid ?? ''
  const domainPage = { name: 'project-domain', params: { projectUid } }
  const items = domains.value.flatMap((domain) => {
    if (domain.status === 'pending') return [{ key: domain.uid, text: t('project.projectOverview.isWaitingForItsDns', { hostname: domain.hostname }), action: t('project.projectOverview.setUp'), to: domainPage }]
    if (domain.status === 'failed') return [{ key: domain.uid, text: t('project.projectOverview.failedVerification', { hostname: domain.hostname }), action: t('project.projectOverview.fix'), to: domainPage }]
    if (domain.dns_missing_since) return [{ key: domain.uid, text: t('project.projectOverview.sDnsRecordsAreMissing', { hostname: domain.hostname }), action: t('project.projectOverview.fix'), to: domainPage }]
    return []
  })
  const domain = verifiedDomain.value
  if (!domain) return items
  return [
    ...items,
    ...domain.saml_apps
      .filter((app) => !app.on_custom_domain)
      .map((app) => ({
        key: app.uid,
        text: t('project.projectOverview.stillUsesTheStandardUrls', { name: app.name, hostname: domain.hostname }),
        action: t('project.projectOverview.review'),
        to: { name: 'project-saml-app-credentials', params: { projectUid, samlAppUid: app.uid } },
      })),
    ...domain.saml_identity_providers
      .filter((provider) => !provider.on_custom_domain)
      .map((provider) => ({
        key: provider.uid,
        text: t('project.projectOverview.stillUsesTheStandardUrls2', { name: provider.name, hostname: domain.hostname }),
        action: t('project.projectOverview.review'),
        to: { name: 'project-identity-provider', params: { projectUid, providerUid: provider.uid } },
      })),
  ]
})

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
  const [applications, endUsers, loadedProviders, loadedDomains] = await Promise.all([
    projectAdminService.listApplications(accountUid.value, projectUid, LOOKUP),
    projectAdminService.listEndUsers(accountUid.value, projectUid, { perPage: 1 }),
    projectAdminService.listIdentityProviders(accountUid.value, projectUid),
    projectAdminService.listDomains(accountUid.value, projectUid),
  ])
  endUserCount.value = endUsers.total
  providers.value = loadedProviders.items
  domains.value = loadedDomains
  apps.value = applications.items.map((app) => ({
    kind: app.app_type,
    uid: app.uid,
    name: app.name,
    machine: app.machine,
    assignments: app.machine ? app.api_count : app.assignment_count,
  }))

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
    <PageHeader :title="$t('project.projectOverview.overview')" :description="$t('project.projectOverview.whereThisProjectStandsAnd')">
      <template #actions>
        <RouterLink :to="{ name: 'project-settings', params }" class="text-sm font-medium text-primary underline">{{ $t('project.projectOverview.projectSettings') }}</RouterLink>
      </template>
    </PageHeader>

    <BaseAlert v-if="load.error.value" variant="danger">{{ $t('project.projectOverview.loadFailed', { message: load.error.value.message }) }}</BaseAlert>

    <BaseCard :title="$t('project.projectOverview.projectSummary')">
      <dl class="grid gap-2 text-sm sm:grid-cols-[max-content_1fr] sm:gap-x-4">
        <dt class="font-medium">{{ $t('project.projectOverview.projectId') }}</dt>
        <dd class="font-mono text-xs break-all">{{ project.uid }}</dd>
        <dt class="font-medium">{{ $t('project.projectOverview.issuer') }}</dt>
        <dd class="font-mono text-xs break-all">{{ project.token_issuer }}</dd>
        <dt class="font-medium">{{ $t('project.projectOverview.openidConnectDiscovery') }}</dt>
        <dd class="font-mono text-xs break-all">{{ `${project.token_issuer}/.well-known/openid-configuration` }}</dd>
        <dt class="font-medium">{{ $t('project.projectOverview.appPortal') }}</dt>
        <dd class="font-mono text-xs break-all">
          <a :href="portalUrl" target="_blank" rel="noopener" class="text-primary underline">{{ portalUrl }}</a>
        </dd>
        <template v-if="verifiedDomain">
          <dt class="font-medium">{{ $t('project.projectOverview.customDomain') }}</dt>
          <dd class="font-mono text-xs break-all">{{ verifiedDomain.hostname }}</dd>
        </template>
        <dt class="font-medium">{{ $t('project.projectOverview.selfSignUp') }}</dt>
        <dd>{{ project.allow_self_sign_up ? $t('project.projectOverview.on') : $t('project.projectOverview.off') }}</dd>
      </dl>
    </BaseCard>

    <div class="grid gap-6 lg:grid-cols-2">
      <BaseCard :title="$t('project.projectOverview.setupChecklist')">
        <p v-if="load.loading.value" class="text-sm text-text-muted" role="status">{{ $t('project.projectOverview.checkingTheProject') }}</p>
        <ul v-else class="flex flex-col divide-y divide-border">
          <li v-for="item in checklist" :key="item.label" class="flex items-start justify-between gap-2 py-2 text-sm">
            <span class="flex flex-col">
              <RouterLink :to="{ name: item.to, params }" class="font-medium text-primary underline-offset-2 hover:underline">{{ item.label }}</RouterLink>
              <span class="text-xs text-text-muted">{{ item.detail }}</span>
            </span>
            <StatusBadge :tone="item.done ? 'success' : 'neutral'" :label="item.done ? $t('project.projectOverview.done') : $t('project.projectOverview.toDo')" />
          </li>
        </ul>
      </BaseCard>

      <BaseCard :title="$t('project.projectOverview.commonTasks')">
        <ul class="flex flex-col divide-y divide-border">
          <li v-for="task in tasks" :key="task.label" class="flex flex-col py-2 text-sm">
            <RouterLink :to="{ name: task.to, params }" class="font-medium text-primary underline-offset-2 hover:underline">{{ task.label }}</RouterLink>
            <span class="text-xs text-text-muted">{{ task.detail }}</span>
          </li>
        </ul>
      </BaseCard>
    </div>

    <BaseCard
      v-if="!load.loading.value && (unassignedApps.length > 0 || machineAppsWithoutApis.length > 0 || samlProvidersWithoutDomains.length > 0 || domainAttention.length > 0)"
      :title="$t('project.projectOverview.needsAttention')"
    >
      <ul class="flex flex-col divide-y divide-border">
        <li v-for="app in unassignedApps" :key="app.uid" class="flex flex-wrap items-center justify-between gap-2 py-2 text-sm">
          <i18n-t keypath="project.projectOverview.unassignedApp" tag="span">
            <template #name><strong>{{ app.name }}</strong></template>
          </i18n-t>
          <RouterLink :to="appAccessRoute(app)" class="font-medium text-primary underline">{{ $t('project.projectOverview.giveAccess') }}</RouterLink>
        </li>
        <li v-for="app in machineAppsWithoutApis" :key="app.uid" class="flex flex-wrap items-center justify-between gap-2 py-2 text-sm">
          <i18n-t keypath="project.projectOverview.machineAppWithoutApis" tag="span">
            <template #name><strong>{{ app.name }}</strong></template>
          </i18n-t>
          <RouterLink :to="{ name: 'project-app-client-api-access', params: { projectUid: project.uid, clientUid: app.uid } }" class="font-medium text-primary underline">
            {{ $t('project.projectOverview.giveApiAccess') }}
          </RouterLink>
        </li>
        <li v-for="item in domainAttention" :key="item.key" class="flex flex-wrap items-center justify-between gap-2 py-2 text-sm">
          <span>{{ item.text }}</span>
          <RouterLink :to="item.to" class="font-medium text-primary underline">{{ item.action }}</RouterLink>
        </li>
        <li v-for="provider in samlProvidersWithoutDomains" :key="provider.uid" class="flex flex-wrap items-center justify-between gap-2 py-2 text-sm">
          <i18n-t keypath="project.projectOverview.providerWithoutDomains" tag="span">
            <template #name><strong>{{ provider.name }}</strong></template>
          </i18n-t>
          <RouterLink :to="{ name: 'project-identity-provider', params: { projectUid: project.uid, providerUid: provider.uid } }" class="font-medium text-primary underline">
            {{ $t('project.projectOverview.review') }}
          </RouterLink>
        </li>
      </ul>
    </BaseCard>

    <BaseCard v-if="access.developer" :title="$t('project.projectOverview.activity')" :description="$t('project.projectOverview.fromTheProjectSAudit')">
      <dl v-if="failuresToday !== null" class="grid gap-4 sm:grid-cols-2">
        <div class="flex flex-col gap-1 rounded-md border border-border p-3">
          <dt class="text-sm text-text-muted">{{ $t('project.projectOverview.failedSignInsLastHours') }}</dt>
          <dd class="text-2xl font-semibold">{{ failuresToday }}</dd>
          <RouterLink :to="{ name: 'project-audit-log', params, query: { action_start: 'end_user.sign_in_failed' } }" class="text-xs font-medium text-primary underline">
            {{ $t('project.projectOverview.seeFailedSignIns') }}
          </RouterLink>
        </div>
        <div class="flex flex-col gap-1 rounded-md border border-border p-3">
          <dt class="text-sm text-text-muted">{{ $t('project.projectOverview.refusedForLackOfAccess') }}</dt>
          <dd class="text-2xl font-semibold">{{ refusalsToday }}</dd>
          <RouterLink :to="{ name: 'project-audit-log', params, query: { action_start: 'end_user.app_access_denied' } }" class="text-xs font-medium text-primary underline">
            {{ $t('project.projectOverview.seeRefusals') }}
          </RouterLink>
        </div>
      </dl>
      <h3 class="text-sm font-semibold">{{ $t('project.projectOverview.recentEvents') }}</h3>
      <AuditEventList :fetch-page="fetchAudit" :filters="{}" :empty-message="$t('project.projectOverview.nothingHasHappenedInThis')" :full-log="{ name: 'project-audit-log', params }" :limit="5" />
    </BaseCard>
  </template>
</template>
