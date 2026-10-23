<script setup lang="ts">
import { computed, watch } from 'vue'
import { RouterLink, RouterView, useRoute } from 'vue-router'
import { storeToRefs } from 'pinia'

import BaseAlert from '@/components/base/BaseAlert.vue'
import PageHeader from '@/components/console/PageHeader.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useProjectStore } from '@/stores/project'

const route = useRoute()
const projectStore = useProjectStore()
const { project } = storeToRefs(projectStore)

const projectUid = computed(() => String(route.params.projectUid))
const loaded = computed(() => project.value?.uid === projectUid.value)

const loading = useAsyncAction((uid: string) => projectStore.select(uid))

watch(projectUid, (uid) => loading.run(uid), { immediate: true })
</script>

<template>
  <BaseAlert v-if="loading.error.value?.code === 'not_found'" variant="danger" title="Project not found">
    It may have been deleted, or you don't have access to it.
    <RouterLink :to="{ name: 'projects' }" class="font-medium text-primary underline">See all projects</RouterLink>
  </BaseAlert>
  <BaseAlert v-else-if="loading.error.value" variant="danger">{{ loading.error.value.message }}</BaseAlert>
  <p v-else-if="!loaded" class="text-sm text-text-muted" role="status">Loading project…</p>

  <template v-if="loaded && project">
    <PageHeader v-if="!route.meta.ownHeader" :title="route.meta.title ?? project.name" :description="route.meta.description" />
    <RouterView :key="project.uid" />
  </template>
</template>
