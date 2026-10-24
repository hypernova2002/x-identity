<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { storeToRefs } from 'pinia'

import BaseActionMenu, { type ActionMenuItem } from '@/components/base/BaseActionMenu.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import CreateProjectDialog from '@/components/console/CreateProjectDialog.vue'
import { useDebounce } from '@/composables/useDebounce'
import { projectService } from '@/services/account'
import { LOOKUP_SIZE } from '@/services/list'
import { useProjectStore } from '@/stores/project'
import { useSessionStore } from '@/stores/session'
import type { Project } from '@/types/api'

const props = defineProps<{
  currentProjectUid: string | null
}>()

const route = useRoute()
const router = useRouter()
const { projects, project, projectsLoaded, accountUid } = storeToRefs(useProjectStore())
const { isAccountAdmin } = storeToRefs(useSessionStore())

const createOpen = ref(false)
const term = ref('')
/** Search results, or null to show the first projects the store loaded. */
const matches = ref<{ items: Project[]; total: number } | null>(null)

const search = useDebounce(async (value: string) => {
  const page = await projectService.list(accountUid.value, { search: value, perPage: LOOKUP_SIZE }).catch(() => ({ items: [], total: 0 }))
  if (term.value.trim() === value) matches.value = page
}, 300)

watch(term, (value) => {
  if (value.trim()) search.run(value.trim())
  else {
    search.cancel()
    matches.value = null
  }
})

const shown = computed(() => matches.value?.items ?? projects.value.slice(0, LOOKUP_SIZE))

const current = computed(
  () =>
    projects.value.find((candidate) => candidate.uid === props.currentProjectUid) ??
    (project.value?.uid === props.currentProjectUid ? project.value : null),
)

/** Switching keeps you on the same section, e.g. End users, in the other project. */
function switchTo(projectUid: string) {
  const onProjectPage = typeof route.name === 'string' && route.params.projectUid !== undefined
  router.push({ name: onProjectPage ? (route.name as string) : 'project', params: { projectUid } })
}

const items = computed<ActionMenuItem[]>(() => [
  ...shown.value.map((shownProject) => ({
    label: shownProject.name,
    current: shownProject.uid === props.currentProjectUid,
    action: () => switchTo(shownProject.uid),
  })),
  ...(shown.value.length === 0 ? [{ label: 'No projects match', disabled: true, action: () => undefined }] : []),
  {
    label: matches.value && matches.value.total > shown.value.length ? `All projects (${matches.value.total} match)` : 'All projects',
    separatorBefore: true,
    action: () => router.push({ name: 'projects', query: term.value.trim() ? { search: term.value.trim() } : {} }),
  },
  ...(isAccountAdmin.value ? [{ label: 'Create project', action: () => (createOpen.value = true) }] : []),
])
</script>

<template>
  <div class="flex flex-col gap-1">
    <BaseActionMenu v-if="projects.length > 0" :items="items" label="Switch project">
      <template #start>
        <BaseInput v-model="term" label="Find a project" type="search" />
      </template>
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
