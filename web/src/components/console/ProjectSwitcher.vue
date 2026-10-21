<script setup lang="ts">
import { computed } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import { storeToRefs } from 'pinia'

import BaseSelect from '@/components/base/BaseSelect.vue'
import { useProjectStore } from '@/stores/project'
import { useSessionStore } from '@/stores/session'

defineProps<{
  currentProjectUid: string | null
}>()

const route = useRoute()
const router = useRouter()
const { projects } = storeToRefs(useProjectStore())
const { isAccountAdmin } = storeToRefs(useSessionStore())

const options = computed(() => projects.value.map((project) => ({ label: project.name, value: project.uid })))

/** Switching keeps you on the same section, e.g. End users, in the other project. */
function switchTo(projectUid: string) {
  const onProjectPage = typeof route.name === 'string' && route.params.projectUid !== undefined
  router.push({ name: onProjectPage ? (route.name as string) : 'project', params: { projectUid } })
}
</script>

<template>
  <div class="flex flex-col gap-2">
    <BaseSelect
      v-if="options.length > 0"
      :model-value="currentProjectUid ?? ''"
      label="Project"
      :options="options"
      @update:model-value="switchTo"
    />
    <p v-else class="text-sm text-text-muted">No projects yet.</p>
    <RouterLink
      v-if="isAccountAdmin"
      :to="{ name: 'projects', query: { create: '1' } }"
      class="w-fit rounded-sm text-sm font-medium text-primary underline hover:text-primary-hover focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
    >
      New project
    </RouterLink>
  </div>
</template>
