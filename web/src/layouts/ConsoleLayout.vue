<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { RouterLink, RouterView, useRoute } from 'vue-router'
import { storeToRefs } from 'pinia'

import BaseDrawer from '@/components/base/BaseDrawer.vue'
import ConsoleSidebar from '@/components/console/ConsoleSidebar.vue'
import UserMenu from '@/components/console/UserMenu.vue'
import { useProjectStore } from '@/stores/project'
import { useSessionStore } from '@/stores/session'

const route = useRoute()
const projectStore = useProjectStore()
const { me } = storeToRefs(useSessionStore())
const { project, projectsLoaded } = storeToRefs(projectStore)

const navigationOpen = ref(false)

/** The project in the URL, or else the one the sidebar offers to open. */
const currentProjectUid = computed(() => {
  const fromRoute = route.params.projectUid
  if (typeof fromRoute === 'string') return fromRoute
  return project.value?.uid ?? (projectsLoaded.value ? projectStore.defaultProjectUid() : null)
})

const inAccount = computed(() => route.meta.context === 'account')

watch(
  () => route.fullPath,
  () => (navigationOpen.value = false),
)

onMounted(() => {
  if (!projectsLoaded.value) projectStore.loadProjects().catch(() => null)
})
</script>

<template>
  <div class="flex h-dvh flex-col">
    <a
      href="#main"
      class="sr-only rounded-md bg-bg px-3 py-2 text-sm font-medium text-primary focus:not-sr-only focus:absolute focus:top-2 focus:left-2 focus:z-50 focus:outline-2 focus:outline-primary"
    >
      Skip to content
    </a>

    <header class="flex h-14 shrink-0 items-center gap-3 border-b border-border bg-bg px-4">
      <button
        type="button"
        class="inline-flex size-10 items-center justify-center rounded-md text-text hover:bg-bg-subtle focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary active:bg-border md:hidden"
        aria-label="Open navigation"
        :aria-expanded="navigationOpen"
        @click="navigationOpen = true"
      >
        <svg aria-hidden="true" viewBox="0 0 20 20" class="size-5" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round">
          <path d="M3 5h14M3 10h14M3 15h14" />
        </svg>
      </button>

      <RouterLink
        :to="{ name: 'console-home' }"
        class="rounded-md text-base font-semibold tracking-tight focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
      >
        x-identity
      </RouterLink>
      <p v-if="me" class="hidden min-w-0 items-center gap-2 text-sm sm:flex">
        <span aria-hidden="true" class="text-text-disabled">/</span>
        <span class="text-text-muted">Account</span>
        <span class="truncate font-medium" :title="me.account.name">{{ me.account.name }}</span>
      </p>

      <div class="ml-auto flex shrink-0 items-center gap-2">
        <RouterLink
          :to="{ name: 'projects' }"
          class="hidden h-10 items-center rounded-md px-3 text-sm font-medium text-text hover:bg-bg-subtle focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary active:bg-border aria-[current=true]:bg-primary-subtle aria-[current=true]:text-primary-active sm:inline-flex"
          :aria-current="inAccount ? 'true' : undefined"
        >
          Account settings
        </RouterLink>
        <UserMenu />
      </div>
    </header>

    <div class="flex min-h-0 flex-1">
      <aside id="console-navigation" aria-label="Console navigation" class="hidden w-64 shrink-0 overflow-y-auto border-r border-border bg-bg-subtle md:flex">
        <ConsoleSidebar :current-project-uid="currentProjectUid" />
      </aside>
      <BaseDrawer v-model:visible="navigationOpen" :title="inAccount ? 'Account' : 'Project'">
        <ConsoleSidebar :current-project-uid="currentProjectUid" />
      </BaseDrawer>

      <main id="main" tabindex="-1" class="min-w-0 flex-1 overflow-y-auto px-4 py-6 md:px-8">
        <div class="mx-auto flex max-w-6xl flex-col gap-6">
          <RouterView />
        </div>
      </main>
    </div>
  </div>
</template>
