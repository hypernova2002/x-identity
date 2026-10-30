<script setup lang="ts">
import { computed, provide, ref, watch, type Ref } from 'vue'
import { useI18n } from 'vue-i18n'
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

const { t } = useI18n()

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
  const shown = client.value?.machine
    ? [
        [t('project.appClient.overview'), 'project-app-client'],
        [t('project.appClient.credentials'), 'project-app-client-credentials'],
        [t('project.appClient.apiAccess'), 'project-app-client-api-access'],
        [t('project.appClient.activity'), 'project-app-client-activity'],
      ]
    : [
        [t('project.appClient.overview'), 'project-app-client'],
        [t('project.appClient.signIn'), 'project-app-client-sign-in'],
        [t('project.appClient.access'), 'project-app-client-access'],
        [t('project.appClient.tokensClaims'), 'project-app-client-tokens'],
        [t('project.appClient.credentials'), 'project-app-client-credentials'],
        [t('project.appClient.activity'), 'project-app-client-activity'],
      ]
  return shown.map(([label, name]) => ({ label: label!, name: name!, to: { name: name!, params } }))
})

watch(clientUid, () => load.run(), { immediate: true })
</script>

<template>
  <PageBreadcrumbs
    :items="[
      { label: $t('project.appClient.applications'), to: { name: 'project-applications', params: { projectUid: project?.uid } } },
      { label: client?.name ?? $t('project.appClient.application') },
    ]"
  />

  <BaseAlert v-if="load.error.value?.code === 'not_found'" variant="danger" :title="$t('project.appClient.applicationNotFound')">
    {{ $t('project.appClient.itMayHaveBeenDeleted') }}
  </BaseAlert>
  <BaseAlert v-else-if="load.error.value" variant="danger">{{ load.error.value.message }}</BaseAlert>
  <p v-else-if="!client" class="text-sm text-text-muted" role="status">{{ $t('project.appClient.loadingApplication') }}</p>

  <template v-if="client">
    <PageHeader
      :title="client.name"
      :description="
        client.machine
          ? $t('project.appClient.aMachineToMachineApp')
          : $t('project.appClient.anOpenidConnectOrApi')
      "
    >
      <template #actions>
        <StatusBadge v-if="client.machine" tone="info" :label="$t('project.appClient.machineToMachine')" />
        <StatusBadge v-else tone="info" :label="$t('project.appClient.openidConnectApi')" />
        <StatusBadge v-if="!client.machine" tone="neutral" :label="client.client_type === 'public' ? $t('project.appClient.publicClient') : $t('project.appClient.confidentialClient')" />
        <StatusBadge :tone="client.enabled ? 'success' : 'neutral'" :label="client.enabled ? $t('project.appClient.enabled') : $t('project.appClient.disabled')" />
      </template>
    </PageHeader>
    <RouteTabs :label="$t('project.appClient.applicationSections')" :tabs="tabs" />
    <RouterView />
  </template>
</template>
