<script setup lang="ts">
// Tabs that are pages, so each section has its own URL and the browser's back button moves between
// them. OpenVue's Tabs keeps the selection in component state instead.
import { RouterLink, useRoute, type RouteLocationRaw } from 'vue-router'

export interface RouteTab {
  label: string
  to: RouteLocationRaw
  /** The route name that marks the tab as current. */
  name: string
}

defineProps<{
  label: string
  tabs: readonly RouteTab[]
}>()

const route = useRoute()
</script>

<template>
  <nav :aria-label="label" class="overflow-x-auto border-b border-border">
    <ul class="flex gap-1">
      <li v-for="tab in tabs" :key="tab.name">
        <RouterLink
          :to="tab.to"
          :aria-current="route.name === tab.name ? 'page' : undefined"
          class="-mb-px block border-b-2 border-transparent px-3 py-2 text-sm whitespace-nowrap text-text-muted hover:border-border hover:text-text focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary aria-[current=page]:border-primary aria-[current=page]:font-semibold aria-[current=page]:text-primary"
        >
          {{ tab.label }}
        </RouterLink>
      </li>
    </ul>
  </nav>
</template>
