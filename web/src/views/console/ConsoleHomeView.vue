<script setup lang="ts">
import { onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { storeToRefs } from 'pinia'

import BaseAlert from '@/components/base/BaseAlert.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useProjectStore } from '@/stores/project'
import { useSessionStore } from '@/stores/session'

const router = useRouter()
const projectStore = useProjectStore()
const { projectsLoaded } = storeToRefs(projectStore)
const { isAccountAdmin } = storeToRefs(useSessionStore())

/** Opens the last project used, or the first; with none, admins create one and members see the list. */
const open = useAsyncAction(async () => {
  if (!projectsLoaded.value) await projectStore.loadProjects()

  const projectUid = projectStore.defaultProjectUid()
  if (projectUid) await router.replace({ name: 'project', params: { projectUid } })
  else await router.replace({ name: isAccountAdmin.value ? 'welcome' : 'projects' })
})

onMounted(() => open.run())
</script>

<template>
  <BaseAlert v-if="open.error.value" variant="danger">{{ $t('console.home.loadFailed', { message: open.error.value.message }) }}</BaseAlert>
  <p v-else class="text-sm text-text-muted" role="status">{{ $t('console.home.opening') }}</p>
</template>
