<script setup lang="ts">
import { computed, provide, ref, watch, type Ref } from 'vue'
import { useI18n } from 'vue-i18n'
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

const { t } = useI18n()

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
    [t('project.samlApp.overview'), 'project-saml-app'],
    [t('project.samlApp.configuration'), 'project-saml-app-configuration'],
    [t('project.samlApp.access'), 'project-saml-app-access'],
    [t('project.samlApp.credentials'), 'project-saml-app-credentials'],
    [t('project.samlApp.activity'), 'project-saml-app-activity'],
  ].map(([label, name]) => ({ label: label!, name: name!, to: { name: name!, params } }))
})

watch(appUid, () => load.run(), { immediate: true })
</script>

<template>
  <PageBreadcrumbs
    :items="[
      { label: $t('project.samlApp.applications'), to: { name: 'project-applications', params: { projectUid: project?.uid } } },
      { label: app?.name ?? $t('project.samlApp.samlApplication') },
    ]"
  />

  <BaseAlert v-if="load.error.value?.code === 'not_found'" variant="danger" :title="$t('project.samlApp.applicationNotFound')">{{ $t('project.samlApp.itMayHaveBeenDeleted') }}</BaseAlert>
  <BaseAlert v-else-if="load.error.value" variant="danger">{{ load.error.value.message }}</BaseAlert>
  <p v-else-if="!app" class="text-sm text-text-muted" role="status">{{ $t('project.samlApp.loadingApplication') }}</p>

  <template v-if="app">
    <PageHeader :title="app.name" :description="$t('project.samlApp.aSamlApplicationItSigns')">
      <template #actions>
        <StatusBadge tone="info" :label="$t('project.samlApp.saml')" />
        <StatusBadge :tone="app.enabled ? 'success' : 'neutral'" :label="app.enabled ? $t('project.samlApp.enabled') : $t('project.samlApp.disabled')" />
      </template>
    </PageHeader>
    <RouteTabs :label="$t('project.samlApp.applicationSections')" :tabs="tabs" />
    <RouterView />
  </template>
</template>
