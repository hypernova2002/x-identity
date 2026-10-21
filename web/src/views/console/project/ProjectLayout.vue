<script setup lang="ts">
import { computed, watch } from 'vue'
import { RouterLink, RouterView, useRoute } from 'vue-router'

import BaseAlert from '@/components/base/BaseAlert.vue'
import PageHeader from '@/components/console/PageHeader.vue'
import { provideProjectContext } from '@/composables/useProjectContext'
import { useAsyncAction } from '@/composables/useAsyncAction'

const route = useRoute()
const { project, access, load } = provideProjectContext()

const projectUid = computed(() => String(route.params.projectUid))

const tabs = computed(() =>
  [
    { name: 'project', label: 'Overview', visible: true },
    { name: 'project-members', label: 'Members', visible: true },
    { name: 'project-app-clients', label: 'App clients', visible: true },
    { name: 'project-end-users', label: 'End users', visible: true },
    { name: 'project-attributes', label: 'Attributes', visible: true },
    { name: 'project-authentication', label: 'Authentication', visible: true },
    { name: 'project-audit-log', label: 'Audit log', visible: access.value.developer },
  ].filter((tab) => tab.visible),
)

const loading = useAsyncAction((uid: string) => load(uid))

watch(projectUid, (uid) => loading.run(uid), { immediate: true })
</script>

<template>
  <p v-if="loading.loading.value && !project" class="text-sm text-text-muted" role="status">Loading project…</p>

  <BaseAlert v-else-if="loading.error.value?.code === 'not_found'" variant="danger" title="Project not found">
    It may have been deleted, or you don't have access to it.
    <RouterLink :to="{ name: 'projects' }" class="font-medium text-primary underline">Back to projects</RouterLink>
  </BaseAlert>
  <BaseAlert v-else-if="loading.error.value" variant="danger">{{ loading.error.value.message }}</BaseAlert>

  <template v-if="project">
    <PageHeader :title="project.name" :description="`Project ${project.uid}`" />

    <nav aria-label="Project sections" class="-mt-4 overflow-x-auto border-b border-border">
      <ul class="flex gap-1">
        <li v-for="tab in tabs" :key="tab.name">
          <RouterLink
            :to="{ name: tab.name, params: { projectUid } }"
            class="block border-b-2 border-transparent px-3 py-2 text-sm whitespace-nowrap text-text-muted hover:text-text focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary aria-[current=page]:border-primary aria-[current=page]:font-semibold aria-[current=page]:text-primary-active"
          >
            {{ tab.label }}
          </RouterLink>
        </li>
      </ul>
    </nav>

    <RouterView />
  </template>
</template>
