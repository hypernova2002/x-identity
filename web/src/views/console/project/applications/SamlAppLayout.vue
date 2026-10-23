<script setup lang="ts">
import { computed, provide, ref, watch, type Ref } from 'vue'
import { RouterView, useRoute } from 'vue-router'

import BaseAlert from '@/components/base/BaseAlert.vue'
import PageBreadcrumbs from '@/components/console/PageBreadcrumbs.vue'
import PageHeader from '@/components/console/PageHeader.vue'
import RouteTabs, { type RouteTab } from '@/components/console/RouteTabs.vue'
import StatusBadge from '@/components/console/StatusBadge.vue'
import { APPLICATION_KEY, SAML_APP_KEY } from '@/composables/useApplicationContext'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useProjectContext } from '@/composables/useProjectContext'
import { projectAdminService } from '@/services/project'
import type { SamlApp } from '@/types/api'

const route = useRoute()
const { accountUid, project } = useProjectContext()
const app = ref<SamlApp | null>(null)
const appUid = computed(() => String(route.params.samlAppUid))

provide(SAML_APP_KEY, { record: app as Ref<SamlApp>, replace: (updated) => (app.value = updated) })
provide(APPLICATION_KEY, computed(() => ({ kind: 'saml_app' as const, uid: appUid.value, name: app.value?.name ?? '' })))

const load = useAsyncAction(async () => {
  if (!project.value) return
  app.value = await projectAdminService.getSamlApp(accountUid.value, project.value.uid, appUid.value)
})

const tabs = computed<RouteTab[]>(() => {
  const params = { projectUid: project.value?.uid, samlAppUid: appUid.value }
  return [
    ['Overview', 'project-saml-app'],
    ['Configuration', 'project-saml-app-configuration'],
    ['Access', 'project-saml-app-access'],
    ['Credentials', 'project-saml-app-credentials'],
    ['Activity', 'project-saml-app-activity'],
  ].map(([label, name]) => ({ label: label!, name: name!, to: { name: name!, params } }))
})

watch(appUid, () => load.run(), { immediate: true })
</script>

<template>
  <PageBreadcrumbs
    :items="[
      { label: 'Applications', to: { name: 'project-applications', params: { projectUid: project?.uid } } },
      { label: app?.name ?? 'SAML application' },
    ]"
  />

  <BaseAlert v-if="load.error.value?.code === 'not_found'" variant="danger" title="Application not found">It may have been deleted.</BaseAlert>
  <BaseAlert v-else-if="load.error.value" variant="danger">{{ load.error.value.message }}</BaseAlert>
  <p v-else-if="!app" class="text-sm text-text-muted" role="status">Loading application…</p>

  <template v-if="app">
    <PageHeader :title="app.name" description="A SAML application: it signs users in with SAML 2.0, using this project as the identity provider.">
      <template #actions>
        <StatusBadge tone="info" label="SAML" />
        <StatusBadge :tone="app.enabled ? 'success' : 'neutral'" :label="app.enabled ? 'Enabled' : 'Disabled'" />
      </template>
    </PageHeader>
    <RouteTabs label="Application sections" :tabs="tabs" />
    <RouterView />
  </template>
</template>
