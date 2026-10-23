<script setup lang="ts">
import { computed, provide, ref, watch, type Ref } from 'vue'
import { RouterView, useRoute } from 'vue-router'

import BaseAlert from '@/components/base/BaseAlert.vue'
import PageBreadcrumbs from '@/components/console/PageBreadcrumbs.vue'
import PageHeader from '@/components/console/PageHeader.vue'
import RouteTabs, { type RouteTab } from '@/components/console/RouteTabs.vue'
import StatusBadge from '@/components/console/StatusBadge.vue'
import { APP_CLIENT_KEY, APPLICATION_KEY } from '@/composables/useApplicationContext'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useProjectContext } from '@/composables/useProjectContext'
import { projectAdminService } from '@/services/project'
import type { AppClient } from '@/types/api'

const route = useRoute()
const { accountUid, project } = useProjectContext()
const client = ref<AppClient | null>(null)
const clientUid = computed(() => String(route.params.clientUid))

provide(APP_CLIENT_KEY, { record: client as Ref<AppClient>, replace: (updated) => (client.value = updated) })
provide(APPLICATION_KEY, computed(() => ({ kind: 'app_client' as const, uid: clientUid.value, name: client.value?.name ?? '' })))

const load = useAsyncAction(async () => {
  if (!project.value) return
  client.value = await projectAdminService.getAppClient(accountUid.value, project.value.uid, clientUid.value)
})

const tabs = computed<RouteTab[]>(() => {
  const params = { projectUid: project.value?.uid, clientUid: clientUid.value }
  return [
    ['Overview', 'project-app-client'],
    ['Sign-in', 'project-app-client-sign-in'],
    ['Access', 'project-app-client-access'],
    ['Tokens & claims', 'project-app-client-tokens'],
    ['Credentials', 'project-app-client-credentials'],
    ['Activity', 'project-app-client-activity'],
  ].map(([label, name]) => ({ label: label!, name: name!, to: { name: name!, params } }))
})

watch(clientUid, () => load.run(), { immediate: true })
</script>

<template>
  <PageBreadcrumbs
    :items="[
      { label: 'Applications', to: { name: 'project-applications', params: { projectUid: project?.uid } } },
      { label: client?.name ?? 'Application' },
    ]"
  />

  <BaseAlert v-if="load.error.value?.code === 'not_found'" variant="danger" title="Application not found">
    It may have been deleted.
  </BaseAlert>
  <BaseAlert v-else-if="load.error.value" variant="danger">{{ load.error.value.message }}</BaseAlert>
  <p v-else-if="!client" class="text-sm text-text-muted" role="status">Loading application…</p>

  <template v-if="client">
    <PageHeader :title="client.name" description="An OpenID Connect or API client: your own app, signing users in through hosted login, an OIDC library or the sign-in API.">
      <template #actions>
        <StatusBadge tone="info" label="OpenID Connect / API" />
        <StatusBadge tone="neutral" :label="client.client_type === 'public' ? 'Public client' : 'Confidential client'" />
        <StatusBadge :tone="client.enabled ? 'success' : 'neutral'" :label="client.enabled ? 'Enabled' : 'Disabled'" />
      </template>
    </PageHeader>
    <RouteTabs label="Application sections" :tabs="tabs" />
    <RouterView />
  </template>
</template>
