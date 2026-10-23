<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { storeToRefs } from 'pinia'

import BaseActionMenu, { type ActionMenuItem } from '@/components/base/BaseActionMenu.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import CreateProjectDialog from '@/components/console/CreateProjectDialog.vue'
import { useProjectStore } from '@/stores/project'
import { useSessionStore } from '@/stores/session'

const props = defineProps<{
  currentProjectUid: string | null
}>()

const route = useRoute()
const router = useRouter()
const { projects, projectsLoaded } = storeToRefs(useProjectStore())
const { isAccountAdmin } = storeToRefs(useSessionStore())

const createOpen = ref(false)

const current = computed(() => projects.value.find((project) => project.uid === props.currentProjectUid) ?? null)

/** Switching keeps you on the same section, e.g. End users, in the other project. */
function switchTo(projectUid: string) {
  const onProjectPage = typeof route.name === 'string' && route.params.projectUid !== undefined
  router.push({ name: onProjectPage ? (route.name as string) : 'project', params: { projectUid } })
}

const items = computed<ActionMenuItem[]>(() => [
  ...projects.value.map((project) => ({ label: project.name, current: project.uid === props.currentProjectUid, action: () => switchTo(project.uid) })),
  { label: 'All projects', separatorBefore: true, action: () => router.push({ name: 'projects' }) },
  ...(isAccountAdmin.value ? [{ label: 'Create project', action: () => (createOpen.value = true) }] : []),
])
</script>

<template>
  <div class="flex flex-col gap-1">
    <BaseActionMenu v-if="projects.length > 0" :items="items" label="Switch project">
      <template #trigger="{ toggle }">
        <button
          type="button"
          aria-haspopup="menu"
          :aria-label="`Project: ${current?.name ?? 'none selected'}. Switch project`"
          class="flex w-full min-w-0 items-center gap-2 rounded-md border border-border bg-bg px-3 py-2 text-left hover:bg-bg-subtle focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary active:bg-border"
          @click="toggle"
        >
          <span class="flex min-w-0 flex-1 flex-col">
            <span class="text-xs text-text-muted">Project</span>
            <span class="truncate text-sm font-semibold" :title="current?.name">{{ current?.name ?? 'Choose a project' }}</span>
          </span>
          <span aria-hidden="true" class="text-text-muted">⌄</span>
        </button>
      </template>
    </BaseActionMenu>
    <template v-else-if="projectsLoaded">
      <p class="text-sm text-text-muted">No projects yet.</p>
      <BaseButton v-if="isAccountAdmin" label="Create project" size="sm" class="self-start" @click="createOpen = true" />
    </template>

    <CreateProjectDialog v-model:visible="createOpen" />
  </div>
</template>
